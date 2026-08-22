---
name: lilac
description: 用于 lilac（Arch Linux 仓库自动化打包系统，lilac2 包）的包级配置编写、维护与运行原理理解。当用户需要为软件包仓库中的包编写或维护 lilac.yaml / lilac.py、分析上游版本/tag 获取方式、排查构建为何触发或不触发时使用。按上游真实形态决策，生成最小、规范、安全、兼容面广的配置。自纠错、自更新。
---

# lilac：配置编写 + 运行理解

一个 skill 覆盖两件事：**① 怎么写 lilac.yaml/lilac.py（操作）② lilac 怎么运行、为何触发/不触发（理解）**。
速查（字段契约、update_on 全 source、别名目录、API、自纠错表）见 `references/config.md`。

## 运行原理（30 秒版）

lilac 是**两阶段**编排器：`git pull` → **nvchecker** 实时抓每个包的上游版本（即"抓 tag"）→ 与 `oldver` 比对得更新集合 → 叠加 pkgrel/依赖/失败重构建因 → `repo_depends` 拓扑排序 → Worker 构建（`build_prefix='makepkg'` 走 bwrap 沙箱，默认 `extra-<arch>` 走 devtools chroot）并执行 `pre_build`/`post_build` 钩子 → 签名拷贝、`nvtake` 记新 oldver、按需发 AUR（仅当包同步 AUR 时）。

**关键结论**：
- `update_on` 写的是**取数规则**，不是写死版本；每次运行实时计算。
- nvchecker 事件流：`updated`(触发构建) / `up-to-date`(不构建) / `error`(剔除并邮件)。
- 构建触发原因：nvchecker 更新、pkgrel 变更、依赖触发（repo_depends）、命令行点名、失败重构建、OnBuild 联动。**失败包不自动重试**：须目录有 git 变更（`UpdatedFailed`）或上次缺的依赖已补齐（`FailedByDeps`）才再进构建集。
- **worker 构建管线**（自动执行，用户无需手写）：`prepare()` → 容器内 `pre_build()` + `recv_gpg_keys` + `vcs_update()`（三者被 `may_update_pkgrel()` 整体包裹，进入前与退出后各快照一次 pkgver/pkgrel）→ `check_srcinfo()`(官方 groups/replaces 冲突 + 降级校验) → 沙箱构建 → `post_build()`（带全局锁）→ `post_build_always(success)`。pkgrel 自动 +1 判定基于 `may_update_pkgrel` 包裹窗口：若窗口内 pkgver 未变且 pkgrel 未增则退出时自动 `pkgrel+1`。
- **信任边界**：`prepare`/`pre_build`/`post_build` 钩子运行在 worker 进程（可信，可写文件、推 git）；而 **source PKGBUILD 的命令**（makepkg/updpkgsums 及 `run_protected` 封装的任何命令）在 `bwrap` 沙箱（`UNTRUSTED_PREFIX`，定义于 `lilac2/cmd.py`）内跑，**PKGBUILD 视为不可信外部代码**。注意隔离有两套，勿混淆：① `run_protected` 的 bwrap（`--unshare-all` + 根只读 + `/home`/`/run`/`/tmp` tmpfs + `--share-net`，当前目录 bind 进 `/tmp/<目录名>` 执行）包装**取数/校验类 PKGBUILD 命令**（`vcs_update` 的 `makepkg -od`、`updpkgsums`、`get_pkgver_and_pkgrel` 等），**与 build_prefix 无关、任何模式都生效**；② **实际构建**：`build_prefix='makepkg'`（`single_main` 默认）时在 bwrap 沙箱内跑 `makepkg --holdver`（worker.py:159-163），生产默认 `extra-<arch>` 则走 `<prefix>-build` devtools chroot，不经 bwrap。钩子里调用 `lilac2/api.py` 公开函数（尤其是 `run_protected` 封装的）是安全的，但**切勿在钩子里拼接/exec 任意 PKGBUILD 内容**——信任区≠可信代码。
- **跳过构建**：`prepare()` 内 `raise SkipBuild('原因')` 可中止本次构建（状态 `skipped`）；其余异常→`failed` 并生成失败报告。
- **本地验证**：`single_main(build_prefix)` 可在本机直接按当前目录 `lilac.yaml`/`lilac.py` 跑一遍构建管线（不依赖调度器），用于上线前自检。
- 配置两层：包级 `lilac.yaml`/`lilac.py`（单包）vs 仓库级 `config.toml`（环境）。**secret 绝不进包级配置**（走 `~/.lilac/nvchecker_keyfile.toml` 与 `config.toml`）。

