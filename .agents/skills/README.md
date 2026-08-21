# lilac Skill（AI 辅助打包配置）

单个 skill 覆盖 lilac 打包配置的**编写**与**运行理解**：

```
skills/
├── README.md               # 本文件：定位、用法、维护说明
└── lilac/                  # 唯一 skill：配置生成/维护 + 运行原理 + 速查
    ├── SKILL.md            # 工作流 0→5 + 决策引擎 + 运行原理/排查 + 工程实战
    └── references/config.md   # 字段契约 + API + update_on 全 source + 别名 + 自纠错表
```

## 用法

| 场景 | 做法 |
|---|---|
| 「根据 PKGBUILD 生成 / 修正 lilac.yaml」 | 加载 `lilac`，走 SKILL 步骤 0→5 |
| 「update_on 某个 source 怎么写 / tag 匹配方式选型」 | `lilac` → references §4 |
| 「字段是否合法 / lilac.py 能用哪些函数」 | `lilac` → references §1-§3、§5 |
| 「lilac 怎么运行 / 为何不触发更新」 | `lilac` → SKILL 运行原理 + 排查 |

> 决策**不依赖仓库风格**：按上游真实形态（GitHub tag / Releases / 生态源 / 官方包 / 本仓库依赖 / 是否同步 AUR）驱动，对任何 lilac 仓库通用。
> **不写实时无关的写法**：references 只含字段契约与取数规则，不含具体包名/版本快照；实际 tag 形态由决策引擎 `git ls-remote` 实查后生成。

## 工程实战要点（面向 AI agent）

1. **新包接入**：取 PKGBUILD → 走 SKILL 0→5，产出最小配置 → 提醒放入仓库正确目录。
2. **配置修正**：先读现有 lilac.yaml，对照自纠错表与当前上游 tag 形态改，不整体重写。
3. **排查不更新**：用 SKILL「运行原理/排查」定位（updated/up-to-date/error 事件流；prefix 不符、use_max_tag 与 use_latest_release 用反）。
4. **拿不准 tag 形态**：决策引擎主动 `git ls-remote --tags` 实查，不靠猜。

## 维护与更新（自更新）

每个文件顶部维护 `# LAST_VERIFIED: <YYYY-MM-DD> | lilac@<commit>`，源码变更时刷新对应内容：

| lilac2 源码变更 | 需更新 |
|---|---|
| `lilacyaml.py` / `typing.py`（LilacInfo 字段） | references §1 |
| `api.py`（API / 模块变量） | references §2/§3 |
| `aliases.yaml`（别名目录） | references §4.2 |
| `nvchecker.py` / `worker.py` / `cmd.py`（运行流程） | SKILL 运行原理 |
| `update_on` 新增 source / tag 策略 | references §4 + SKILL 步骤2 |

扩展新 source：按 references 末尾「扩展 SOP」追加写法并更新选型表；验证方式：抽取目标仓库真实包跑决策引擎，与仓库内真实配置比对。
