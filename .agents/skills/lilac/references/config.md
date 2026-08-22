# lilac 配置速查（lilac.yaml + lilac.py + update_on sources）
权威来源：`lilac2/lilacyaml.py`、`lilac2/typing.py`、`lilac2/api.py`、`lilac2/aliases.yaml`、
`lilac2/nvchecker.py`（`update_on` 经 `**config` 透传 nvchecker，所有 nvchecker source 均可用）、`schema-docs/`。
**本文只写规则与字段契约，不含具体包/版本快照**（那些会随上游变化，需按 SKILL 步骤 2 实查上游 tag 后生成）。

---

## 1. `lilac.yaml` 字段（LilacInfo）

| 字段 | 类型 | 默认 | 说明 |
|---|---|---|---|
| `maintainers` | list[{github,email}] | `[]` | 构建失败通知对象；**AUR 场景是同步白名单**（aur_pre_build 必填）。为空加载不报错，但强烈建议填写 |
| `update_on` | list[dict] | `[]` | 上游版本检测（source 见 §4；条目键留空则用 pkgbase 名） |
| `update_on_build` | list[{pkgbase,from_pattern?,to_pattern?}] | `[]` | 依赖包更新时连带重建（需 db）；`from_pattern`/`to_pattern` 必须成对出现 |
| `repo_depends` | list[str 或 `{pkgbase: pkgname}`] | `[]` | **本仓库内**构建顺序依赖（非 Arch/AUR 依赖）；str 形式则 pkgbase=pkgname |
| `repo_makedepends` | list | `[]` | 同上，仅影响构建期顺序 |
| `time_limit_hours` | float | `1` | 构建时限；`< 0` 抛 ValueError（=0 合法） |
| `staging` | bool | `false` | 是否暂存 |
| `managed` | bool | `true` | `false` 则 lilac 不管理该包 |
| `allowed_workers` | list[str] | `[]` | 限定构建机 |
| `throttle_info` | dict[int,timedelta] | `{}` | 按 source 下标**抑制触发**（由 `lilac_throttle` 生成，不手写；需构建历史 db 才生效） |
| `pre_build`/`post_build`/`post_build_always` | str(函数名) | — | **引用 `lilac2/api.py` 函数名**，加载时 `getattr(api, name)` 自动解析（lilacyaml.py FUNCTIONS） |
| `pre_build_script`/`post_build_script`/`post_build_always_script` | str(python 代码) | — | 内联脚本，与对应函数名**二选一** |

> 两种钩子写法等价：`post_build: aur_post_build`（引用 api 函数名）vs `post_build_script: |`（内联脚本）。内联脚本命名空间自动注入 api 全部公开符号（含 `_G`），无需 `from lilaclib import *`。`post_build_always(_script)` 签名必须是 `def post_build_always(success)`，脚本内可直接用 `success`。
> yaml 顶层键（如 `build_prefix`/`time_limit_hours`）会原样注入 lilac.py 模块（lilacpy.py `setattr(mod, k, v)`），由 worker 以模块变量读取——即**同一字段既可在 lilac.yaml 顶层写，也可在 lilac.py 里赋值**（完整清单见 §3）。

### 打包目录特殊文件（schema-docs/special-files.md）
- `package.list`：split 包名无法用正则确定时每行一个包名，**防止被自动清理**。
- `.gitignore`：git 忽略；**不会被清理，也不会被内建 AUR 下载器覆盖**。

> **配置容错边界（重要）**：lilac 对 `lilac.yaml` 顶层**多余/拼错的键不会报错**，也不会进任何 "unknown" 集合——它们会被原样 `setattr` 进 lilac 模块并静默忽略。真正会在**加载期**报错的只有：YAML 语法错误、钩子函数名 `getattr` 失败、`time_limit_hours < 0`、以及 `update_on_build` 条目含非 `{pkgbase,from_pattern,to_pattern}` 的键（解包抛 `TypeError`）。这些以**包为单位**整体落入 `errors`（该包不参与本轮构建）。
> 另：`pkgbase` **不是 lilac.yaml 字段**，lilac 强制取包**目录名**；yaml 里写 `pkgbase` 会被静默覆盖为目录名（冗余写法）。

