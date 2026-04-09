# Scripts

`scripts/` 放统一入口、工具目录和配置样例。

整体技术方案见：

- [README.md](./README.md)
- [ARCHITECTURE.md](./ARCHITECTURE.md)
- [TASKS.md](./TASKS.md)

这里的目标很明确：

- 一个顶层入口
- 命令见名知意
- 日常只记少量命令
- 配置、初始化、检查都自动化
- 不只把工具装好，还要把最佳实践使用方式一起落进去
- 文档和帮助信息尽量不制造歧义

原则：

- 顶层只有一个总入口
- 工具按类别分目录
- 一个工具一个主入口
- 配置、脚本、文档放在一起
- 说明文档尽量收敛，不拆散

补充说明：

- `README.md` 负责讲怎么使用
- `ARCHITECTURE.md` 负责讲整体边界、目录模型、能力模型和最佳实践设计
- `TASKS.md` 负责讲当前完成了什么、下一步做什么、优先级是什么
- 后续默认能力不会只靠 `skill / plugin` 定义，还会覆盖 `hook / MCP / agent / memory / policy`
- `config init --scope project` 已生成共享的 `project-context / architecture / workflow / checklist`，并内置角色分工、持续记忆、测试与发布引导，以及默认角色模板
- `tool review` 已覆盖全局初始化回归、项目初始化回归、默认报告回归和旧概念残留拦截
- 顶层帮助与子工具帮助已改成彩色分层展示，优先突出主命令、配置起步模板、默认记忆、典型场景和最小必要信息
- 顶层帮助现在会同时展示：接口全览、场景执行、工具支持能力和按需能力
- `scenario` 现在是步骤式全交互向导：选工具、选场景、补配置、看计划、再执行
- `scenario` 会自动补齐关键配置、必要时创建 `local.conf`，再给出执行计划并确认执行
- `scenario` 对 OpenClaw 额外提供“部署形态”引导：公网域名、公网 IP、Tailscale 私网、Tailscale 公网入口
- `scenario` 默认沿用配置里的推荐模型和模式，只在用户明确要改时展开进阶项

## 总入口

```bash
cd scripts

bash manage.sh service report --tool-name openclaw --config ./general-agents/openclaw/local.conf
bash manage.sh scenario
bash manage.sh scenario --tool-name codex --scene install
bash manage.sh guide start --tool-name codex
bash manage.sh service install --tool-name codex --config ./coding-agents/codex/local.conf
bash manage.sh config init --tool-name codex --config ./coding-agents/codex/local.conf --scope project --path /workspace/path
bash manage.sh service check --tool-name codex --config ./coding-agents/codex/local.conf
bash manage.sh tool review
```

## 默认工作流

- 一个顶层入口：`manage.sh`
- 需要交互式引导时，优先用 `scenario`
- `scenario` 会按步骤逐步引导，不要求用户先理解内部配置名
- `scenario` 会先补齐关键配置，再串起安装、增强、迁移、项目初始化或状态检查
- Coding Agents 默认三命令：`service install`、`config init`、`service check`
- `service install` 负责安装并完成全局最优初始化
- `config init` 负责初始化项目目录骨架、记忆文档、角色分工、测试与发布说明
- `service check` 负责检查安装、配置、官方目录和运行清单状态
- `service check` 会同时显示当前值、目标值，以及是否一致 / 不一致 / 缺失
- `service check / report` 会展示“最佳实践就绪度”，直接看当前是否达到推荐基线
- `service check / report` 在检测到“未安装”或“未生效”时，会直接给出下一条建议动作
- `service check / report` 还会补“未就绪原因”，直接指出缺的是安装、认证、配置还是默认能力项
- `service check / report` 会显示当前能力包策略，直接看当前 `MODE`、默认包、进阶包、探索包是否生效
- `service check / report` 会同时显示“核心能力统计”和“能力项统计”
- “核心能力统计”优先按用户体感看 `skill + plugin/extension + 核心 MCP`
- “能力项统计”是完整口径，会把 `hook / 全量 MCP / agent` 一起算进去
- OpenClaw 保留它自己的主链路：`service install`、`service configure`、`service report`、`service check`

## 三类典型场景

