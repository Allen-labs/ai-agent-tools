# OpenCode Scripts

主文档先看：

- 使用：[../../README.md](../../README.md)
- 设计：[../../ARCHITECTURE.md](../../ARCHITECTURE.md)
- 任务追踪：[../../TASKS.md](../../TASKS.md)

这份文档只保留 OpenCode 的特有差异。

项目初始化默认会生成共享的 `.agents/project-context.md`、`.agents/architecture.md`、`.agents/workflow.md`、`.agents/checklist.md`，并补角色分工、持续记忆、测试和发布引导。

## 统一使用方式

OpenCode 同样保持统一入口和统一命令：

- 新装并应用最佳实践：`service install`
- 已装后切模式、补增强、重放配置：`service configure`
- 给项目落模板：`config init --scope project`
- 不确定当前状态：`service report`
- 验证是否达到推荐基线：`service check`

## 工具特有点

- 官方状态目录：
  - `~/.config/opencode`
- `service install / configure / config init --scope global` 现在会补：
  - `~/.config/opencode/agents/global-governance.md`
  - `~/.config/opencode/agents/engineering-standards.md`
  - `~/.config/opencode/agents/delivery-checklist.md`
  - `~/.config/opencode/agents/memory-rules.md`
  - `~/.config/opencode/agents/planner.md`
  - `~/.config/opencode/agents/implementer.md`
  - `~/.config/opencode/agents/reviewer.md`
  - `~/.config/opencode/agents/tester.md`
- 工具目录本身承担备份、清单、包装命令：
  - `scripts/coding-agents/opencode`
- 会初始化：
  - `~/.config/opencode/opencode.json`
  - `~/.agents/skills`
  - `~/.config/opencode/plugins`
  - `~/.config/opencode/agents`
- 项目目录会生成：
  - `opencode.json`
  - `.opencode/plugins`
  - `.opencode/agents`
- 如使用 provider API Key，会生成：
  - `scripts/coding-agents/opencode/bin/opencode-managed`
- 真实扩展方向：
  - 优先官方配置文件、本地插件目录和运行时插件机制
  - `service install / configure` 会把默认 npm plugin 写入 `opencode.json`
  - 默认 npm plugin 安装后会重新回写目标 `opencode.json`，避免官方 `opencode plugin` 命令覆盖掉我们声明的完整插件清单
  - `service check / report` 会同时识别官方包缓存和 npm 兜底安装目录，不再只按单一路径误判
  - `config show` 对 Base URL 只显示是否已配置，不回显真实地址
  - `service check / report` 会显示官方 `agents/` 目录治理模板和角色模板补齐度
  - `openai` provider 现在支持通过 `API_BASE_URL + PROVIDER_ENV_KEY + PROVIDER_API_VALUE` 接入 OpenAI-compatible 网关
  - `scenario` 会先展示当前模式下准备安装的 plugin，再决定是否增加或排除个别项
  - `PLUGIN_SPECS` 用于额外增加，`PLUGIN_EXCLUDES` 用于从默认模式方案里排除
  - 默认基线只统计 npm 包和本地可落地插件；共享最佳实践能力继续通过模板、agents、清单落地
  - `opencode-background-agents` 已收敛到 `opencode-automation` 进阶包，不再放在默认即开层
  - 当前工具专属默认包维持 `opencode-core + opencode-workspace`，不再额外堆叠 automation / memory / safety 类默认插件
  - `PLUGIN_SPECS` 目前支持：
    - npm 包名：`opencode-supermemory`
    - 本地 JS/TS 插件文件或路径：`./plugins/my-plugin.ts`
    - 远程 GitHub / URL 来源登记：`github:your-org/your-plugin`、`https://github.com/your-org/your-plugin`
  - `service check / report` 会区分已安装、已配置、缺失和需人工处理，并显示最佳实践就绪度
  - 远程 GitHub / URL 来源会进入状态快照，但官方当前仍以 npm 包或本地 JS/TS 插件文件为准

## 快速使用

```bash
cd /root/codes/ai-agent-tools/scripts

bash manage.sh service install --tool-name opencode --config ./coding-agents/opencode/local.conf
bash manage.sh service configure --tool-name opencode --config ./coding-agents/opencode/local.conf
bash manage.sh config init --tool-name opencode --config ./coding-agents/opencode/local.conf --scope project --path /workspace/path
bash manage.sh service report --tool-name opencode --config ./coding-agents/opencode/local.conf
bash manage.sh service check --tool-name opencode --config ./coding-agents/opencode/local.conf
```
