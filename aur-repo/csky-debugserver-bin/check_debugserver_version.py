#!/usr/bin/env python3
"""玄铁 DebugServer (C-Sky) 版本检测 + OSS 下载链接获取脚本（供 lilac 使用）。

背景
----
xrvm.cn 玄铁资源中心是 JS 单页应用，每个版本的 OSS 下载链接都不同且随版本变动。
本脚本通过其公开 API 自动解析最新版本号，并用维护者登录 JWT 自动获取真实下载链接：
  - 版本目录枚举（公开，无需登录）:
      POST /api/resource/resDir/getSelectedDirs  {"id": "<任意已知版本目录 id>"}
  - 版本内文件列表（公开，无需登录）:
      POST /api/resource/resDir/getAllRes       {"parentId": "<版本目录 id>", ...}
  - 真实 OSS 下载链接（需登录 JWT）:
      POST /api/resource/res/download           {"id": "<资源 id>"}
        -> {"code":0,"result":"https://occ-oss-prod.oss-cn-hangzhou.aliyuncs.com/resource//<TS>/..."}

JWT 说明
--------
`res/download` 的认证靠名为 `Authorization` 的 httpOnly cookie（值是 HS512 JWT，约 8 小时过期）。
因此需把登录后的 JWT 存到独立密钥文件（secret 不进 lilac.yaml）：
  ~/.lilac/xrvm.toml    内容:  authorization = "eyJhbGciOiJIUzUxMiJ9..."
获取方法：登录 https://www.xrvm.cn 后按 F12 -> Application -> Cookies ->
https://www.xrvm.cn -> 复制名为 `Authorization` 的 cookie 值，粘贴进上述文件（chmod 600）。
lilac 只在检测到新版本、需要更新 PKGBUILD source 时才调 res/download；
JWT 过期时脚本会给出明确提示，重新复制粘贴一次即可。

用法
----
  python3 check_debugserver_version.py               # 输出最新版本（lilac update_on 用）
  python3 check_debugserver_version.py --files       # 输出最新版本 x86_64 安装包文件名
  python3 check_debugserver_version.py --fetch-url   # 用 JWT 取最新版 x86_64 + User Guide 真实 URL
  python3 check_debugserver_version.py --token-test  # 校验 JWT 是否有效
  python3 check_debugserver_version.py --verbose     # 调试：打印所有版本目录

注意
----
- `update_on: cmd` 在 lilac/nvchecker 中以仓库根目录为工作目录运行，故 lilac.yaml 里写
  `cmd: python3 csky-debugserver-bin/check_debugserver_version.py`；
  pre_build 在工作沙箱的包目录内运行，故用相对包目录名 `check_debugserver_version.py`。
- 本脚本只读取 ~/.lilac/xrvm.toml 中的 JWT，不涉及其它账号信息。
"""

import argparse
import json
import os
import re
import sys
import urllib.error
import urllib.request

try:
    import tomllib  # Python 3.11+
except ImportError:
    tomllib = None

API_SELECTED_DIRS = "https://www.xrvm.cn/api/resource/resDir/getSelectedDirs"
API_ALL_RES = "https://www.xrvm.cn/api/resource/resDir/getAllRes"
API_DOWNLOAD = "https://www.xrvm.cn/api/resource/res/download"
# JWT 密钥文件（独立于 lilac.yaml / nvchecker keyfile）
SECRET_FILE = os.path.expanduser("~/.lilac/xrvm.toml")
UA = ("Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/148.0 Safari/537.36")

# getSelectedDirs 会返回指定目录同组（DebugServer）的全部版本目录；
# 以下为已知版本目录 id（取较旧的稳定版本作为 seed，越旧越不可能被删除）。
SEED_DIR_IDS = [
    "4380347564587814912",  # V5.18.3
    "4587994279539970048",  # V5.18.10
    "4224169423675658240",  # V5.8.20（最老，最稳定）
    "4224169250815807488",  # V5.16.11
]
VERSION_RE = re.compile(r"^V(\d+\.\d+\.\d+)$")


