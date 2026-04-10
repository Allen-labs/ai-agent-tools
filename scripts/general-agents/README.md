# General Agents Scripts

这里放通用型 AI 助手工具的入口。

主文档先看：

- 使用：[../README.md](../README.md)
- 设计：[../ARCHITECTURE.md](../ARCHITECTURE.md)
- 任务追踪：[../TASKS.md](../TASKS.md)

当前已接入：

- `openclaw`

统一使用方式：

- 新装并应用推荐配置：`service install`
- 已装后调整访问模式、飞书、技能、插件或安全策略：`service configure`
- 先看当前状态和建议动作：`service report`
- 详细排查：`service check`
- 查看运行日志：`service logs`

快速使用：

```bash
cd /root/codes/ai-agent-tools/scripts

bash manage.sh service install --tool-name openclaw --config ./general-agents/openclaw/local.conf
bash manage.sh service configure --tool-name openclaw --config ./general-agents/openclaw/local.conf
bash manage.sh service report --tool-name openclaw --config ./general-agents/openclaw/local.conf
bash manage.sh service check --tool-name openclaw --config ./general-agents/openclaw/local.conf
```

说明：

- 日常优先走顶层 `scripts/manage.sh`
- 如需单独调试，也可以直接进入工具子目录执行
- OpenClaw 现在会把长期治理文件写回 `~/.openclaw`
- 涉及 Base URL、Token、Secret 这类敏感项的帮助和报告默认只显示状态，不直接回显真实值
- `scenario` 交互阶段为便于确认，会明文展示 URL / 地址类当前值；Key / Token / Secret 继续隐藏输入