---

## 2. `lilac.py` 可用 API

函数由 `lilac2/api.py` 提供。两种使用方式：lilac.py 里 `from lilaclib import *`（=`lilac2/api.py` 全量导出）；lilac.yaml 通过 `pre_build`/`post_build` 引用函数名（lilacyaml.py 自动解析）。

**版本与 PKGBUILD 编辑**
- `update_pkgver_and_pkgrel(newver, *, updpkgsums=True)` — 更新 pkgver/pkgrel 并重算 sha256（最常用）。
- `update_pkgrel(rel=None)` — 只 bump pkgrel。
- `get_pkgver_and_pkgrel()` → `(pkgver, pkgrel)`。
- `edit_file(filename)` — 逐行 yield，改写后 `print(line)` 回写。
- `add_into_array(which, extra)` / `add_depends`/`add_makedepends`/`add_checkdepends`/`add_conflicts`/`add_replaces`/`add_provides`/`add_groups`/`add_arch` — 向数组追加。
- `obtain_array(name)` / `obtain_depends()` / `obtain_makedepends()` / `obtain_optdepends()` — 读数组。
- `run_protected(cmd)` / `run_cmd(cmd)` — bwrap 沙箱内执行（updpkgsums/makepkg 自动走沙箱）。
- `vcs_update()` — 更新 VCS 源。

**AUR 同步**
- `aur_pre_build(name=None, *, do_vcs_update=None, maintainers=())` — 拉 AUR 上游覆盖；`maintainers` 必填：lilac 取该 AUR 包网页上的 **Last Packager**（若该包已由 lilac 接管则 Last Packager=lilac，比对通过）作可信校验，且不在 `AUR_BLACKLIST`，否则抛异常——**填的是 AUR 页面 Last Packager 栏的账号，不是你自己的账号，也不是 Maintainer 栏**。
- `aur_post_build()` — 提交 AUR 变更。
- `update_aur_repo()` — 推送本包到 AUR（需 lilac 有 co-maintainer 权限；VCS 包仅 pkgver/pkgrel 变化时自动跳过）。
- `git_pkgbuild_commit()` — `git add PKGBUILD`+commit；`git_add_files(files, *, force=False)` / `git_commit()` / `git_rm_files()`。
- `git_pull()` / `git_push()` — 同步仓库（push 失败自动 rebase 重试）。

**运行时上下文对象 `_G`**：lilac 注入的命名空间，钩子/脚本内可用，完整字段见 §3 `_G` 条目（含 `_G.oldver`/`_G.newver`/`_G.oldvers`/`_G.newvers`/`_G.on_build_vers`/`_G.reponame`/`_G.built_version`/`_G.commit_msg_template`/`_G.mod`/`_G.add_report()`）。

**源生成器**
- `pypi_pre_build(depends=None, pypi_name=None, arch=None, makedepends=None, ...)` / `pypi_post_build()`（不再支持 python2）。
- `mediawiki_pre_build(name, mwver, desc, license)` / `mediawiki_post_build()`。
- `download_official_pkgbuild(name)` — 从 Arch 官方下载 PKGBUILD（返回文件列表）。
- `single_main(build_prefix='makepkg')` — 手动单包构建入口。

**校验 / 清理**
- `check_library_provides()` — **opt-in 校验函数**（`api.py:632`，全仓库仅定义、无自动调用点）：检测产物 `.PKGINFO` 里未带版本的 `.so` provides。worker 管线**不会自动调用它**；要启用需在包的 `post_build`/`post_build_script` 里显式调用（很多仓库放在共享 post_build 中）。
- `clean_directory()` — 删除非特殊文件的 git 跟踪内容。

**联动更新（OnBuild）**：机制与约束见 §4.5 `update_on_build`（按依赖包构建触发重建、需 `repo_depends` + 构建历史库）；上下文字段 `_G.on_build_vers` 见 §3。

**密钥**：`recv_gpg_keys` 不是 api 函数（是独立脚本），**worker 构建管线自动执行**，无需在配置里调用。

