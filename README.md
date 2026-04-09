# AI Agent Tools 导览（2026）

> 覆盖主流 AI Agent 工具的完整指南与选型参考

---

## 目录结构

```
ai-agent-tools/
├── README.md                  ← 本文（总导览）
├── scripts/
│   ├── manage.sh              ← 顶层统一入口
│   ├── README.md              ← 可执行脚本与运维入口总览
│   ├── shared/
│   │   └── lib/
│   ├── general-agents/
│   │   ├── README.md
│   │   └── openclaw/
│   │       ├── README.md      ← OpenClaw 安装与运维脚本入口
│   │       ├── manage.sh      ← OpenClaw 主入口
│   │       ├── conf.example   ← OpenClaw 配置样例
│   │       └── lib/
│   └── coding-agents/
│       ├── README.md
│       ├── manage.sh
│       ├── claude-code/
│       ├── codex/
│       ├── gemini-cli/
│       └── opencode/
├── coding-agents/
│   ├── README.md              ← Coding Agents 选型对比指南
│   ├── claude-code.md         ← Claude Code 完整指南
│   ├── codex.md               ← OpenAI Codex CLI 完整指南
│   ├── gemini-cli.md          ← Google Gemini CLI 完整指南
│   └── opencode.md            ← OpenCode 完整指南
└── general-agents/
    ├── README.md              ← General Agents 导引
    └── openclaw.md            ← OpenClaw 完整指南
```

---

## Coding Agents

在终端中运行的 AI 编程助手，具备读写代码、执行命令、调用外部工具的能力，可自主完成多步骤开发任务。

| 工具 | 开发商 | 核心定位 | Stars | 文档 |
|------|--------|---------|-------|------|
| **Claude Code** | Anthropic | 代码质量最高，生态最丰富，复杂任务首选 | ~80K | [→](./coding-agents/claude-code.md) |
| **Codex CLI** | OpenAI | 终端操作最强，OS 级沙盒，Token 效率最高 | ~66K | [→](./coding-agents/codex.md) |
| **Gemini CLI** | Google | 免费入门，1M 超长上下文，原生多模态 | ~98K | [→](./coding-agents/gemini-cli.md) |
| **OpenCode** | SST 团队 | 开源 MIT，提供商无关，LSP 原生支持 | ~130K | [→](./coding-agents/opencode.md) |

> 详细选型对比、基准测试数据、混合工作流 → [Coding Agents 选型指南](./coding-agents/README.md)

---

## General Agents

通用 AI 助手，不限于编程场景，可通过消息平台、语音、移动端等多种方式交互，适合日常助手、个人自动化等场景。

| 工具 | 开发商 | 核心定位 | Stars | 文档 |
|------|--------|---------|-------|------|
| **OpenClaw** | Peter Steinberger | 本地优先个人助手，20+ 消息平台，自托管 Gateway | ~335K | [→](./general-agents/openclaw.md) |

> 详细导引 → [General Agents 导引](./general-agents/README.md)

---

## 如何选择

**需要 AI 帮你写代码 / 调试 / 重构？** → [Coding Agents](./coding-agents/README.md)

**需要随时随地用手机和 AI 交互、处理日常任务？** → [General Agents](./general-agents/README.md)

两类工具互补而非替代，可以同时使用：OpenClaw 处理日常提醒和信息查询，Claude Code / OpenCode 处理具体编程任务。

---

## Scripts

如果你需要直接安装、更新或运维某个工具，请优先看：

- [Scripts 总览](./scripts/README.md)
- [OpenClaw Scripts](./scripts/general-agents/openclaw/README.md)
- 变更脚本后先执行：`cd scripts && bash manage.sh tool review`

当前 OpenClaw 脚本已覆盖：

- 安装、更新、配置重放、状态检查、备份恢复
- 飞书接入检查与流式输出配置
- skill / plugin 的依赖安装、检查、移除
- 官方状态目录 / 项目层初始化：全局层 / 项目层
- 工具侧生成的备份与静态包装脚本默认写回 `scripts/general-agents/openclaw`
- 执行权限三档：`safe` / `ops` / `admin`

当前 Coding Agents 脚本已覆盖：

- `claude-code`、`codex`、`gemini-cli`、`opencode`
- 日常优先使用 `service install`、`config init`、`service check`
- `service configure/update/uninstall` 作为可选运维命令保留
- `codex` 额外保留 `project trust`
- 官方状态目录保持各工具默认位置，备份、清单和包装命令默认写回各自工具目录
- 已支持初始化全局 / 项目记忆文档、官方目录骨架和运行清单
- 扩展目录与清单由安装或初始化阶段自动准备，独立扩展安装器留到下一阶段
- `service check` 已支持直接对比当前配置与目标配置，优先用于安全检查，不会直接覆盖现有配置

---

## 共性：主流工具都支持

- **MCP（Model Context Protocol）**：连接数据库、GitHub、外部 API 等外部工具
- **Open Agent Skills Standard**：可复用工作流 SOP，跨工具通用，一次编写多处运行
- **非交互 / CI 模式**：无人值守集成到 CI/CD 流水线
- **本地模型支持**：部分工具（OpenCode、OpenClaw）支持 Ollama 本地模型，数据不出本机

---

*2026-03-25 · 持续更新*
