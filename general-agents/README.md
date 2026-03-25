# General Agents 导引（2026）

> 通用 AI 助手工具概览与选型参考

General Agents 是定位更广泛的 AI 助手，不局限于编程场景，通常支持多渠道接入（消息平台、语音、移动端），适合个人自动化、日常助手、跨设备工作流等场景。

---

## 工具列表

| 工具 | 开发商 | 核心定位 | 开源 | 文档 |
|------|--------|---------|------|------|
| **OpenClaw** | Peter Steinberger | 本地优先个人助手，20+ 消息平台接入，自托管 Gateway | MIT | [→](./openclaw.md) |

---

## OpenClaw 速览

OpenClaw 是目前最成熟的自托管个人 AI 助手，~335K GitHub Stars。

**核心特性**：
- **20+ 消息渠道**：WhatsApp、Telegram、Discord、Slack、Signal、iMessage 等
- **33+ AI 提供商**：Anthropic、OpenAI、Google、Ollama（本地）等，随时切换
- **本地优先**：Gateway 运行在你自己的设备，数据不经过第三方
- **Skills 系统**：三层级（Bundled / Managed / Workspace），ClawHub 社区技能市场
- **自动化**：Webhook、Cron 定时任务、Gmail Pub/Sub 事件触发
- **移动端**：iOS / Android companion app，语音唤醒，Android 设备远程控制
- **Tailscale 集成**：安全远程访问，无需暴露公网端口

**典型使用场景**：
```
手机 WhatsApp → "提醒我明天下午 3 点开会" → OpenClaw Gateway → 创建日历事件
手机 Telegram → "总结今天的邮件" → OpenClaw → 读取 Gmail → 返回摘要
告警系统 Webhook → OpenClaw → 发送分析报告到 Slack
```

**快速安装**：
```bash
curl -fsSL https://openclaw.ai/install.sh | bash
openclaw onboard --install-daemon
```

完整指南 → [openclaw.md](./openclaw.md)

---

## 与 Coding Agents 的区别

| 维度 | Coding Agents | General Agents |
|------|--------------|----------------|
| **主要场景** | 代码编写、调试、重构 | 日常任务、个人自动化、多渠道交互 |
| **交互方式** | 终端 CLI / IDE | 消息平台 / 语音 / 移动端 |
| **部署方式** | 本地 CLI 工具，按需启动 | 自托管 Gateway，常驻后台 |
| **典型用法** | `claude "帮我重构这个函数"` | WhatsApp 发消息触发任务 |
| **使用时机** | 坐在电脑前开发时 | 随时随地，任何设备 |

> 两者互补而非替代：OpenClaw 处理日常任务和提醒，Coding Agents 处理具体编程任务。

> 返回总导览 → [README](../README.md)

---

## 快速速查

### 安装

| 工具 | 命令 |
|------|------|
| OpenClaw（macOS/Linux）| `curl -fsSL https://openclaw.ai/install.sh \| bash` |
| OpenClaw（Windows）| `iwr -useb https://openclaw.ai/install.ps1 \| iex` |
| OpenClaw（npm）| `npm install -g openclaw@latest` |
| 首次初始化 | `openclaw onboard --install-daemon` |

### 常用 CLI 命令

| 命令 | 说明 |
|------|------|
| `openclaw status` | 查看 Gateway 状态 |
| `openclaw doctor` | 健康检查 |
| `openclaw logs` | 查看日志 |
| `openclaw restart` | 重启 Gateway |
| `openclaw update` | 更新版本 |
| `openclaw channels list` | 查看渠道状态 |
| `openclaw channels login <channel>` | 登录渠道（如 whatsapp）|
| `openclaw models list` | 查看可用模型 |
| `openclaw models set <model>` | 切换模型 |
| `openclaw skills install <name>` | 安装技能 |

### 聊天内命令

| 命令 | 说明 |
|------|------|
| `/new` | 开始新会话 |
| `/compact` | 压缩上下文 |
| `/think <level>` | 设置推理深度（off/minimal/low/medium/high/xhigh）|
| `/model <id>` | 临时切换模型 |
| `/status` | 查看 Gateway 和渠道状态 |
| `/usage` | 查看 Token 使用量 |
| `/restart` | 重启 Gateway |

### 配置路径速查

| 配置项 | 路径 |
|--------|------|
| 全局配置 | `~/.openclaw/config.json` |
| Skills 目录 | `~/.openclaw/skills/` |
| 日志目录 | `~/.openclaw/logs/` |
| 凭证目录 | `~/.openclaw/credentials/` |

### 常用环境变量

| 变量 | 说明 |
|------|------|
| `ANTHROPIC_API_KEY` | Anthropic API Key |
| `OPENAI_API_KEY` | OpenAI API Key |
| `TELEGRAM_BOT_TOKEN` | Telegram Bot Token |
| `DISCORD_BOT_TOKEN` | Discord Bot Token |
| `OPENCLAW_CONFIG` | 自定义配置文件路径 |

---

*2026-03-25 · 持续更新*