def _post(url, payload, extra_headers=None):
    headers = {
        "Content-Type": "application/json",
        "User-Agent": UA,
    }
    if extra_headers:
        headers.update(extra_headers)
    req = urllib.request.Request(
        url,
        data=json.dumps(payload).encode("utf-8"),
        headers=headers,
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=30) as resp:
        return json.load(resp)


def fetch_version_dirs():
    """遍历已知 seed，返回所有版本目录条目 [{name, id, ...}]。"""
    for seed in SEED_DIR_IDS:
        try:
            data = _post(API_SELECTED_DIRS, {"id": seed})
        except (urllib.error.URLError, urllib.error.HTTPError, OSError) as exc:
            sys.stderr.write(f"xrvm: getSelectedDirs({seed}) failed: {exc}\n")
            continue
        result = data.get("result") or []
        if result:
            return result
    return []


def parse_versions(dirs):
    versions = []
    for item in dirs:
        m = VERSION_RE.match(item.get("name") or "")
        if m:
            versions.append(tuple(int(p) for p in m.group(1).split(".")))
    return sorted(versions)


def format_version(v):
    return ".".join(str(p) for p in v)


def find_latest_dir(dirs, latest):
    target = "V" + format_version(latest)
    for item in dirs:
        if item.get("name") == target:
            return item
    return None


def fetch_resources(dir_id):
    """列出某版本目录下的文件（公开 API，返回 [{id, name, ...}]）。"""
    payload = {"parentId": dir_id, "pageIndex": 1, "pageSize": 50}
    try:
        data = _post(API_ALL_RES, payload)
    except (urllib.error.URLError, urllib.error.HTTPError, OSError) as exc:
        sys.stderr.write(f"xrvm: getAllRes({dir_id}) failed: {exc}\n")
        return []
    result = data.get("result") or {}
    return result.get("list") or []


# ---------- JWT / 真实下载链接 ----------

TOKEN_EXPIRED_HINT = (
    "JWT 已过期或未配置。请登录 https://www.xrvm.cn 后按 F12 -> Application -> Cookies -> "
    "https://www.xrvm.cn，复制名为 `Authorization` 的 cookie 值，写入 {secret}（chmod 600）：\n"
    "    authorization = \"eyJhbGciOiJIUzUxMiJ9...\"\n"
    "若只带 Authorization 仍被拒，请改填完整 Cookie 串（最可靠）：\n"
    "    cookie = \"Authorization=...; access_token=...; ...\""
)


def load_cookie():
    """从 ~/.lilac/xrvm.toml 读取用于 res/download 的 Cookie 头值。

    配置示例（chmod 600，二选一）：
        # 方式一（推荐，最可靠）：完整 Cookie 串，等价于浏览器发出的
        cookie = "Authorization=...; access_token=...; unb=...; cna=...; ..."
        # 方式二（省事）：只填 JWT，脚本拼成 "Authorization=<jwt>"（可再加 extra_cookies）
        # authorization = "eyJhbGciOiJIUzUxMiJ9..."
        # extra_cookies = "cna=...; isg=..."
    """
    if tomllib is None:
        return "", "Python 3.11+ required for tomllib"
    try:
        with open(SECRET_FILE, "rb") as f:
            data = tomllib.load(f)
    except FileNotFoundError:
        return "", TOKEN_EXPIRED_HINT.format(secret=SECRET_FILE)
    except Exception as exc:
        return "", f"读取 {SECRET_FILE} 失败: {exc}"
    full = str(data.get("cookie") or "").strip()
    if full:
        return full, None
    auth = str(data.get("authorization") or "").strip()
    if not auth:
        return "", TOKEN_EXPIRED_HINT.format(secret=SECRET_FILE)
    extra = str(data.get("extra_cookies") or "").strip()
    return ("Authorization=" + auth + ("; " + extra if extra else "")), None


