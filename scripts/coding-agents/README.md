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
- 日常优先只记：
  - `service install`
  - `service configure`
  - `config init`
  - `service report`
  - `service check`
- `service check` 只读，不直接覆盖现有配置
- 扩展目录和 manifest 由 `service install / config init` 自动准备

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

## 当前能力边界

- 已完成：
  - 安装 / 更新 / 卸载 / 配置重放 / 检查
  - 全局 / 项目初始化
  - 能力包配置与 manifest
  - `service report`
  - `config show`
  - 共享项目模板：`project-context / architecture / workflow / checklist`
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