如果不想自己记具体命令，直接执行：

```bash
bash manage.sh scenario
```

也可以显式指定工具和场景：

```bash
bash manage.sh scenario --tool-name codex --scene install
bash manage.sh scenario --tool-name codex --scene project --path /workspace/project
```

说明：

- `scenario` 现在是“步骤式全交互”向导，会先后引导：工具、场景、配置文件、关键配置、项目模板、执行确认
- `scenario` 会自动检查配置文件，不存在时会从 `conf.example` 创建
- 常见安装和增强场景默认沿用配置里的推荐模型、模式和常规 provider，只补认证和必填项
- `install / enhance / migrate` 会补齐真正会卡住场景的关键项，例如认证、模型、provider、访问模式、飞书、长期记忆
- `project / status` 只保留必要输入，不会追问无关密钥
- OpenClaw 的 `scenario` 不再直接让用户理解 `ACCESS_MODE / PUBLIC_MODE`，而是先按“部署形态”选择，再自动落到配置项

### 1. 从零开始安装，并直接进入最佳实践

目标：

- 先把工具安装好
- 同时把全局最佳实践配置、默认能力包、运行清单一起落好
- 如果要开始做项目，再补项目模板

推荐命令：

```bash
bash manage.sh service install --tool-name codex --config ./coding-agents/codex/local.conf --yes
```

如果还要把某个项目一起初始化到最佳实践，再执行：

```bash
bash manage.sh config init --tool-name codex --config ./coding-agents/codex/local.conf --scope project --path /workspace/project --yes
```

说明：

- 只看“全局可用 + 最佳实践生效”，通常 1 条命令就够
- 需要把某个项目也初始化成推荐结构时，通常是第 2 条命令

### 2. 已经通过本工具安装，后续想增强或调整配置

典型场景：

- 把 `MODE` 从 `standard` 调到 `advanced` 或 `exploration`
- 补启用增强能力包
- 修改模型、provider、认证方式、默认扩展

做法：

- 可以先用 `scenario --scene enhance` 交互式改目标项
- 也可以直接改配置文件，再执行 1 条重放命令

```bash
bash manage.sh service configure --tool-name codex --config ./coding-agents/codex/local.conf --yes
```

如需确认当前状态，再补 1 条检查：

```bash
bash manage.sh service check --tool-name codex --config ./coding-agents/codex/local.conf
```

说明：

- 这个场景不该重新执行安装
- 语义上就是“把当前环境重放到新的目标配置”

### 3. 不是用本工具安装，但想升级到我们的最佳实践

目标：

- 尽量保留现有安装
- 把官方目录、配置、运行清单、默认能力对齐到当前最佳实践

推荐优先用场景向导接管：

```bash
bash manage.sh scenario --tool-name codex --scene migrate
```

推荐先直接接管并对齐：

```bash
bash manage.sh service configure --tool-name codex --config ./coding-agents/codex/local.conf --yes
```

然后检查结果：

```bash
bash manage.sh service check --tool-name codex --config ./coding-agents/codex/local.conf
```

如果不确定当前环境是否已安装、是否适合直接 `configure`，先看概览：

```bash
bash manage.sh service report --tool-name codex --config ./coding-agents/codex/local.conf
```

说明：

- 这类场景优先用 `service configure`，不是 `service install`
- `service report / check` 会给出建议动作，告诉你下一步应该 `install` 还是 `configure`
- 目标是把“已有环境”平滑拉到我们的推荐基线，而不是强行推倒重装

## 场景化建议

- 新装一个工具：先 `service install`
- 要做项目初始化：再 `config init --scope project`
- 已装后想切模式、补增强、改配置：用 `service configure`
- 不确定当前状态：先 `service report`
- 要确认是否达到推荐基线：用 `service check`
- 想直接拿到 1-2 条最短命令：用 `guide start`

## 快速开始命令

如果不想先读完整帮助，直接执行：

```bash
bash manage.sh guide start --tool-name codex
bash manage.sh guide start --tool-name openclaw --scene install
```

说明：

- `guide start` 只输出最短上手路径
- 适合首次使用、快速安装、迁移接管和项目模板初始化
- 完整命令面仍看 `bash manage.sh --help`