> 沙箱细节见上方信任边界：source PKGBUILD 的命令在 `bwrap`（`UNTRUSTED_PREFIX`，`cmd.py`）内跑，**PKGBUILD 视为不可信代码**；生产默认构建走 devtools chroot，bwrap 用于 `build_prefix='makepkg'` 路径。

**排查"为什么不更新"**：nvchecker `up-to-date`（tag 没变）？`error`（被剔除）？`prefix` 写错导致版本带 `v` 比不上？`include_regex` 把 tag 全过滤了？`use_max_tag` 与 `use_latest_release` 用反？

**排查"为什么触发了构建"**（构建原因诊断，`nomypy.py` 的 `BuildReason`，报告里可见）：
- `NvChecker`：nvchecker 检测到版本变化 → 正常触发。
- `UpdatedFailed`：上次构建失败且本批目录有 git 变更（`failed_prev ∩ changed`）——**失败不无条件重试**。
- `UpdatedPkgrel`：pkgrel 被改（如 `may_update_pkgrel` 自动 +1）。
- `Depended`：被 `repo_depends` 的下游包依赖且尚无已构建产物，随上游一起进构建集。
- `FailedByDeps`：上次因缺这些依赖失败、本次依赖已构建完成，连带重建。
- `OnBuild`：命中 `update_on_build`（被依赖包刚构建）。
- `Cmdline`：被命令行/`single_main` 显式指定。
据此可快速判断"误触发"是否源于 `repo_depends`/`alias`/`update_on_build` 配置过宽。

## 配置生成工作流

### 步骤 0：收集上下文
确认：① `PKGBUILD`（必需，无则停下询问；split 包注意 `package()` 多 `pkgname`，推断失败需 `package.list`）；② 维护者 `github`+`email`；③ 是否同步 AUR（决定 post_build 钩子）；④ 目标仓库现有包列表（探测 `repo_depends`）；⑤ 有无生态依赖需锁定（决定 `alias`）；⑥ 上游版本是否在多个位置需联合判断（决定多 source）。

### 步骤 1：提取 PKGBUILD 信号

> **消歧铁律（多信号同现时用）**：`url` 只是主页，**以"实际下载 tarball 的来源主域"为准**判定 source；先展开 PKGBUILD 变量再匹配。优先级：`pypi.org`/`files.pythonhosted.org`→pypi；`crates.io`→crates；`registry.npmjs.org`→npm；`cpan.org`/`metacpan.org`→cpan；`rubygems.org`→gem；`hackage.haskell.org`→hackage；其次 `github.com`→github；`codeberg.org` 等已知 gitea→gitea（带 `host:`）；含 `gitlab`→gitlab（带 `host:`，gitlab.com 也显式写）；`bitbucket.org`→bitbucket；`git+https://` 任意→git。命名约定兜底（仅在变量展开后仍全不命中主域时）：`python-*`→pypi、`perl-*`→cpan、`ruby-*`→gem、`haskell-*`→hackage、`rust-*`/`cargo`→crates、`nodejs-*`/`npm-*`→npm；兜底结果**必须实查注册站存在该名**才采用，否则停下问用户。多条信号指向不同 source 时以"下载源主域"裁决，不靠 `url`。

| 信号 | 推导 |
|---|---|
| 下载源主域为 pypi/crates/npm/cpan/gem/hackage | 对应生态 source（见上铁律） |
| 下载源主域 `github.com/<o>/<r>` | `source: github` + `github: <o>/<r>` |
| 下载源为 gitlab/gitea 实例 | `source: gitlab`/`gitea`（均带 `host:`） |
| `source` 含 `#tag=` | pre_build 里改 tag 行（`edit_file`） |
| `pkgname` 以 `-git/-hg/-svn/-bzr` 结尾 | **VCS 包** → `source: vcs` + `vcs: <git url>`（构建时拉 HEAD；要语义版本才加 `use_max_tag`） |
| 上游只在 Releases 发版 | `use_latest_release: true`（非 use_max_tag） |
| 跟随 AUR 已有包 | `source: aur` + `aur: <pkgname>`（同步 AUR 标配） |
| `depends`/`makedepends` 命中别名目录 | 追加 `- alias: <名>`（手写，无自动绑定） |
| 依赖官方包 soname/ABI 版 | **优先 `- alias: <名>`（§4.2 目录命中即禁用 alpm 写法）**；目录外冷门 so 才手写 `source: alpm`(+`provided`+`strip_release`) 或 `alpmfiles` |
| 依赖**本仓库自产包**版本 | `alpm-lilac`（非 `alpm`） |
| 版本无法自动检测 | `manual: N`（固定版本占位，非每次重建） |
| 依赖仅目标仓库提供的包 | `repo_depends`/`repo_makedepends` |