**安全**：source PKGBUILD 的命令经 `run_protected`（拼 `UNTRUSTED_PREFIX`，定义于 `lilac2/cmd.py`）进 bwrap 沙箱；`run_cmd` 仅当完整命令**恰为 `['updpkgsums']`**、或某参数是**以 `'makepkg '`（带尾随空格）开头的单字符串**（如 `'makepkg --holdver'`）时才自动走沙箱；`['makepkg', ...]` 列表形式不命中、其余一律裸跑——故钩子里**统一用 `run_protected` 封装外部命令**，勿直接 `run_cmd` 执行不可信内容，勿拼 exec PKGBUILD 变量。

---

## 3. 模块级控制变量（lilac.yaml 顶层或 lilac.py 均可）

| 变量 | 作用 |
|---|---|
| `build_prefix` | chroot 前缀，默认 `extra-<arch>`（即 devtools 的 `extra-<arch>-build`，非 bwrap）；`makepkg` 则脱离 chroot 在本地直接跑 makepkg（single_main 默认）；其余任意前缀会被拼成 `<prefix>-build` 命令执行（常见如 `multilib`/`archlinuxcn-x86_64`，具体值取决于目标仓库约定）。**AUR 推送走 `update_aur_repo()`，与 build_prefix 无关** |
| `time_limit_hours` | 覆盖构建时限 |
| `build_args` | makepkg 参数（如 `['--noconfirm']`） |
| `makechrootpkg_args` / `makepkg_args` | chroot/打包器参数 |
| `prepare()` | pre_build 前执行的函数（返回 str 则 SkipBuild） |
| `_G.newver` | nvchecker 抓到的新版本号（单 source；pre_build 里取用；git 类 source 可能是 `version@commit`） |
| `_G.oldver` / `_G.oldvers` / `_G.newvers` | 单 source 旧版本 / 多 source 时旧新版本列表 |
| `_G.on_build_vers` | list[tuple[str,str]]；被依赖包（pkgbase）的（旧,新）版本，来自构建历史库 db.py，查不到为空串 |
| `_G.reponame` | 仓库名（运行环境填充） |
| `_G.built_version` | 构建成功后填充，pre_build 时为 None |
| `_G.commit_msg_template` | commit 模板 |
| `_G.mod` | 当前 lilac 模块 |
| `_G.add_report()` | 追加构建报告（无返回值） |

---

## 4. `update_on` source 全量 + tag 策略

### 4.1 通用 tag 处理顺序（对 tag 类 source 生效）
`include_regex`(白名单) → `exclude_regex`(黑名单) → `prefix` 剥前缀 → `from_pattern`→`to_pattern` 映射 → 按版本选最大（`use_max_tag`/`use_latest_tag`/`use_latest_release`）。

| 字段 | 作用 |
|---|---|
| `use_max_tag: true` | tag 按版本号语义取最大（最常用） |
| `use_latest_tag: true` | 取最新 tag（按 Git 顺序，慎用） |
| `use_latest_release: true` | 取最新 GitHub/Gitea **Release**（适合只在 Releases 发版的上游） |
| `use_commit: true` | 取指定 `branch` 的最新 commit（配 `branch:`，VCS 类包跟踪 commit 用） |
| `prefix: v` / `prefix: pkg-v` | 剥掉版本前的固定前缀 |
| `include_regex: 'v\d+\.\d+'` | 只保留匹配的 tag（白名单，配合 `from_pattern` 去前缀） |
| `exclude_regex: '[-_](rc|beta|alpha|dev)'` | 剔除预发布/无关 tag（黑名单） |
| `from_pattern` / `to_pattern` | 版本字符串映射（如 `'-'`→`'_'`） |
| `use_sorted_tags: true` | 按排序取最大 tag（bitbucket 等场景） |
| `lilac_throttle: 7d` | **抑制触发而非抑制检查**：周期内 nvchecker 照常检查，仅该 source 不加入构建触发原因（间隔按包上次成功构建时间计，需构建历史 db 生效） |

### 4.2 source 全量写法

