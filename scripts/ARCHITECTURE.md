# Scripts 技术方案

这套脚本的核心目的不是单纯“自动安装”。

一句话总结：

**用一套统一脚本，把各类 agent 工具的安装、升级、卸载、最佳实践初始化、配置管理、扩展管理、检查排障统一起来，让这些工具长期保持可管理、可复现、可高效使用。**

## 目标边界

这套脚本要解决的是：

- 快速安装一个工具
- 按最佳实践完成首次初始化
- 后续可安全升级、卸载、重放配置
- 明确管理工具自己的官方目录
- 明确管理仓库里的运行文件、备份和清单
- 能看清当前状态与目标状态是否一致
- 在工具真实支持的前提下，管理 skill / plugin / hook / mcp 等扩展

这套脚本不追求：

- 用一套重抽象强行抹平所有工具差异
- 暴露工具实际上并不支持的“假能力”
- 为了共享代码把脚本做成难以理解的框架

## 最佳实践实现方案

这套脚本后续要实现的“最佳实践”，不只是安装几个 skill 或 plugin。

这份文档现在就是唯一的设计总纲，不再拆出第二份平行设计文档。

### 1. 最佳实践不是单层能力

必须同时覆盖：

- `skill / plugin / extension`
- `hook`
- `MCP`
- `agent / subagent / command`
- `memory / project guide`
- `permission / sandbox / approval`

### 2. Coding Tools 先共用，再分化

对 `codex / claude-code / gemini-cli / opencode`，后续要优先做：

- 一套通用默认能力包
- 一套工具专属默认能力包
- 一套增强能力包

目标不是让每个工具完全不同，而是让它们先共享一套开发最佳实践，再补各自强项。

当前已经明确三层能力包：

- 通用默认包
  - `common-core`
  - `common-docs-architecture`
  - `common-quality`
  - `common-backend`
  - `common-frontend`
- 工具专属默认包
  - `codex-core`
  - `codex-review`
  - `claude-workflow`
  - `claude-review`
  - `gemini-core`
  - `gemini-collaboration`
  - `opencode-core`
  - `opencode-workspace`
- 工具专属增强包
  - `codex-ecosystem`
  - `codex-frontend`
  - `codex-research`
  - `claude-ui`
  - `claude-memory`
  - `claude-ecosystem`
  - `gemini-ui`
  - `gemini-data`
  - `opencode-automation`
  - `opencode-memory`
  - `opencode-safety`
- 通用增强包
  - `enhanced-browser-deep`
  - `enhanced-long-memory`
  - `enhanced-data-platform`
  - `enhanced-background-agents`
  - `enhanced-observability`
- 实验包
  - `experimental-bleeding-edge`

用户侧配置现在收敛为一个主开关：

- `MODE=standard`
  - 只启用默认包
- `MODE=advanced`
  - 启用默认包 + 进阶包
- `MODE=exploration`
  - 启用默认包 + 进阶包 + 探索包

当前收敛原则再补一条：

- 通用默认包要保留“大多数工具都高频适用”的能力，不能为了保守把默认基线削得过轻
- 偏重但高频的能力可以留在默认包，例如 `playwright` 这类广泛适用的开发测试能力
- 更依赖外部设计系统、第三方服务或额外账号权限的能力，再优先进入工具专属增强包或通用增强包

当前统计口径也明确为两套：

- 核心能力统计
  - 面向用户体感
  - 重点看 `skill / plugin / extension / 核心 MCP`
  - 用来判断 `standard / advanced / exploration` 是否符合“默认够强、又不过重”的目标
- 能力项统计
  - 面向完整运行模型
  - 会把 `hook / 全量 MCP / agent` 一并统计
  - 用来解释为什么总量通常会高于用户直觉中的“装了多少扩展”

### 3. 最佳实践的实现方式

不是“装好一堆包就结束”，而是：

- 有能力包设计
- 有配置包设计
- 有初始化模板
- 有使用范式模板
- 有安全护栏
- 有一致性检查
- 有默认工作流
- 有最佳使用指引

### 4. 当前和目标状态

当前已具备：

- 安装 / 升级 / 卸载 / 检查
- 全局 / 项目初始化
- 官方目录与工具目录管理
- manifest 机制
- 能力包配置模型
- 能力项统计与元信息
- 仓库级 review
- 非破坏性全局初始化回归
- 项目级共享模板：
  - `project-context`
  - `architecture`
  - `workflow`
  - `checklist`
- 第一批真实能力落地：
  - `codex` 官方 skill / GitHub skill / 本地 skill 安装与状态快照
  - `claude-code` 官方 / 第三方 marketplace plugin 安装与状态快照
  - `gemini-cli` 官方 extension 安装
  - `opencode` plugin 配置接入与本地插件同步

后续目标是继续把 manifest 升级为：

