---
name: lilac
description: 用于 lilac（Arch Linux 仓库自动化打包系统，lilac2 包）的包级配置编写、维护与运行原理理解。当用户需要为软件包仓库中的包编写或维护 lilac.yaml / lilac.py、分析上游版本/tag 获取方式、排查构建为何触发或不触发时使用。按上游真实形态决策，生成最小、规范、安全、兼容面广的配置。自纠错、自更新。
---

# lilac：配置编写 + 运行理解

一个 skill 覆盖两件事：**① 怎么写 lilac.yaml/lilac.py（操作）② lilac 怎么运行、为何触发/不触发（理解）**。
速查（字段契约、update_on 全 source、别名目录、API、自纠错表）见 `references/config.md`。

## 运行原理（30 秒版）

lilac 是**两阶段**编排器：`git pull` → **nvchecker** 实时抓每个包的上游版本（即"抓 tag"）→ 与 `oldver` 比对得更新集合 → 叠加 pkgrel/依赖/失败重构建因 → `repo_depends` 拓扑排序 → Worker 在 **bwrap 沙箱**跑 makepkg（`pre_build`/`post_build` 钩子）→ 签名拷贝、`nvtake` 记新 oldver、发 AUR。

**关键结论**：
- `update_on` 写的是**取数规则**，不是写死版本；每次运行实时计算。
- nvchecker 事件流：`updated`(触发构建) / `up-to-date`(不构建) / `error`(剔除并邮件)。
- 构建触发原因：nvchecker 更新、pkgrel 变更、依赖触发（repo_depends）、命令行点名、失败重构建、OnBuild 联动。
- **worker 构建管线**（自动执行，用户无需手写）：`prepare()` → `pre_build()` → `recv_gpg_keys` → `vcs_update()` → `check_srcinfo()`(官方 groups/replaces 冲突 + 降级校验) → 沙箱构建 → `post_build()` → `post_build_always(success)`；pre_build 后 pkgver 未变且 pkgrel 未增则自动 pkgrel+1。
- 沙箱：所有会 source PKGBUILD 的命令（makepkg/updpkgsums/run_protected）都在 `bwrap --unshare-all --ro-bind / /` 内跑，**PKGBUILD/lilac.py 视为不可信代码**。
- 配置两层：包级 `lilac.yaml`/`lilac.py`（单包）vs 仓库级 `config.toml`（环境）。**secret 绝不进包级配置**（走 `~/.lilac/nvchecker_keyfile.toml` 与 `config.toml`）。

**排查"为什么不更新"**：nvchecker `up-to-date`（tag 没变）？`error`（被剔除）？`prefix` 写错导致版本带 `v` 比不上？`include_regex` 把 tag 全过滤了？`use_max_tag` 与 `use_latest_release` 用反？

## 配置生成工作流

### 步骤 0：收集上下文
确认：① `PKGBUILD`（必需，无则停下询问）；② 维护者 `github`+`email`；③ 是否同步 AUR（决定 post_build 钩子）；④ 目标仓库现有包列表（探测 `repo_depends`）；⑤ 有无生态依赖需锁定（决定 `alias`）。

### 步骤 1：提取 PKGBUILD 信号
| 信号 | 推导 |
|---|---|
| `url` 含 `github.com/<o>/<r>` | `source: github` + `github: <o>/<r>` |
| `url` 含 gitlab 等 git 托管 | `source: git`(任意 git) / `gitlab`(需 `host:`) / `gitea`(需 `host:`) |
| `url`/`source` 含 pypi/crates.io/npm/cpan/gem/hackage/go | 对应生态 source |
| `source` 含 `#tag=` | pre_build 里改 tag 行（`edit_file`） |
| `pkgname` 以 `-git/-hg/-svn/-bzr` 结尾 | VCS 包 |
| 上游只在 Releases 发版 | `use_latest_release: true`（非 use_max_tag） |
| 跟随 AUR 已有包 | `source: aur` + `aur: <pkgname>`（同步 AUR 标配） |
| `depends`/`makedepends` 命中别名目录 | 追加 `- alias: <名>`（手写，无自动绑定） |
| 依赖官方包 soname/ABI 版 | `source: alpm`(+`provided`+`strip_release`) 或 `alpmfiles` |
| 版本无法自动检测 | `manual: N`（自增触发重建） |
| 依赖仅目标仓库提供的包 | `repo_depends`/`repo_makedepends` |

**禁止**：PKGBUILD 无可解析上游 URL 时停下问用户，不凭空猜 source。