**git 托管**
```yaml
# GitHub（最常见）
- source: github
  github: owner/repo
  use_max_tag: true
  prefix: v

# 任意 git 仓库（自建等）
- source: git
  git: https://git.example.com/o/r.git
  use_max_tag: true

# GitLab（需 host）
- source: gitlab
  host: invent.kde.org
  gitlab: owner/repo
  branch: master

# Gitea（自建托管，需 host）
- source: gitea
  gitea: o/r
  host: https://git.example.com
  use_max_tag: true

# Bitbucket
- source: bitbucket
  bitbucket: o/r
  use_sorted_tags: true

# VCS 包（-git 等，构建时拉 HEAD；无 use_max_tag 时版本为 commit 计数）
- source: vcs
  vcs: https://github.com/o/r.git
```

**生态源**
```yaml
- source: pypi
  pypi: package-name        # 无此键则用 pkgname
- source: npm
  npm: package-name
- source: cpan
  cpan: Module::Name
- source: gem
  gem: package-name
- source: hackage
  hackage: package-name
- source: crates
  crates: crate-name
- source: go
  go: module/path           # Go module（可带 /v3 后缀）
```

**官方包/系统**
```yaml
# Arch 官方仓库（跟随官方包版本）
- source: archpkg
  archpkg: package-name

# Arch 官方 alpm 依赖的 soname/ABI
- source: alpm
  alpm: libssl
  provided: libssl.so        # 可选：取该 provided 版本
  strip_release: true        # 去掉 release 段只比版本号

# alpmfiles：取包内某文件的版本
- source: alpmfiles
  alpmfiles: package-name
  regex: 'lib(\d+)'

# apt（Debian 系版本）
- source: apt
  apt: package-name
```

**AUR / 命令 / 手工**
```yaml
# 跟随 AUR 包版本（同步 AUR 包标配）
- source: aur
  aur: pkgname

# 正则抓网页版本
- source: regex
  url: https://example.com/ver
  regex: 'name_v([\d.]+).deb'
  lilac_throttle: 7d

# 任意 shell 命令输出作为版本
- source: cmd
  cmd: curl -sS https://... | grep -oP 'v([\d.]+)'

# Go module proxy 拉取版本
- source: go
  go: github.com/o/r

# 无法自动检测：用固定版本号 N 占位（版本恒为 N，不随上游变化）
- source: manual
  manual: N
```
> `manual` 是 nvchecker 原生 source：版本永远等于 N，**不会每次都重建**；要触发更新须人工改 N。它只用于上游无任何可自动检测的取数手段时。
其他低频但存在的 nvchecker 原生 source：`jq`(url+jq 表达式)、`htmlparser`、`httpheader`。需要时查 nvchecker 文档，不凭空写。

**别名（aliases.yaml 内置 —— 优先于手写 alpm/provided）**
```yaml
- alias: libssl      # 推荐写法：命中别名目录直接用，lilac 自动展开为下方 alpm 等价体
# 等价手写（不推荐，易错且冗余）：
# - source: alpm
#   alpm: libssl
#   provided: libssl.so
#   strip_release: true
```
> **封装关系（关键）**：`alias` 就是 `alpm`/`alpmfiles` 的**预封装**——lilac 解析时把 `alias` 取出，再拿 `aliases.yaml` 里该名预定义好的字典（含 `source: alpm` + `alpm:` + `provided:` + `strip_release:` 等）回填到 `update_on` 条目（`lilacyaml.py` `parse_update_on`）。所以 `alias: libssl` 与手写上述 alpm 块**完全等价**，但别名写法更短、不会写错 `provided`/`strip_release`。

**修复优先级铁律**：下游包被某 so 库破坏 / 需跟随其版本时，**先查 aliases.yaml 的 20 个别名**——
- 若命中（常用 soname 库：protobuf/jsoncpp/grpc/libssl/libcrypto/spdlog/fmt/openmpi/libgit2 等 soname 提供型；python/ruby/perl/r/lua/boost/icu/readline/clang/mediawiki/qt6-base 等版本归一型）→ **一律用 `alias: <名>`，禁止手写 `source: alpm` + `provided` + `strip_release`**（alias 已封装且经仓库验证，手写易错、参数不全）。
- 仅当**不在别名目录**的冷门 so 依赖，才退回到手写 `source: alpm` + `provided`/`strip_release`（且需自己确认 provided 名与 strip 规则）。