## 当前验证口径

当前我们把验证分成两层：

- 隔离回归验证
  - 不碰真实官方目录
  - 主要验证命令、模板、清单、报告输出和目录模型
- 非破坏性实机验证
  - 尽量利用当前机器真实环境
  - 不影响现网服务
  - 主要验证安装状态识别、配置重放、升级接管、建议动作和失败提示

当前已完成的稳定范围：

- 四个 coding agent 的全局初始化隔离回归
- 四个 coding agent 的项目初始化隔离回归
- 四个 coding agent 的默认报告回归
- 顶层命令、帮助输出、文档一致性回归

当前还在继续补的范围：

- `service install` 的非破坏性实机验证
- `service configure` 的迁移接管验证
- `service update` 的真实升级验证
- 第三方来源、登录、429、未注册等场景的实机提示验证

用户可以这样理解当前状态：

- 设计和脚本结构已经形成闭环
- 隔离验证已经较完整
- 实机验证正在继续补，且优先保证不影响现网

## 当前目录结构

```text
scripts/
├── manage.sh
├── README.md
├── shared/
│   └── lib/
├── general-agents/
│   ├── README.md
│   └── openclaw/
└── coding-agents/
    ├── manage.sh
    ├── claude-code/
    ├── codex/
    ├── gemini-cli/
    └── opencode/
```

## 当前已接入

- [General Agents](./general-agents/README.md)
- [OpenClaw](./general-agents/openclaw/README.md)
- [Coding Agents](./coding-agents/README.md)

说明：

- 日常使用优先走顶层 `manage.sh`
- 修改脚本或文档后，先执行 `bash manage.sh tool review`
- 根目录主文档只保留三份：使用、设计、任务追踪
- `tool review` 现在会在隔离的临时目录里验证四个 coding agents 的全局初始化，不会触碰真实 `~/.codex`、`~/.claude`、`~/.gemini`、`~/.config/opencode`
- OpenClaw 优先记：`service install`、`service configure`、`service report`、`service check`、`service logs`
- Coding Agents 优先记：`service install`、`config init`、`service check`
- 常用主链路可以压缩成三步：先 `service install`，再 `config init --scope project`，最后 `service check`
- Coding Agents 的扩展目录和运行清单由 `service install` / `config init` 自动准备，不单独暴露 `skill/plugin/hook/mcp` 命令
- Coding Agents 的 `service check` 只做检查，不会直接覆盖现有配置
- Coding Agents 的 `config init --scope global` 负责生成仓库运行模板、清单和官方目录骨架；真正同步到官方配置文件由 `service install / configure / update` 负责
- Coding Agents 的默认基线只包含稳定、可自动落地的核心能力；重依赖或强服务绑定能力默认进入增强包
- 当前通用默认基线为：`common-core + common-docs-architecture + common-quality + common-backend + common-frontend`
- Coding Agents 现在优先通过 `MODE=standard|advanced|exploration` 切换层级，不再要求用户分别记增强开关和实验开关
- 当前进阶包不再只是一套通用列表，配置样例已经按工具给出各自更合适的进阶包组合
- 子目录 `manage.sh` 保留给分类管理和单独调试
- `coding-agents` 已进入第一批可用实现阶段，不再只是骨架
- Coding Agents 的官方状态目录保留在各工具默认位置，备份、清单和包装命令默认写回各自工具目录
- Coding Agents 已支持“通用默认能力包 + 工具专属能力包 + 增强能力包”的配置与运行清单视图
- `gemini-cli` 已支持第一批官方 extension 真正落地与状态快照
- `gemini-cli` 已支持官方名称、`github:org/repo`、`org/repo`、GitHub URL、本地路径这几类 extension 规格
- `opencode` 已支持把默认 npm plugin 写入 `opencode.json`，并同步本地插件路径
- `opencode` 已把远程 GitHub / URL 插件来源纳入状态快照，但会明确提示官方仍以 npm 包或本地 JS/TS 插件文件为准
- `codex` 已支持第一批官方 skill / GitHub skill / 本地 skill 真正落地与 `skills.status`
- `claude-code` 已支持第一批官方 / 第三方 marketplace plugin 真正落地与 `plugins.status`