def fetch_download_url(resource_id, cookie):
    """用 Cookie 调 res/download 取真实 OSS URL。返回 (url_or_None, errmsg_or_None)。"""
    if not cookie:
        return None, "no cookie configured"
    headers = {
        "Cookie": cookie,
        "Referer": "https://www.xrvm.cn/community/download?id=4380347564587814912",
        "bx-v": "2.5.37",
    }
    try:
        data = _post(API_DOWNLOAD, {"id": resource_id}, headers)
    except urllib.error.HTTPError as exc:
        return None, f"HTTP {exc.code}"
    except (urllib.error.URLError, OSError) as exc:
        return None, str(exc)
    code = data.get("code")
    if code != 0:
        return None, data.get("msg") or f"code={code}"
    url = data.get("result")
    if not isinstance(url, str) or not url.startswith("http"):
        return None, f"unexpected result: {url!r}"
    return url, None


def fetch_version_urls(cookie):
    """返回最新版本的 [(resource_name, oss_url), ...]，供 --fetch-url / pre_build 使用。"""
    dirs = fetch_version_dirs()
    if not dirs:
        return None, "no version directories found"
    versions = parse_versions(dirs)
    if not versions:
        return None, "no Vx.y.z directories found"
    latest_dir = find_latest_dir(dirs, versions[-1])
    if not latest_dir:
        return None, f"latest version dir not found ({format_version(versions[-1])})"
    resources = fetch_resources(latest_dir.get("id"))
    out = []
    errs = []
    for res in resources:
        name = res.get("name", "")
        # 只取需要的文件：x86_64 安装包 + User Guide PDF
        want = "linux-x86_64" in name and name.endswith(".sh.tar.gz") or \
               ("User Guide" in name and name.endswith(".pdf"))
        if not want:
            continue
        url, err = fetch_download_url(res.get("id"), cookie)
        if url:
            out.append((name, url))
        else:
            errs.append(f"{name}: {err}")
    if not out:
        return None, "res/download 全部失败: " + "; ".join(errs) if errs else "无匹配资源"
    return out, None


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--files", action="store_true",
                        help="同时输出最新版本的 x86_64 安装包文件名")
    parser.add_argument("--fetch-url", action="store_true",
                        help="用 ~/.lilac/xrvm.toml 的 JWT 获取最新版本真实下载 URL")
    parser.add_argument("--token-test", action="store_true",
                        help="校验 JWT 是否有效（取最新版一个文件试下载链接）")
    parser.add_argument("--verbose", action="store_true",
                        help="打印全部版本目录")
    args = parser.parse_args()

    dirs = fetch_version_dirs()
    if not dirs:
        sys.stderr.write("xrvm: no version directories found (API unreachable or changed)\n")
        return 1

    versions = parse_versions(dirs)
    if not versions:
        sys.stderr.write("xrvm: no Vx.y.z directories found, names=%s\n"
                         % [d.get("name") for d in dirs])
        return 1

    if args.verbose:
        for item in dirs:
            print(item.get("name"), item.get("id"))

    latest = versions[-1]
    latest_str = format_version(latest)

    # --token-test / --fetch-url 需要 Cookie
    if args.token_test or args.fetch_url:
        cookie, err_hint = load_cookie()
        if not cookie:
            if err_hint:
                sys.stderr.write("xrvm: " + err_hint + "\n")
            return 2
        urls, err = fetch_version_urls(cookie)
        if err:
            sys.stderr.write(f"xrvm: {err}\n")
            if "登录" in err or "Authorization" in err:
                sys.stderr.write("xrvm: " + TOKEN_EXPIRED_HINT.format(secret=SECRET_FILE) + "\n")
            return 2
        for name, url in urls:
            print(f"{name}\t{url}")
        if args.token_test:
            sys.stderr.write(f"xrvm: Cookie 有效（最新版 {latest_str}，共 {len(urls)} 个链接）\n")
        return 0

    # 默认 / --files：只需公开 API
    print(latest_str)
    if args.files:
        latest_dir = find_latest_dir(dirs, latest)
        if latest_dir:
            names = [r.get("name", "") for r in fetch_resources(latest_dir.get("id"))]
            x86 = [n for n in names if "linux-x86_64" in n and n.endswith(".sh.tar.gz")]
            if x86:
                print("# x86_64 安装包文件名: " + x86[0])
            else:
                print("# 未找到 x86_64 .sh.tar.gz（可下载文件: %s）" % " | ".join(names))
    return 0


if __name__ == "__main__":
    sys.exit(main())