完整目录（20 个）：python, ruby, perl, r, lua, boost, icu, readline, clang, mediawiki, qt6-base, protobuf, jsoncpp, grpc, libssl, libcrypto, spdlog, fmt, openmpi, libgit2。
两类型：**版本归一型**（python/ruby/perl/r/lua/boost/icu/readline/clang/mediawiki/qt6-base，用 from_pattern 比主版本号）vs **soname 提供型**（protobuf/jsoncpp/grpc/libssl/libcrypto/spdlog/fmt/openmpi/libgit2，用 provided+strip_release 比 `.so` 版本）。
> 别名清单以 `lilac2/aliases.yaml` 为权威源，上列为常见快照；新增/调整别名时先查该文件。
特殊别名 `alpm-lilac`：取本仓库自己 alpm 数据库中的包版本（lilac 自动填 `dbpath`/`repo`，依赖本仓库内包时用）。

### 4.3 repo_depends / repo_makedepends（本仓库内构建顺序）
- 作用：声明**仅目标仓库提供**、Arch/AUR 无此包的依赖，控制构建拓扑顺序。
- 写法：`- <pkg>`（pkgbase=pkgname）或 `- <pkgbase>: <pkgname>`（dict 的 value 是**包名**，不是版本）；`repo_makedepends` 只影响构建期顺序。
```yaml
repo_depends:
  - <pkg-in-this-repo>
```
> 注意：这是「本仓库包间依赖」，不是 Arch/AUR 依赖；Arch 依赖照常写在 PKGBUILD 的 depends。

### 4.4 选型表（按上游形态）

| 上游形态 | 推荐 source | 备注 |
|---|---|---|
| GitHub 有版本 tag | `github` + `use_max_tag` + `prefix` | 最常用 |
| GitHub 只在 Releases 发版 | `github` + `use_latest_release` | 不用 use_max_tag |
| GitLab | `gitlab` + `host` | branch 可选 |
| 自建 git / Gitea / Bitbucket | `git` / `gitea`+`host` / `bitbucket` | |
| 生态包（PyPI/crates/npm/cpan/gem/hackage/go） | 对应 source | 版本即发布版 |
| Arch 官方包 / soname | `archpkg` / `alpm`(+provided+strip_release) | |
| 跟随 AUR 包 | `aur`（可加 `alias`） | 同步 AUR 标配 |
| 网页版本 | `regex` + `lilac_throttle` | 抑制触发（不防检查） |
| 命令输出版本 | `cmd` | 输出须为干净版本串 |
| 无法自动检测 | `manual: N` | |
| VCS 包（-git 等） | `vcs` | 需要语义版本再加 use_max_tag |

### 4.5 `update_on_build`（按其他包构建触发重建）
当本包需要「依赖包一旦重新构建就跟着重建」时（如 A 提供头文件但 so 未变、或版本归一型依赖），用此字段而非 `alias`/`update_on`。
- 机制：查构建数据库里 `pkgbase` 最近两次构建版本，若不同（=该依赖刚被重建）则触发本包重建；可选 `from_pattern`/`to_pattern` 对版本做变换后再比较。
- **约束**：被引用的 `pkgbase` 必须同时出现在 `repo_depends`（lilac 靠 `repo_depends` 定位依赖目录）。
- 需构建历史库（db）已启用，否则仅告警不触发。
```yaml
update_on_build:
  - pkgbase: boost          # 该包重建时本包跟着重建（同时 boost 须在 repo_depends）
  - pkgbase: qt5-webkit
    from_pattern: ^(\d+)\.\d+
    to_pattern: \1
```

### 4.6 多 source、split 包与别名边界（易错点）

**多 source**：`update_on` 是 list，可同时写多个条目（如一个 git tag + 一个 submodule 的 aur 跟随）。多 source 时版本以列表传递：
- `_G.newver` / `_G.oldver`：仅取 **第一个** source 的版本（单值快捷方式）。
- `_G.newvers` / `_G.oldvers`：list，**与 `update_on` 条目顺序一一对应**——pre_build 里需逐源处理时用它而非 `_G.newver`。
- 决策树补充分支：上游版本在**多个位置**需联合判断（如主程序 tag + 数据版本）时，列多个 source，并在 pre_build 里用 `_G.newvers[i]` 逐源改写对应 PKGBUILD 段。

