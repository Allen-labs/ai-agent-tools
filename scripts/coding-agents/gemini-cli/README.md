# Gemini CLI Scripts

主文档先看：

- 使用：[../../README.md](../../README.md)
- 设计：[../../ARCHITECTURE.md](../../ARCHITECTURE.md)
- 任务追踪：[../../TASKS.md](../../TASKS.md)

这份文档只保留 Gemini CLI 的特有差异。

项目初始化默认会生成共享的 `.agents/project-context.md`、`.agents/architecture.md`、`.agents/workflow.md`、`.agents/checklist.md`，并补角色分工、持续记忆、测试和发布引导。

## 统一使用方式

Gemini CLI 也不改变统一入口和统一命令：

- 新装并应用最佳实践：`service install`
- 已装后切模式、补增强、重放配置：`service configure`
- 给项目落模板：`config init --scope project`
- 不确定当前状态：`service report`
- 验证是否达到推荐基线：`service check`

## 工具特有点

- 官方状态目录：
  - `~/.gemini`
- 工具目录本身承担备份、清单与生成配置：
  - `scripts/coding-agents/gemini-cli`
- 会初始化：
  - `~/.gemini/skills`
  - `~/.gemini/extensions`
  - `~/.gemini/policies`
  - `~/.gemini/agents`
- 真实扩展方向：
  - 优先官方 extension 安装模型
  - `service install / configure` 会真正尝试安装第一批官方 extension
  - `service check / report` 会区分缺失、未生效、需人工处理，并显示最佳实践就绪度
  - 默认基线只统计可自动安装的 extension；策略、agents、shared workflow 仍通过项目模板和清单默认落地
  - 当前工具专属默认包收敛为 `gemini-core + gemini-collaboration`
  - `PLUGIN_SPECS` 目前支持：
    - 官方名称：`workspace`
    - GitHub 简写：`github:your-org/your-extension`
    - GitHub 仓库：`your-org/your-extension`
    - GitHub URL：`https://github.com/your-org/your-extension`
    - 本地路径：`./extensions/your-extension`

## 快速使用

```bash
cd /root/codes/ai-agent-tools/scripts

bash manage.sh service install --tool-name gemini-cli --config ./coding-agents/gemini-cli/local.conf
bash manage.sh service configure --tool-name gemini-cli --config ./coding-agents/gemini-cli/local.conf
bash manage.sh config init --tool-name gemini-cli --config ./coding-agents/gemini-cli/local.conf --scope project --path /workspace/path
bash manage.sh service report --tool-name gemini-cli --config ./coding-agents/gemini-cli/local.conf
bash manage.sh service check --tool-name gemini-cli --config ./coding-agents/gemini-cli/local.conf
```