- 默认能力包清单
- 增强能力包清单
- 工具专属能力清单
- 当前状态与目标状态对比清单

当前还未完成的核心点：

- `codex / claude-code` 更广第三方生态的进一步自动化
- 三类来源的统一安装策略继续收敛
- 安装结果的深度校验
- 更完整的 role / memory / guide 初始化
- 默认使用范式和最佳实践引导

### 5. review 的边界

`manage.sh tool review` 的目标是验证：

- 命令面没有跑偏
- 文档和实现没有不一致
- 默认模板和运行清单还能正确生成
- 旧命令、旧概念、旧目录模型没有残留

它不应该做的事：

- 直接写真实官方全局目录
- 为了回归而覆盖用户现有配置
- 对线上正在使用的工具做破坏性卸载验证

因此当前 review 采用：

- 项目初始化回归：写入 `/tmp/ai-agent-tools-review/...`
- 全局初始化回归：通过临时配置文件把官方目录重定向到 `/tmp/ai-agent-tools-review/...`
- 默认报告回归：只校验关键输出，不碰真实现网配置

## 能力项元信息

能力包解析后的能力项，后续统一使用三类元信息驱动真实安装和检查：

- `source`
  - 官方
  - 第三方
  - GitHub / 本地包
- `install`
  - 目录接入
  - 官方安装命令
  - 交互式插件命令
  - 配置文件驱动
  - 模板渲染
- `risk`
  - `low`
  - `medium`
  - `high`

这些元信息不是为了展示，而是为了决定：

- 能不能自动安装
- 是否需要人工登录
- 是否默认启用
- 检查时该如何判断“已安装 / 已就绪 / 需人工处理”

## 工具分层

按产品形态分两类：

### 1. 通用助手型工具

代表：`OpenClaw`

特点：

- 本身是长期运行的服务
- 有 systemd / nginx / 证书 / 防火墙 / 外部接入
- 有消息平台、插件、技能、访问模式等更完整的运维面

因此它需要更完整的命令面，例如：

- `service install / configure / update / uninstall`
- `service report / check / logs / status`
- `config init / backup / restore / show`
- `skill install / remove / check / recommend`
- `plugin install / remove`
- `feishu check / guide`

### 2. 编程代理型工具

代表：`codex`、`claude-code`、`gemini-cli`、`opencode`

特点：

- 本质是 CLI 工具，不是重服务
- 更强调终端使用、官方目录、项目骨架、模型配置、审批与安全边界
- 不需要复制 OpenClaw 那一整套服务化命令

因此这类工具应保持更轻：

- 主链路：`service install`、`config init`、`service check`
- 可选运维：`service configure / update / uninstall`
- 轻量管理：后续补 `service report`、`config backup / restore / show`

这里的“更轻”不是能力更弱，而是命令更收敛：

- 日常最好只记三步：安装、项目初始化、检查
- 最佳实践初始化由 `service install` 和 `config init` 自动完成
- 扩展、hook、MCP、agent、memory 尽量通过配置与模板自动落地，不再拆成很多日常子命令

对应到用户真实场景，建议固定成下面的命令语义：

- 新装一个工具并应用全局最佳实践：
  - `service install`
- 给某个项目落最佳实践模板：
  - `config init --scope project`
- 已安装环境切模式、补增强、重放配置：
  - `service configure`
- 不是用本工具安装，但想迁移到我们的最佳实践：
  - 优先 `service configure`
  - 再用 `service check`
- 不确定当前状态或下一步动作：
  - 先 `service report`

为了进一步降低首次使用成本，顶层入口还应提供一个只输出最短路径的快速引导命令：

- `guide start`
  - 面向首次使用者
  - 优先给出 1-2 条可直接执行的命令
  - 不把完整命令面全部塞进首次帮助

## 能力模型

每个工具都按下面 7 层能力去实现。

### 1. 生命周期管理

必须具备：

- 安装
- 升级
- 卸载
- 重放配置
- 检查

对应命令：

- `service install`
- `service update`
- `service uninstall`
- `service configure`
- `service check`

### 2. 最佳实践初始化

必须具备：

- 初始化工具的官方全局目录
- 初始化项目目录骨架
- 初始化记忆文档、说明文档、规则文档
- 初始化扩展目录或扩展清单

对应命令：

- `config init --scope global|project`

### 3. 配置管理

必须具备：

- 一份容易理解的 `conf.example`
- 区分“常用项”和“高级项”
- 能对比当前真实配置和目标配置
- 检查命令默认只读，不直接覆盖现网

当前状态展示建议统一为：

- `一致`
- `不一致`
- `缺失`
- `未声明`

### 4. 扩展管理

这里不能假设所有工具都一样。

原则：

- 工具官方真实支持什么，就管理什么
- 工具只支持目录骨架或清单，就只暴露到那个层级
- 未验证的外部安装器，不要假装已经具备