**split 包（一个 PKGBUILD 产多个 pkgname）**：
- 默认从 PKGBUILD 的 `package()` / `package_<name>()` 正则推断 pkgname；推断失败（动态/条件性 split）时，建 `package.list` 文件每行一个包名（见 §1 特殊文件），**防止被自动化清理**。
- lilac 的包标识是 `(pkgbase, pkgname)` 二元组；`repo_depends` 的 dict 形式 `<pkgbase>: <pkgname>` 正是在 split 场景下精确指定依赖哪个产出包。

**别名边界**：`alpm` 系列别名探测的是**官方仓库（Arch/alpm db）**版本；若依赖的是**本仓库自己打的包**（不是 Arch 官方包），要用 `alpm-lilac`（取本仓库 alpm 数据库），而非 `alpm`——这是别名目录里最容易选错的一类。

### 4.7 soname 自动触发规范与 lilac 护栏（关键）

lilac 对 soname 有**两端互补**的规范，配置 soname 触发时**两端都要做对**（注意：`check_library_provides()` 是 **opt-in 校验函数**，worker 不会自动调用，需各包在 `post_build` 里显式启用）：

**(A) 提供方（打包含 `.so` 的库）必须写「版本化 provides」**
- `lilac2/api.py:check_library_provides()` 是**可选校验函数**，worker 管线**不会自动调用**（全仓库无自动调用点）。它扫描产物 `.PKGINFO`，凡 `provides = ...*.so$`（**未带版本号**，如 `libfoo.so`）一律**抛异常中断构建**——但仅在包的 `post_build`/`post_build_script` 里**显式调用**时才生效；很多仓库把它放在共享 post_build 中统一启用。
- 因此：PKGBUILD 里 `provides=('libfoo.so')` 必须写成**版本化**形式：`provides=('libfoo.so=1'` 或 `libfoo.so=1.2.3`），否则一旦该包启用了 `check_library_provides()` 就会失败。
- 钩子里 `add_provides('libfoo.so')` 同理——**务必传版本化字符串**（`add_provides('libfoo.so=1')`），纯 `libfoo.so` 会在调用校验时触发拒绝。
- 未版本化 provides **不在自动护栏范围**：未启用该函数的包不会因此失败；但作为良好实践（且 Arch 打包规范要求），库包应始终写版本化 provides。

**(B) 消费方（链接别人 so 的下游包）用 `alias` 探版本变化**
- 下游在 `lilac.yaml` 加 `- alias: <名>`（名取自 §4.2 别名目录，**与 (A) 的修复优先级铁律一致：命中别名目录一律用 `alias`，禁手写 alpm**）。lilac 通过对应上游的 `provided: libxxx.so` + `strip_release` 探到 so 版本变化，从而触发下游重建。下游**自身也应写版本化 provides**（若它同时也是提供方）。
- 只有别名目录列出的 so 提供型/版本归一型包能用 `alias` 自动触发；**不在别名目录的 so 依赖**不会自动触发，需手动 `lilac -p <pkg>` 或改用 `repo_depends`/`update_on_build`（此时才退回手写 `source: alpm` + `provided`/`strip_release`）。

**(C) 判定流程**
```
包是否提供 .so？
├─ 是（提供方）→ PKGBUILD/lilac.py 的 provides 必须版本化（'=N'），否则 check_library_provides 中断
└─ 否（消费方）→ 依赖的 so 在 §4.2 别名目录？
                 ├─ 是 → 加 alias: <名> 自动触发重建
                 └─ 否 → 不在目录则无自动触发；用 repo_depends / update_on_build / 手动重建
```

> 权威源：`lilac2/aliases.yaml`（so 提供型别名 + `provided:` + `strip_release`）与 `lilac2/api.py:check_library_provides()`。新增 so 提供型别名时按 §8 扩展 SOP 同步更新 §4.2。

---