**三者边界（避免误配）**：① `alias`/`alpm`/`alpm-lilac` 是**取数探测**（让 lilac 感知依赖版本变化以决定是否重建本包）；② `repo_depends` 是**构建顺序**（本仓库包间拓扑，非版本探测）；③ `update_on_build` 是**被依赖包刚构建就连带重建**（依赖提供头文件但 so 未变、或版本归一型时用，且被引 pkgbase 必须在 `repo_depends`）。三者可叠加，互不替代。

**禁止**：无法从 PKGBUILD 推断出真实上游（经变量展开+主域判定+命名兜底后仍无果）时停下问用户，不凭空猜 source。

### 步骤 2：决策引擎（核心，可回退）
1. **选 source**（步骤1 + references 选型表）。上游版本需**多位置联合判断**（主程序 tag + 子模块/数据版本）时，列多个 `update_on` 条目（多 source）。
2. **判定版本取法**：`use_max_tag` / `use_latest_tag` / `use_latest_release` / `use_commit` / `prefix` / `include_regex` / `exclude_regex` / `from_pattern`→`to_pattern`。
   **必须主动验证**：对 git/github 上游执行 `git ls-remote --tags <url>`（或 Releases API）确认真实 tag 形态再定规则，确保模拟后产出 Arch 合规 `x.y.z`（无 `v` 前缀、无预发布后缀）。**拿不准必须实查，不靠猜**。
3. **别名探测（命中优先用 alias，禁手写 alpm）**：扫 `depends`/`makedepends` 命中 §4.2 别名目录 → 直接 `- alias: <名>`，**禁止手写 `source: alpm` + `provided` + `strip_release`**（alias 是 alpm 的封装，已含仓库验证过的参数，手写易错且冗余）。注意区分**官方包**（`alpm`/`alias`）与**本仓库自产包**（`alpm-lilac`）。
   **soname 版本化 provides（见 references §4.7）**：若本包**自己提供 `.so`**（库包），PKGBUILD/lilac.py 的 `provides` 应写**版本化**（`libfoo.so=1`）；`add_provides()` 同样传版本化串。注意 `check_library_provides()`（`api.py:632`）是 **opt-in 校验函数**，worker 不会自动调用——仅在包的 `post_build` 里显式调用时才拦截未版本化 `.so`；未启用则不报错，但版本化是 Arch 规范良好实践。下游用 `alias` 触发重建与此独立。
4. **repo_depends 探测**：仅目标仓库提供、Arch/AUR 无此包的依赖 → `repo_depends`（仅构建期则 `repo_makedepends`）；split 包精确指定产出用 `- <pkgbase>: <pkgname>`。
5. **AUR 发布探测（仅当需同步 AUR）**：需同步 AUR → post_build 钩子选一：内联 `git_pkgbuild_commit()+update_aur_repo()` 或引用 `post_build: aur_post_build`；AUR 上游覆盖 → `aur_pre_build()`（填相符的 `maintainers` 白名单）。
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
钩子有两种**等价写法**，按目标仓库惯例选一：
- 写法 A（内联脚本）：脚本内可直接用 api 函数与 `_G`，无需 import。
```yaml
pre_build_script: |
  update_pkgver_and_pkgrel(_G.newver)
post_build_script: |
  git_pkgbuild_commit()
  update_aur_repo()
```
- 写法 B（引用 api 函数名）：lilac 自动从 `lilac2/api.py` 解析，**函数名必须在 api.py 中**。
```yaml
post_build: aur_post_build   # 或 pre_build: pypi_pre_build 等
```
- 默认可省字段不写（`managed`/`staging`/`allowed_workers`/`time_limit_hours`）。
- `update_on` 内任意 `<source-type>:` 键的值若留空/缺省，lilac 自动填充为**包目录名（pkgbase）**——此 fallback 对所有 source 类型通用（nvchecker 兼容逻辑），不必重复写；仅当目录名 ≠ 上游仓库名时必须显式写（如目录 `foo-git` 对应上游 `owner/foo`）。
- **多 source**：列多个 `update_on` 条目即可；多 source 时版本以列表传递——`_G.newver`/`_G.oldver` 仅取第一个 source，`_G.newvers`/`_G.oldvers` 与条目**顺序一一对应**，pre_build 逐源处理用后者。**触发语义**：nvchecker 结果按 `pkgbase` 聚合，**任一** source 的 `oldver != newver` 即整包进 `nv_changed`（生成 `NvChecker` 原因），非逐 source 独立进集；某 source 出错时该 source 在 `nvdata` 填 `(None,None)` 占位，**不会整体剔除该包**（lilac 按第一个 source 判定新旧，其余 source 仅供 `_G.newvers` 逐源使用）。
- 版本 `-` 需转 `_`：优先 source 级 `from_pattern`/`to_pattern`，不塞 pre_build。
- `repo_depends` 只列目标仓库提供的包（写 `- <pkg>` 或 `- <pkgbase>: <pkgname>`）。

