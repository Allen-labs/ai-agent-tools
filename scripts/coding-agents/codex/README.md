# Codex Scripts

主文档先看：

- 使用：[../../README.md](../../README.md)
- 设计：[../../ARCHITECTURE.md](../../ARCHITECTURE.md)
- 任务追踪：[../../TASKS.md](../../TASKS.md)

这份文档只保留 Codex 的特有差异。

项目初始化默认会生成共享的 `.agents/project-context.md`、`.agents/architecture.md`、`.agents/workflow.md`、`.agents/checklist.md`，并补角色分工、持续记忆、测试和发布引导。

## 统一使用方式

Codex 仍然走统一入口和统一命令，不单独换心智：

- 新装并应用最佳实践：`service install`
- 已装后切模式、补增强、重放配置：`service configure`
- 给项目落模板：`config init --scope project`
- 不确定当前状态：`service report`
- 验证是否达到推荐基线：`service check`

## 工具特有点

- 额外支持 `project trust`
- 官方状态目录：
  - `~/.codex`
  - `~/.agents`
- `service install / configure / config init --scope global` 现在会补：
  - `~/.codex/agents/global-governance.md`
  - `~/.codex/agents/engineering-standards.md`
  - `~/.codex/agents/delivery-checklist.md`
  - `~/.codex/agents/memory-rules.md`
  - `~/.codex/agents/planner.md`
  - `~/.codex/agents/implementer.md`
  - `~/.codex/agents/reviewer.md`
  - `~/.codex/agents/tester.md`
- 工具目录本身承担备份、清单、包装命令：
  - `scripts/coding-agents/codex`
- 真实扩展方向：
  - 优先 `~/.agents/skills` 和官方 OpenAI skill 安装方式
  - `service install / configure / update` 会尝试安装默认官方 skill
  - `service check / report` 会生成 `skills.status`
  - `service check / report` 会显示全局治理模板和全局角色模板是否补齐
  - `service check / report` 除了数量，还会直接列出缺失 / 未生效 / 需人工处理的 skill 名称
  - `print_summary / config show` 对 Base URL 只显示是否已配置，不回显真实地址
  - `scenario` 在 `apikey` 模式下会把 provider、Base URL 一起当成关键接入项确认，不再藏在进阶项里
  - `scenario` 会先展示当前模式下准备安装的 skill，再决定是否增加或排除个别项
  - `SKILL_SPECS` 用于额外增加，`SKILL_EXCLUDES` 用于从默认模式方案里排除
  - 额外支持 `github:owner/repo[:path]`、GitHub URL 和本地 skill 目录
  - 默认基线只把可自动安装的官方 / GitHub / 本地 skill 算进真实安装状态；共享最佳实践模板仍会单独落地到项目目录
  - `security-best-practices`、`doc` 已收敛到 `codex-ecosystem` 增强包，不再放在默认即开层
  - 当前工具专属默认包收敛为 `codex-core + codex-review`
- 如使用第三方 provider + 自定义 env key，会生成：
  - `scripts/coding-agents/codex/bin/codex-managed`

## 快速使用

```bash
cd /root/codes/ai-agent-tools/scripts

bash manage.sh service install --tool-name codex --config ./coding-agents/codex/local.conf
bash manage.sh service configure --tool-name codex --config ./coding-agents/codex/local.conf
bash manage.sh config init --tool-name codex --config ./coding-agents/codex/local.conf --scope project --path /workspace/path
bash manage.sh service report --tool-name codex --config ./coding-agents/codex/local.conf
bash manage.sh service check --tool-name codex --config ./coding-agents/codex/local.conf
```