## 5. 仓库级配置（config.toml，非 lilac.yaml）
lilac.yaml 是**包级**；以下在仓库根 `config.toml`（或控制仓库）配置，对所有包生效，不写进单个包：
- `[bindmounts]`：devtools 构建环境内绑定挂载（如 `~/.cargo` → `/build/.cargo`），用于缓存；源目录不存在会自动创建。
- `tmpfs`（[misc] 段）：在 chroot 内挂 tmpfs 的路径列表（如 bazel 缓存）。
- `[nvchecker] proxy` 与 `~/.lilac/nvchecker_keyfile.toml`：取数密钥（GitHub token 等）走独立 keyfile，**不进 lilac.yaml/config.toml**。
- `max_concurrency`、`remoteworker`、`rebuild_failed_pkgs` 等运行参数同理为仓库级。注意 `rebuild_failed_pkgs` 的真实语义是**控制 nvtake（oldver 记录）范围**：`true`（默认）时所有构建成功的包都记录新版本；`false` 时仅 NvChecker 原因触发且实际构建过的包才记录——它**不是**「失败自动重试」开关（config.toml.sample 注释有误导）。失败包重试依赖 `UpdatedFailed`（目录有 git 变更）与 `FailedByDeps`（上次缺的依赖已补齐）。

---

## 6. 自纠错表（生成后逐条核对）

| 检查项 | 错误表现 | 修正 |
|---|---|---|
| `maintainers` 为空 | AUR 白名单/通知缺失 | 至少 1 个 {github,email} |
| `source` 非法 | nvchecker 报错 | 限 §4.2 列出的类型或别名 |
| `github:` 非 `owner/repo` | 解析失败 | 两段式；`gitlab`/`gitea` 需 `host:` |
| `pre_build`/`post_build` 引用的函数不存在 | AttributeError（加载时 getattr(api,name)） | 仅用 lilac2/api.py 导出函数 |
| `post_build_always` 函数签名缺 `success` | 构建报错 | 写 `def post_build_always(success)` |
| `prefix` 与实际 tag 不符 | 版本带多余前缀 | 去掉或修正 prefix |
| `time_limit_hours < 0` | ValueError | 改正数（=0 合法） |
| `pre_build` 与 `pre_build_script` 同时写 | 行为歧义 | 二选一 |
| 取数规则产出版本 ≤ 仓库现有 | 构建前降级检查拒绝 | 修正 tag 策略/prefix 保证单调递增 |
| PKGBUILD groups/replaces 命中官方包 | 构建前冲突检查拒绝 | 与官方协商或改名 |
| `repo_depends` 名非本仓库包 | 构建顺序/触发失败 | 只列本仓库提供的包 |
| AUR 上游覆盖未填 `maintainers` 白名单 | aur_pre_build 抛错 | 填 AUR 维护者 github |
| 可自动检测版本却用 `manual` | 版本永不自动更新，须人工改 N | 优先自动 source；仅上游无取数手段才用 `manual` |
| VCS 包误加 `use_max_tag` 或误以为必须 | 版本语义变化 | 默认 commit 计数即可，要语义版本再加 |
| 依赖 soname/ABI 破坏事务（典型：boost/icu/protobuf/libssl 升级后下游链接旧 so） | `:: 安装 <dep> (<newver>) 破坏依赖 'libxxx.so=N.M.0-64'（<pkg> 需要）` → `无法准备事务处理`/`更新已中止` | 下游 `<pkg>` 链接旧 so 版本；在其 `lilac.yaml` 加 `alias: <x>`（见 §4.2 别名目录）随依赖版本变化触发重建；已加 alias 仍报则手动 `lilac -p <pkg>` 重构建并检查进仓库顺序；详见 §7 |
| 下游包漏加 `alias` 致未重建 | 同上事务错误，且 `alias` 缺失 | 依赖属 §4.2 别名目录的 soname 提供型/版本归一型包时，下游必须声明对应 `alias` 才能被 lilac 探测到需重建 |
| 提供方写未版本化 `provides: libfoo.so` | `check_library_provides()` 抛「unversioned library "provides"」中断 | PKGBUILD/lilac.py 的 provides 必须版本化（`libfoo.so=1`）；`add_provides()` 同样传版本化串（见 §4.7） |

---

## 7. 故障速查（按构建生命周期）

统一诊断模板：**先读 lilac 邮件/日志的失败类型**（邮件模板来自 `lilac2/l10n/*/mail.ftl`，文案随版本，关键看**类型**而非逐字），再定位「生命周期阶段」。下表为高频类型与处置；具体文案以实际邮件为准。