### 步骤 4：生成 lilac.py（仅当必须）
**生成阈值**：仅下列任一成立才写 `.py`，否则只用 yaml（yaml 能表达的全部用 yaml）：
1. 需 `aur_pre_build()`（AUR 上游覆盖）；
2. 需 `edit_file` 改独立 tag 变量（`_tagname=`/`_ver=`）或逐源改写 PKGBUILD 段（多 source 时 `_G.newvers[i]`）；
3. 需 `add_into_array`/`pypi_pre_build`/`mediawiki_pre_build`/`download_official_pkgbuild` 等自定义逻辑；
4. 需自定义 `prepare()`（返回 str 则 `SkipBuild`）。
惯例：首行 `#!/usr/bin/env python3`，随后 `from lilaclib import *`，再写 `def pre_build():` 等；api 符号由 `lilaclib` 注入（内联 `*_script` 写法无需 import）。注意 VCS 类 source 下 `_G.newver` 可能是 `version@commit` 格式，需 split 处理。

### 步骤 5：自纠错（必做）
对照 references 自纠错表逐条核对：`maintainers` 非空（AUR 场景还是同步白名单）、`source` 合法、`github` 格式、`pre_build`/`post_build` 引用的函数名存在、`post_build_always` 若引用须带 `success` 参数、`prefix` 匹配真实 tag、`repo_depends` 名是否目标仓库内包。构建前 `check_srcinfo` 会拒绝降级包与官方 groups/replaces 冲突包——确认取数规则产出的版本必高于仓库现有版本。有疑问回退修正。

## 工程实战要点
- **新包接入**：走 0→5 全流程；生成后提醒放入仓库正确目录。
- **配置修正**：先读现有 `lilac.yaml`，对照自纠错表与当前真实上游 tag 形态（上游可能迁移/改 tag 策略）再改，不整体重写。
- **安全**：secret 不进 `lilac.yaml`（走 `config.toml`/keyfile）；不替用户执行 lilac 构建命令（除非明确要求）；`pre_build_script` 只调 `lilac2/api.py` 公开 API，不写任意 shell（与上「信任边界」一致）。

## 常见运行时故障

完整故障速查（按构建生命周期 12 类失败、统一诊断模板）见 `references/config.md` §7。下面以**最高频**的 soname/ABI 破坏事务为例详解：

### 依赖 soname/ABI 破坏事务（最常见）
**现象**：chroot 内 `pacman` 更新报 `:: 安装 <dep> (<newver>) 破坏依赖 'libxxx.so=N.M.0-64'（<pkg> 需要）` → `错误：无法准备事务处理` / `更新已中止`。
**根因**：依赖包升主版本致 so 版本号变化（如 `boost-libs` 1.91→1.92），下游 `<pkg>` 仍链接旧 `.so=N.M.0-64`，未跟随重建。
**处理**：
1. 确认 `<pkg>` 的 `lilac.yaml` 声明了对应 `alias`（boost/icu/protobuf/libssl 等，见 config.md §4.2 别名目录）。`alias` 展开为 `update_on` 的 `source: alpm`，使 lilac 在依赖版本变化时把 `<pkg>` 纳入重建集合。
2. 漏加 → 补 `alias: <x>` 重跑 lilac，自动触发重建；已加仍报则手动 `lilac -p <pkg>` 强制重建（进仓库顺序/时机问题）。
3. 库包 `provides = libxxx.so` 应带版本号（`libxxx.so=1`）；`check_library_provides` 是 opt-in（需在 post_build 显式调用才校验），但版本化是良好实践。
**例外**：纯运行时可选依赖、或不链接该 so 的下游，不必加 alias（避免无谓重建）。

## 自更新 SOP
知识来源：`lilac2/lilacyaml.py`、`aliases.yaml`、`api.py`、`typing.py`、`nvchecker.py`、`l10n/*/mail.ftl` 及目标仓库真实配置。遇 lilac 升级时按 `references/config.md` §8「扩展 SOP」逐类更新（新增 source→§4.2/§4.6；字段/钩子→§1/§2；API 变更→§2/§3；失败类型→§7 以 mail.ftl **类型**为准）。本技能只写规则与字段契约，不写具体包版本快照。
