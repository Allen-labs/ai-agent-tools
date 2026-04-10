# Coding Agents Scripts

这里放编程型 AI 工具的统一入口和工具差异说明。

主文档先看：

- 使用：[../README.md](../README.md)
- 设计：[../ARCHITECTURE.md](../ARCHITECTURE.md)
- 任务追踪：[../TASKS.md](../TASKS.md)

这份文档只保留 coding agents 这一类工具的共性约束和工具差异，不重复大段设计说明。

## 已接入工具

- `claude-code`
- `codex`
- `gemini-cli`
- `opencode`

## 共性约束

- 顶层 `manage.sh` 负责统一路由
- 用户侧入口和命令保持统一，不因为工具不同而改变主用法
- 官方状态目录保留在各工具默认位置
- 工具侧生成的备份、清单、包装命令统一落在各自工具目录
- 官方 `agents/` 目录现在承载全局治理模板和全局角色模板
- 日常优先只记：
  - `service install`
  - `service configure`
  - `config init`
  - `service report`
  - `service check`
- `service check` 只读，不直接覆盖现有配置
- `service report / check / config show` 默认对 Base URL、Key、Token、Secret 这类敏感项只给状态，不直接回显真实值
- `scenario` 交互阶段为便于确认，会明文展示 URL / 地址类当前值；Key / Token / Secret 继续隐藏输入
- `service check / report` 会把缺失、未生效、待生效、需人工处理的能力项名称直接列出来，避免只给数量
- 扩展目录和 manifest 由 `service install / config init` 自动准备

## 最佳实践包含什么

- 安装、更新、卸载、接管和状态检查
- 官方全局目录与项目目录的初始化
- 官方 `agents/` 目录里的全局治理模板、角色模板和记忆回写规则
- 推荐模型、认证方式、provider 与安全策略
- `standard / advanced / exploration` 三档模式
- 默认能力包覆盖 `skill / plugin / extension / hook / MCP / agent / memory`
- 项目模板覆盖上下文、架构、流程、检查单和角色分工
- `service report / check` 的就绪度、差异项和建议动作
- `scenario` 的交互式补齐与执行闭环

## 统一使用方式

不管是 `codex`、`claude-code`、`gemini-cli` 还是 `opencode`，用户都优先按同一套场景理解：

### 1. 从零安装并进入最佳实践

```bash
bash manage.sh service install --tool-name codex --config ./coding-agents/codex/local.conf --yes
```

如果要把项目模板也一起落好，再补：

```bash
bash manage.sh config init --tool-name codex --config ./coding-agents/codex/local.conf --scope project --path /workspace/project --yes
```

### 2. 已经用本工具安装，后续想增强、切模式或改配置

```bash
bash manage.sh service configure --tool-name codex --config ./coding-agents/codex/local.conf --yes
```

### 3. 不是用本工具安装，但想迁移到我们的最佳实践

```bash
bash manage.sh service configure --tool-name codex --config ./coding-agents/codex/local.conf --yes
bash manage.sh service check --tool-name codex --config ./coding-agents/codex/local.conf
```

如果不确定当前环境状态，先执行：

```bash
bash manage.sh service report --tool-name codex --config ./coding-agents/codex/local.conf
```

结论上，coding agents 的统一心智就是：

- 新装用 `service install`
- 已装重放配置用 `service configure`
- 项目落模板用 `config init`
- 先看状态用 `service report`
- 验证推荐基线用 `service check`

补充：

- `scenario` 在 `install / enhance / migrate` 时，会先补关键接入项，再展示当前模式下要安装的主能力
- 这里的“主能力”按工具不同分别是：`codex=skill`、`claude-code=plugin`、`gemini-cli=extension`、`opencode=plugin`
- 如果用户要高阶定制，可以在 `scenario` 里直接增加或排除个别项
- 对配置文件来说，`*_SPECS` 是额外增加，`*_EXCLUDES` 是从当前模式默认方案里排除

## 默认基线原则

- 默认只放稳定、通用、可自动落地的核心能力
- 当前通用默认基线固定为：`common-core + common-docs-architecture + common-quality + common-backend + common-frontend`
- 工具专属默认包只保留该工具最原生、最稳定、最适合自动落地的能力，避免和通用基线重复
- 当前工具专属默认包收敛为：
  - `codex`: `codex-core + codex-review`
  - `claude-code`: `claude-workflow + claude-review`
  - `gemini-cli`: `gemini-core + gemini-collaboration`
  - `opencode`: `opencode-core + opencode-workspace`