| # | 阶段 | 失败类型（语义） | 典型触发 | 处置方向 |
|---|---|---|---|---|
| 1 | 版本探查 | nvchecker 取数失败 / 无新版本 | token 失效、源 404、正则不匹配 | 查 `update_on` 配置与 keyfile；`lilac -p <pkg>` 重探查 |
| 2 | 版本探查 | 版本非单调递增（降级） | tag 策略产版本 ≤ 仓库现有 | 修正 `prefix`/`use_max_tag`；必要时 `updpkgsums` |
| 3 | 构建前 | 重建被跳过（无需重建） | 依赖未变 / alias 未声明 | 确认是否真需重建；缺失则补 `alias`/`update_on_build` |
| 4 | 构建前 | 包冲突（与官方包重名/provides 冲突） | `groups`/`replaces` 命中官方包 | 改名或与官方协商 |
| 5 | 构建前 | 依赖环 / 依赖不存在 | `repo_depends` 指向本仓库不存在的包 | 修正 `repo_depends`/`repo_makedepends` |
| 6 | 构建前 | 触发原因判定异常 | `_G` 上下文未填充或 source 配置错 | 检查 `update_on` 与钩子取 `_G` 方式 |
| 7 | 构建前 | 超时（time_limit） | 构建超 `time_limit_hours` | 调大时限或优化构建 |
| 8 | 构建中 | 构建失败 | PKGBUILD 错、patch 失败、编译错 | 本地 `single_main` 复现；改 PKGBUILD/钩子 |
| 9 | 构建中 | 依赖事务破坏（soname/ABI） | 依赖升级 so 版本，下游未重建 | 见 §6 末两行 + 下游加 `alias` 或 `update_on_build` |
| 10 | 构建后 | 推送/commit 失败 | git push 冲突、AUR 推送无权限 | rebase 重试；确认 co-maintainer 权限 |
| 10b | post_build 校验（仅启用该函数的包） | 未版本化 `.so` provides 被 `check_library_provides()` 拒绝 | 提供方 `provides=('libfoo.so')` 无版本 / `add_provides('libfoo.so')` 无版本，且该包 post_build 显式调用了校验 | 改为版本化 `libfoo.so=1`（§4.7） |
| 11 | 构建后 | AUR 提交校验失败 | `maintainers` 与实际 AUR 打包者不符 / 入黑名单 | 修正 `aur_pre_build` 的 `maintainers` |
| 12 | 全周期 | 限频（throttle）抑制触发 | `lilac_throttle` 周期内**照常检查**但该 source 不加入触发原因（非漏检） | 确认是否真需立即重建；必要时移除/缩短 `lilac_throttle` |

> 扩展阅读：`lilac2/l10n/zh_CN/mail.ftl` 是失败邮件模板的权威源；排查时以实际邮件「类型字段」为准，不在本表逐字对照。

---

## 8. 扩展 SOP（随 lilac 升级维护本技能）

lilac 自身会演进；本技能遇到下列变化时按图更新，避免快照失效：

| 变化 | 去哪改 | 动作 |
|---|---|---|
| 新增/调整 `update_on` source 或别名 | §4.2、§4.6 | 先查 `lilac2/aliases.yaml` 与 nvchecker 文档，补写法与分类 |
| 新增 LilacInfo 字段或钩子 | §1、§2 | 对照 `lilac2/lilacyaml.py` FUNCTIONS / `lilac2/typing.py` |
| API 签名/行为变化 | §2、§3 | 对照 `lilac2/api.py` 与各 api 小节函数 |
| 构建管线/触发原因变化 | SKILL 运行原理、§7 | 对照 `lilac2/worker.py` / `cmd.py` / `nomypy.py` |
| 失败类型文案变化 | §7 | 以 `lilac2/l10n/*/mail.ftl` 的**类型**为准，不逐字抄 |
| 仓库级配置项变化 | §5 | 对照 `config.toml.sample` |

原则：本技能写「规则与字段契约」，**不写具体包版本/快照**；一切易变量以 `lilac2/*` 源码与 `schema-docs/` 为权威源，生成配置时按 SKILL 步骤 2 实查上游。

