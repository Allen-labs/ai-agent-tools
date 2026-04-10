# Claude Code Scripts

主文档先看：

- 使用：[../../README.md](../../README.md)
- 设计：[../../ARCHITECTURE.md](../../ARCHITECTURE.md)
- 任务追踪：[../../TASKS.md](../../TASKS.md)

这份文档只保留 Claude Code 的特有差异。

项目初始化默认会生成共享的 `.agents/project-context.md`、`.agents/architecture.md`、`.agents/workflow.md`、`.agents/checklist.md`，并补角色分工、持续记忆、测试和发布引导。

## 统一使用方式

Claude Code 也保持统一入口和统一命令：

- 新装并应用最佳实践：`service install`
- 已装后切模式、补增强、重放配置：`service configure`
- 给项目落模板：`config init --scope project`
- 不确定当前状态：`service report`
- 验证是否达到推荐基线：`service check`

## 工具特有点

- 官方状态目录：
  - `~/.claude`
  - `~/.claude.json`
- `service install / configure / config init --scope global` 现在会补：
  - `~/.claude/agents/global-governance.md`
  - `~/.claude/agents/engineering-standards.md`
  - `~/.claude/agents/delivery-checklist.md`
  - `~/.claude/agents/memory-rules.md`
  - `~/.claude/agents/planner.md`
  - `~/.claude/agents/implementer.md`
  - `~/.claude/agents/reviewer.md`
  - `~/.claude/agents/tester.md`
- 工具目录本身承担备份、清单与生成配置：
  - `scripts/coding-agents/claude-code`
- 默认保留现有：
  - `settings.local.json`
  - `~/.claude/CLAUDE.md`
- API Key / Token 模式默认会同步：
  - `~/.claude.json`
  - 写入 `hasCompletedOnboarding=true`，跳过首次登录引导
- `service report / check` 会把 `~/.claude.json` 的引导跳过状态一并打出来
- `service report / check` 会把官方 `agents/` 目录治理模板和角色模板补齐度一并打出来
- `service report / check / config show` 对 Base URL 只做脱敏展示，不直接回显个人网关地址
- 真实扩展方向：
  - 优先官方 marketplace 和 `claude plugin install`
  - `service install / configure / update` 会尝试自动安装默认 plugin
  - `service check / report` 会生成 `plugins.status`
  - 当前默认 plugin 收敛到更稳的工作流与评审集合
  - `scenario` 会先展示当前模式下准备安装的 plugin，再决定是否增加或排除个别项
  - `PLUGIN_SPECS` 用于额外增加，`PLUGIN_EXCLUDES` 用于从默认模式方案里排除
  - 第三方来源支持 `plugin@github:owner/repo` 和 `github:owner/repo`
  - `superpowers`、`claude-code-setup`、`security-guidance` 已收敛到 `claude-ecosystem` 增强包，不再放在默认即开层
  - 默认基线只把可自动处理的 marketplace plugin 算进真实安装状态；通用最佳实践继续通过模板、agents、清单落地
  - 当前工具专属默认包收敛为 `claude-workflow + claude-review`

## 快速使用

```bash
cd /root/codes/ai-agent-tools/scripts

bash manage.sh service install --tool-name claude-code --config ./coding-agents/claude-code/local.conf
bash manage.sh service configure --tool-name claude-code --config ./coding-agents/claude-code/local.conf
bash manage.sh config init --tool-name claude-code --config ./coding-agents/claude-code/local.conf --scope project --path /workspace/path
bash manage.sh service report --tool-name claude-code --config ./coding-agents/claude-code/local.conf
bash manage.sh service check --tool-name claude-code --config ./coding-agents/claude-code/local.conf
```

如果你走第三方网关，至少确认这几项：

- `AUTH_MODE=api-key` 或 `auth-token`
- `ANTHROPIC_BASE_URL=...`
- `ANTHROPIC_API_KEY` 或 `ANTHROPIC_AUTH_TOKEN`
- `CLAUDE_SKIP_ONBOARDING=1`