### 步骤 2：决策引擎（核心，可回退）
1. **选 source**（步骤1 + references 选型表）。
2. **判定版本取法**：`use_max_tag` / `use_latest_tag` / `use_latest_release` / `use_commit` / `prefix` / `include_regex` / `exclude_regex` / `from_pattern`→`to_pattern`。
   **必须主动验证**：对 git/github 上游执行 `git ls-remote --tags <url>`（或 Releases API）确认真实 tag 形态再定规则，确保模拟后产出 Arch 合规 `x.y.z`（无 `v` 前缀、无预发布后缀）。**拿不准必须实查，不靠猜**。
3. **别名探测**：扫 `depends`/`makedepends` 命中别名目录 → `- alias: <名>`。
4. **repo_depends 探测**：仅目标仓库提供、Arch/AUR 无此包的依赖 → `repo_depends`（仅构建期则 `repo_makedepends`）。
5. **AUR 发布探测**：需同步 AUR → post_build 钩子选一：内联 `git_pkgbuild_commit()+update_aur_repo()` 或引用 `post_build: aur_post_build`；AUR 上游覆盖 → `aur_pre_build()`。
6. **特殊字段**：独立 `_tagname=`/`_ver=` 变量 → `edit_file('PKGBUILD')` 替换；超时风险大 → 提示 `time_limit_hours`；自定义 chroot 前缀 → `build_prefix`。

### 步骤 3：生成最小 lilac.yaml
只写必要字段。骨架（GitHub tag 场景）：
```yaml
maintainers:
  - github: <user>
    email: <email>
update_on:
  - source: github
    github: <owner>/<repo>
    use_max_tag: true
    prefix: v
```
钩子有两种**等价主流写法**，按目标仓库惯例选一：
- 写法 A（内联脚本，aur-repo 主流）：脚本内可直接用 api 函数与 `_G`，无需 import。
```yaml
pre_build_script: |
  update_pkgver_and_pkgrel(_G.newver)
post_build_script: |
  git_pkgbuild_commit()
  update_aur_repo()
```
- 写法 B（引用 api 函数名，archlinuxcn 主流）：lilac 自动从 `lilac2/api.py` 解析，**函数名必须在 api.py 中**。
```yaml
post_build: aur_post_build   # 或 pre_build: pypi_pre_build 等
```
- 默认可省字段不写（`managed`/`staging`/`allowed_workers`/`time_limit_hours`）。
- `update_on` 条目键留空（如 `github:`）时默认取 pkgbase 名，不必重复写。
- 版本 `-` 需转 `_`：优先 source 级 `from_pattern`/`to_pattern`，不塞 pre_build。
- `repo_depends` 只列目标仓库提供的包（写 `- <pkg>` 或 `- <pkgbase>: <pkgname>`）。

### 步骤 4：生成 lilac.py（仅当必须）
需要 `aur_pre_build()`、`edit_file` 改独立 tag 变量、`add_into_array`/`pypi_pre_build`/`mediawiki_pre_build` 等自定义逻辑才生成。惯例：首行 `#!/usr/bin/env python3`，随后 `from lilaclib import *`，再写 `def pre_build():` 等。注意 `_G.newver` 在 git 类 source 下可能是 `version@commit` 格式，需 split 处理。

### 步骤 5：自纠错（必做）
对照 references 自纠错表逐条核对：`maintainers` 非空（AUR 场景还是同步白名单）、`source` 合法、`github` 格式、`pre_build`/`post_build` 引用的函数名存在、`post_build_always` 若引用须带 `success` 参数、`prefix` 匹配真实 tag、`repo_depends` 名是否目标仓库内包。构建前 `check_srcinfo` 会拒绝降级包与官方 groups/replaces 冲突包——确认取数规则产出的版本必高于仓库现有版本。有疑问回退修正。

## 工程实战要点
- **新包接入**：0→5 全流程；生成后提醒放入仓库正确目录。
- **配置修正**：先读现有 `lilac.yaml`，对照自纠错表与当前上游 tag 形态（上游可能迁移/改 tag 策略）再改，不整体重写。
- **排查不更新**：按上文「运行原理/排查」定位。
- **安全**：secret 不进 lilac.yaml（走 config.toml/keyfile）；不替用户执行 lilac 构建命令（除非明确要求）；`pre_build_script` 只调 `lilac2/api.py` 公开 API，不写任意 shell。

## 自更新 SOP
知识来源：`lilac2/lilacyaml.py`、`aliases.yaml`、`api.py`、`typing.py`、`nvchecker.py` 及目标仓库真实配置。
- `update_on` 新增 source/tag 策略 → 更新 references §4 与选型表。
- `LilacInfo` 字段 / `api.py` 函数变更 → 更新 references §1/§2。
- 每次更新维护 `# LAST_VERIFIED`。

# LAST_VERIFIED: 2026-08-20 | lilac@update-skills