当前理解应分三档：

- **完整管理**：像 OpenClaw 的 skill / plugin，可安装、移除、检查
- **半管理**：只负责初始化目录、生成清单、保留说明
- **未开放**：工具没有稳定官方接法时，不单独暴露命令

### 5. 运行与备份目录管理

目录模型应统一：

- 工具官方状态放在工具官方目录
- 工具侧生成的备份、清单、包装命令放在各自工具目录
- 备份默认放在 `scripts/<category>/<tool>/backups`
- 不额外制造一个独立的“中间运行层”
- `config init --scope global` 负责准备仓库运行模板和官方目录骨架
- `service install / configure / update` 才负责把目标配置同步到官方可生效位置

### 6. 检查与自检

必须具备：

- 工具级检查：安装状态、当前配置、目标配置、目录状态、清单状态
- 仓库级检查：脚本命令风格、旧概念残留、文档一致性、语法检查

对应命令：

- 工具级：`service check`
- 仓库级：`manage.sh tool review`

这里还要补一条验证原则：

- 先做隔离回归，保证命令、模板、目录和报告稳定
- 再做非破坏性实机验证，保证不影响当前正在使用的环境
- 不为了追求“全自动验证”而直接覆盖真实官方目录或现网配置

### 7. 使用范式与引导

我们的目标不只是“把工具安装好”，还要“把工具用好”。

因此后续必须补上：

- 默认 workflow
- 默认 role / subagent 分工
- 默认项目模板
- 默认最佳实践指引
- 最佳实践就绪度检查

这一层的目标是让用户安装完成后，不需要自己再摸索一套方法，默认就能按高质量范式使用工具。

## 当前实现评估

### OpenClaw

当前已经较接近目标。

已实现：

- 生命周期管理
- 服务化运维管理
- 配置管理
- 备份恢复
- 访问模式管理
- 飞书接入
- skill / plugin 管理
- 记忆插件和上下文增强

结论：

- 已接近“完整管理工具”

### Coding Agents

当前已经完成“可用的安装、初始化、能力包建模、清单化和检查”。

已实现：

- 安装 / 升级 / 卸载 / 配置重放 / 检查
- 全局 / 项目初始化
- 官方目录与工具目录管理
- 当前配置与目标配置对比
- 扩展目录与运行清单初始化
- 能力包配置与 manifest
- `service report`、`config show`
- 能力项元信息与数量摘要

已补到第一批实现：

- `service check / report` 已展示最佳实践就绪度
- `gemini-cli` 已支持官方名称、`github:org/repo`、`org/repo`、GitHub URL、本地路径这几类 extension 规格
- `opencode` 已把远程 GitHub / URL 插件来源纳入状态快照，并明确区分官方直连能力与人工落地边界
- `config init --scope project` 生成的共享模板已补角色分工、持续记忆、测试基线、发布与回滚检查单

当前验证结论：

- 隔离回归已经覆盖“新装初始化”和“项目模板初始化”
- 报告回归已经覆盖“建议动作、未就绪原因、最佳实践就绪度、能力包策略、双口径统计”
- 真实环境侧还需要继续补“安装后立即可用、迁移接管、升级重放”的非破坏性验证
- 各 coding agent 的项目 agents 目录已默认生成 `planner / implementer / reviewer / tester` 角色模板

尚未完全实现：

- 真正可用的扩展管理闭环
- 三类来源的真实安装器
- 安装后可用性校验
- 默认项目 workflow / role 模板进一步细化
- 更深入的最佳实践默认配置
- 各工具更深入的最佳实践默认配置
- 最佳实践使用指引进一步增强

结论：

- 当前已经是“可用的安装、初始化、检查和最佳实践建模工具”
- 下一阶段要进入“真实安装自动化”和“默认 workflow 落地”

## 扩展能力原则

关于 `skill / plugin / hook / mcp`，后续必须按工具真实能力分别处理。

### OpenClaw

- `skill`：完整管理
- `plugin`：完整管理
- 额外接入：飞书、长期记忆、上下文增强

### Codex

- `skills / agents / hooks / mcp` 有真实落点
- `project trust` 有真实落点
- 后续应优先做：
  - hook 管理
  - mcp 管理
  - skills / agents 模板管理
- `plugin` 是否单独暴露，要以官方真实能力为准，不能先假设

### Claude Code

- `skills / agents / rules / settings` 有真实落点
- `plugin / mcp / hook` 需要继续按官方能力确认深度
- 当前先保持“目录和清单初始化 + 配置管理”是合理的
- 真实插件安装要优先遵守官方交互式 `/plugin` 边界

### Gemini CLI