- 当前工具专属增强包建议为：
  - `codex`: `codex-ecosystem + codex-frontend + codex-research`
  - `claude-code`: `claude-ui + claude-memory + claude-ecosystem`
  - `gemini-cli`: `gemini-ui + gemini-data`
  - `opencode`: `opencode-automation + opencode-memory + opencode-safety`
- 强依赖第三方服务、需要额外账号或权限的能力，默认放增强包
- `common-frontend` 现在保留所有工具都高频适用的前端基线，例如前端设计、定向测试和 `playwright`；更依赖外部设计系统或第三方生态的能力再放工具专属增强包
- 最佳实践模板、hooks、agents、memory 引导会默认落地，但不强行算成“必须安装成功的插件”
- `service check / report` 中的真实安装状态，只统计当前工具能够自动处理的那部分能力

## 当前已落地范围

- 四个 coding tools 已全部支持统一入口与统一帮助
- `scenario` 已支持关键配置补齐、返回上一层、退出、执行前确认
- `scenario` 已支持按当前模式预览主能力安装计划，并增删个别项
- 四个工具的 `config show --section extensions` 已统一展示模式、默认包、显式增加项和排除项
- 四个工具的 `conf.example` 已统一提供 `*_SPECS / *_EXCLUDES` 示例口径
- 四个工具的 `service install / configure / config init --scope global` 已补官方 `agents/` 目录治理模板
- 四个工具的 `service report / check` 已直接显示全局治理模板和全局角色模板补齐度

## 当前能力边界

- 已完成：
  - 安装 / 更新 / 卸载 / 配置重放 / 检查
  - 全局 / 项目初始化
  - 能力包配置与 manifest
  - `service report`
  - `config show`
  - 共享项目模板：`project-context / architecture / workflow / checklist`
  - 官方 `agents/` 目录治理模板：`global-governance / engineering-standards / delivery-checklist / memory-rules`
  - 官方 `agents/` 目录角色模板：`planner / implementer / reviewer / tester`
  - 项目模板已补角色分工、持续记忆、测试基线、发布与回滚检查单
  - 项目 agents 目录已默认生成 `planner / implementer / reviewer / tester` 角色模板
  - `service check / report` 的最佳实践就绪度
  - `codex` 第一批官方 / GitHub / 本地 skill 真正落地与 `skills.status`
  - `claude-code` 第一批官方 / 第三方 marketplace plugin 真正落地与 `plugins.status`
  - `gemini-cli` 第一批 extension 真正落地，且支持官方名称、`github:org/repo`、`org/repo`、GitHub URL、本地路径
  - `opencode` 第一批 plugin 配置接入与本地插件同步，并把远程 GitHub / URL 来源纳入状态快照
- 还在后续阶段：
  - `codex / claude-code` 更深校验与更广的第三方生态
  - 默认 role / guide 模板进一步增强

## 工具差异

- 这些差异只影响内部实现、配置项和报告内容，不影响统一入口和主命令。
- `codex`
  - 额外支持 `project trust`
  - 更偏 `skills / agents / hooks / mcp`
- `claude-code`
  - 更偏 `settings / skills / plugins / agents`
  - 插件接入要优先尊重官方交互式边界
- `gemini-cli`
  - 更偏 `extensions / policies / hooksConfig / agents`
- `opencode`
  - 更偏 `opencode.json / plugins / agents / hooks`
  - 官方扩展主路径仍以 npm 包和本地 JS/TS 插件文件为准

## 快速使用

```bash
cd /root/codes/ai-agent-tools/scripts

bash manage.sh service install --tool-name codex --config ./coding-agents/codex/local.conf
bash manage.sh config init --tool-name codex --config ./coding-agents/codex/local.conf --scope project --path /workspace/path
bash manage.sh service check --tool-name codex --config ./coding-agents/codex/local.conf
```

如需单独调试，也可以进入 `scripts/coding-agents/<tool>/` 直接执行子目录里的 `manage.sh`。