- `skills / policies / hooksConfig` 有真实落点
- `mcp` 需要继续按官方能力确认接法
- 已接入官方 extension 安装模型
- 已支持官方名称、GitHub 简写、GitHub 仓库、GitHub URL、本地路径这几类 extension 来源
- 安全策略与项目初始化也要继续做扎实

### OpenCode

- `skills / hooks / mcp / provider` 有真实落点
- 已接入 provider、plugin 配置和本地插件同步的第一批闭环
- 远程 GitHub / URL 来源已进入状态快照，但官方当前仍以 npm 包或本地 JS/TS 插件文件为准

## 真实安装原则

进入下一阶段后，真实安装必须遵守下面几条：

- 优先官方接法
- 再考虑第三方稳定接法
- 最后才考虑 GitHub / 本地包
- 不为自动化强行绕过官方交互边界
- 不新增一层和官方冲突的私有命令体系
- 默认基线只统计“脚本可自动落地”的真实安装项
- 当前通用默认基线固定为：核心开发、文档架构、质量、后端、前端五类能力
- 通用最佳实践模板、agents、hooks、memory 引导默认保留，但不强行记成插件或 skill 缺失

按当前研究，四个 coding agent 的真实安装方向应是：

- `Codex`
  - 优先 `skills` 目录和官方 skill 安装方式
- `Claude Code`
  - 优先官方 `/plugin` 体系
  - 自动化要以“准备、校验、指引”为主，避免强行伪造交互
- `Gemini CLI`
  - 优先官方 extension 安装模型
- `OpenCode`
  - 优先官方配置文件、本地插件目录和运行时插件机制

## 下一阶段详细任务

下一阶段不再扩命令面，只增强现有命令背后的能力。

### 第一优先级

- 为 `gemini-cli` 接入真实 extension 安装闭环
- 为 `opencode` 接入真实 plugin/config 落地
- 为 `codex` 接入真实 skill 安装闭环
- 为 `claude-code` 接入可控的插件接入策略

### 第二优先级

- 安装后可用性校验
- 失败重试、回退和降级
- 登录前提与人工确认提示

### 第三优先级

- 项目初始化模板增强
- 默认 role / workflow / memory 模板
- 开发、测试、架构、发布检查单
- 各工具最佳实践使用指南
- 最佳实践就绪度检查

### 完成标准

- `service install` 能真正把默认能力装起来
- `service check` 能准确说明“已安装 / 已配置 / 未生效 / 需要人工登录”
- `config init --scope project` 能生成一套可直接进入开发的最佳实践模板
- 用户能从初始化模板和文档里直接看见“怎么发挥这个工具的最大能力”
- 后续 `report / check / show` 能展示最佳实践就绪度
- `tool review` 能覆盖安装策略元信息和模板完整性

## 命令设计原则

统一要求：

- 命令风格统一为 `manage.sh 名词 动词 --xx xx`
- 帮助信息中文、简洁、见名知意
- 日常只要求记住少量主命令
- 高级命令放到可选层

分层要求：

### OpenClaw

- 允许更丰富的命令面
- 因为它本身就是服务型产品

### Coding Agents

- 不机械复制 OpenClaw 命令
- 只保留轻量且必要的命令面
- 不暴露没有真实实现的扩展命令

## 实施顺序

### 第一阶段

补齐 coding agents 的轻量管理闭环：

- `service report`
- `config backup`
- `config restore`
- `config show`

当前状态：

- `service report`、`config show` 已覆盖四个 coding agent
- `config backup / restore` 当前先保留在更需要它们的工具上，不强行每个工具都做一份

### 第二阶段

按工具真实能力补扩展管理，并把 manifest 升级为能力包视图：

- Codex：`hook / mcp / skills / agents`
- Claude Code：`plugin / skill / hook / subagent / mcp`
- Gemini CLI：`skills / policies / hooksConfig / mcp`
- OpenCode：`provider / plugin / agent / hook / mcp / skills`

当前状态：

- 已完成能力包 manifest、agent manifest 和配置层接入
- 真实扩展下载与安装仍留在后续阶段

### 第三阶段

继续打磨最佳实践默认配置和能力包：

- 更贴近各工具真实登录方式
- 更贴近各工具官方目录结构
- 更贴近项目开发使用场景
- 更贴近“通用默认能力包 + 工具专属能力包 + 增强能力包”

### 第四阶段

把最佳实践真正变成可启用、可校验、可回滚的运行模型：

- 能力包注册表
- 配置层启用能力包
- 同步与安装真实扩展
- 当前状态和目标状态一致性检查

## 判断标准

只有同时满足下面几条，才算真正达到目标：

- 能一键安装
- 能一键重放最佳实践配置
- 能安全升级和卸载
- 能清楚看出当前状态和目标状态
- 能管理官方目录与工具目录
- 能按工具真实能力管理扩展
- 帮助、文档、日志足够清晰
- 修改后可以通过统一 review
