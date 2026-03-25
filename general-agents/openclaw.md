# OpenClaw 完整指南（2026）

> 本地优先 · 多渠道接入 · 自托管 · MIT 开源
>
> 通过 WhatsApp、Telegram、Slack 等消息平台与 AI 交互的个人助手

---

## 目录

1. [什么是 OpenClaw](#1-什么是-openclaw)
2. [安装](#2-安装)
3. [快速开始](#3-快速开始)
4. [渠道配置（Channels）](#4-渠道配置channels)
5. [AI 模型配置](#5-ai-模型配置)
6. [配置系统](#6-配置系统)
7. [Gateway 架构](#7-gateway-架构)
8. [Skills 系统](#8-skills-系统)
9. [自动化功能](#9-自动化功能)
10. [安全模型](#10-安全模型)
11. [会话管理](#11-会话管理)
12. [移动端与设备操作](#12-移动端与设备操作)
13. [聊天命令](#13-聊天命令)
14. [与 Coding Agents 的区别](#14-与-coding-agents-的区别)
15. [快速速查](#15-快速速查)

---

## 1. 什么是 OpenClaw

OpenClaw 是一个**本地优先、自托管的个人 AI 助手**，核心理念是：AI 助手运行在你自己的设备上，通过你日常使用的消息平台（WhatsApp、Telegram、Slack、Discord 等）来交互，而不是打开一个新的 App 或网页。

| 属性 | 详情 |
|------|------|
| **GitHub** | `github.com/openclaw/openclaw` |
| **开源协议** | MIT |
| **GitHub Stars** | ~335K |
| **创始人** | Peter Steinberger（PSPDFKit 创始人）|
| **实现语言** | TypeScript（pnpm monorepo）|
| **版本格式** | `vYYYY.M.D`（稳定版），`vYYYY.M.D-beta.N`（测试版）|
| **官方文档** | [docs.openclaw.ai](https://docs.openclaw.ai) |

**核心定位**：不是 CLI 编程助手（不同于 Claude Code / Codex / OpenCode），而是**个人全能助手**——帮你管理日程、处理邮件、自动化任务、回答问题，用你已有的消息 App 作为界面，无需学习新工具。

**典型使用场景**：
- 在 WhatsApp 给自己发消息让 AI 帮你查信息、写内容
- 用 Telegram Bot 触发定时任务和提醒
- 手机上随时随地和 AI 助手交互，助手运行在家里的服务器上
- 自动处理邮件、通知、告警响应

---

## 2. 安装

### 2.1 系统要求

- **Node.js 24**（推荐）或 Node 22.16+
- 推荐包管理器：pnpm
- Windows 用户需要 WSL2
- Docker 部署最低需要 **2 GB RAM**

### 2.2 快速安装

```bash
# macOS / Linux
curl -fsSL https://openclaw.ai/install.sh | bash

# 或通过包管理器
npm install -g openclaw@latest
pnpm add -g openclaw@latest
```

```powershell
# Windows（PowerShell）
iwr -useb https://openclaw.ai/install.ps1 | iex
```

### 2.3 首次初始化

```bash
# 引导式配置（推荐，约 2 分钟完成）
opencode onboard --install-daemon
```

`--install-daemon` 将 Gateway 注册为系统后台服务（macOS launchd / Linux systemd / Windows schtasks），开机自动启动。

**onboard 常用参数**：

| 参数 | 说明 |
|------|------|
| `--reset` | 重置配置、凭证和会话后重新初始化 |
| `--flow <quickstart\|advanced\|manual>` | 选择初始化流程 |
| `--auth-choice` | 选择 AI 提供商（openai / anthropic / gemini / ollama 等）|
| `--gateway-bind <loopback\|lan\|tailnet\|auto\|custom>` | Gateway 绑定模式 |
| `--tailscale <off\|serve\|funnel>` | Tailscale 网络模式 |

### 2.4 Docker / Podman 安装

```bash
# 使用预构建镜像
export OPENCLAW_IMAGE="ghcr.io/openclaw/openclaw:latest"
./scripts/docker/setup.sh

# 或手动
docker build -t openclaw:local -f Dockerfile .
docker compose up -d openclaw-gateway
```

**Docker 环境变量**：

| 变量 | 说明 |
|------|------|
| `OPENCLAW_IMAGE` | 使用远程镜像而非本地构建 |
| `OPENCLAW_SANDBOX` | 启用沙盒（`1` 或 `true`）|
| `OPENCLAW_DOCKER_SOCKET` | 覆盖 Docker socket 路径 |
| `OPENCLAW_HOME_VOLUME` | 持久化 `/home/node` |
| `OPENCLAW_EXTRA_MOUNTS` | 额外 bind mount |

### 2.5 Nix 安装

通过 `nix-openclaw` Home Manager 模块安装，支持声明式配置、固定版本、launchd 服务和版本回滚。

```bash
export OPENCLAW_NIX_MODE=1  # 禁用自动更新，适合 Nix 声明式管理
```

### 2.6 VPS / 云部署

推荐架构：Gateway 运行在 VPS，本地通过 SSH tunnel 或 Tailscale Serve 连接。

- 支持 Fly.io（`fly.toml`）和 Render（`render.yaml`）
- 详细指南：`docs.openclaw.ai/install/vps`

---

## 3. 快速开始

```bash
# 查看 Gateway 状态
openclaw status

# 健康检查（排查配置问题）
openclaw doctor

# 查看日志
openclaw logs

# 重启 Gateway
openclaw restart

# 更新到最新版本
openclaw update

# 渠道管理
openclaw channels list          # 查看所有渠道状态
openclaw channels login whatsapp # 扫码登录 WhatsApp

# 模型管理
openclaw models list            # 查看可用模型
openclaw models set anthropic/claude-sonnet-4-6  # 切换模型
```

---

## 4. 渠道配置（Channels）

渠道是 OpenClaw 与用户交互的入口，配置在 `openclaw.config.json` 的 `channels` 字段。

### 4.1 支持的渠道列表

| 渠道 | 认证方式 | 备注 |
|------|----------|------|
| **WhatsApp** | QR 码扫描（Baileys）| 最常用 |
| **Telegram** | Bot Token | 配置最简单，推荐新手 |
| **Discord** | Bot Token | — |
| **Slack** | Bot Token + App Token | — |
| **Google Chat** | Chat API | — |
| **Signal** | signal-cli | 需额外安装 signal-cli |
| **iMessage（BlueBubbles）** | serverUrl + password | macOS 专属 |
| **Microsoft Teams** | — | — |
| **Matrix** | — | — |
| **飞书（Feishu）** | — | — |
| **LINE** | — | — |
| **Mattermost** | — | — |
| **Nextcloud Talk** | — | — |
| **IRC** | — | — |
| **Nostr** | — | — |
| **Synology Chat** | — | — |
| **Twitch** | — | — |
| **Zalo** | — | — |
| **WebChat** | 无需配置 | 内置 Web UI |
| 插件渠道 | 按插件要求 | 通过 plugin channels 扩展 |

### 4.2 渠道配置示例

```jsonc
{
  "channels": {
    // Telegram — 推荐新手从这里开始
    "telegram": {
      "botToken": "{env:TELEGRAM_BOT_TOKEN}"
    },

    // Discord
    "discord": {
      "token": "{env:DISCORD_BOT_TOKEN}"
    },

    // Slack（通过环境变量 SLACK_BOT_TOKEN + SLACK_APP_TOKEN）
    "slack": {},

    // WhatsApp（运行 openclaw channels login whatsapp 扫码）
    "whatsapp": {},

    // iMessage via BlueBubbles（macOS）
    "bluebubbles": {
      "serverUrl": "http://your-mac:1234",
      "password": "{env:BLUEBUBBLES_PASSWORD}",
      "webhookPath": "/bb-webhook"
    }
  }
}
```

### 4.3 群组配置

```jsonc
{
  "channels": {
    "telegram": {
      "botToken": "{env:TELEGRAM_BOT_TOKEN}",
      "groupPolicy": "allowlist",
      "groups": {
        "-1001234567890": {
          "requireMention": true  // 群内需要 @mention 才触发
        }
      }
    }
  }
}
```

### 4.4 渠道健康监控

OpenClaw 内置自动重启机制，失效渠道会自动尝试重连：

```jsonc
{
  "channels": {
    "whatsapp": {
      "healthMonitor": { "enabled": true }  // 默认开启
    }
  },
  "gateway": {
    "channelHealthCheckMinutes": 5,    // 健康检查间隔（0 = 禁用）
    "channelMaxRestartsPerHour": 10    // 每小时最大重启次数
  }
}
```

---

## 5. AI 模型配置

### 5.1 支持的提供商（33+）

| 提供商 | 认证方式 | 代表模型 |
|--------|----------|----------|
| **Anthropic** | API Key | Claude Sonnet 4.6 / Opus 4.6 |
| **OpenAI** | API Key 或 OAuth | GPT-5.4 / GPT-4o |
| **Google** | API Key | Gemini 2.5 Pro / Flash |
| **Ollama** | 本地服务（无需 Key）| 任意本地模型 |
| **AWS Bedrock** | AWS 凭证 | Claude / Llama via Bedrock |
| **Azure OpenAI** | API Key + Endpoint | GPT via Azure |
| **Groq** | API Key | Llama 3.x（超快推理）|
| **Mistral** | API Key | Mistral Large |
| **DeepSeek** | API Key | DeepSeek-V3 |
| **xAI（Grok）** | API Key | Grok 系列 |
| **OpenRouter** | API Key | 统一入口访问多模型 |

### 5.2 模型配置

```jsonc
{
  "model": "anthropic/claude-sonnet-4-6",   // 主模型
  "fallbackModel": "openai/gpt-4o",          // 故障转移模型

  // 中转 / 代理
  "provider": {
    "anthropic": {
      "apiKey": "{env:ANTHROPIC_API_KEY}",
      "baseURL": "https://your-proxy.example.com/v1"  // 可选
    },
    "openai": {
      "apiKey": "{env:OPENAI_API_KEY}"
    },
    "ollama": {
      "baseURL": "http://localhost:11434"
    }
  }
}
```

### 5.3 推理深度控制（Thinking Level）

针对支持 extended thinking 的模型（Claude 3.7+、GPT-5.2+）：

| 级别 | 说明 | 适用场景 |
|------|------|----------|
| `off` | 不使用推理 | 简单问答，最快 |
| `minimal` | 极少推理 | 日常任务 |
| `low` | 轻量推理 | 一般任务 |
| `medium` | 中等推理 | 推荐日常默认 |
| `high` | 深度推理 | 复杂分析 |
| `xhigh` | 最深推理 | 最复杂任务，最慢最贵 |

```bash
# 在聊天中动态切换
/think medium
/think high
```

### 5.4 模型故障转移

```jsonc
{
  "model": "anthropic/claude-sonnet-4-6",
  "fallbackModel": "openai/gpt-4o",
  "modelFailoverEnabled": true
}
```

---

## 6. 配置系统

### 6.1 配置文件位置

| 位置 | 说明 |
|------|------|
| `~/.openclaw/config.json` | 全局用户配置（默认）|
| `OPENCLAW_CONFIG` 环境变量 | 指定自定义配置路径 |
| Docker 挂载卷 | 容器化部署时的配置 |

### 6.2 完整配置示例

```jsonc
{
  // 主模型
  "model": "anthropic/claude-sonnet-4-6",
  "fallbackModel": "openai/gpt-4o",

  // 私信策略：pairing（需配对）或 open（任何人可发消息）
  "dmPolicy": "pairing",

  // 允许发消息的用户白名单
  "allowFrom": {
    "telegram": ["@your_username"],
    "discord": ["your_discord_id"]
  },

  // Gateway 配置
  "gateway": {
    "bind": "loopback",
    "port": 3000,
    "tailscale": { "mode": "off" },
    "auth": { "mode": "password", "allowTailscale": true },
    "channelHealthCheckMinutes": 5,
    "channelMaxRestartsPerHour": 10
  },

  // 渠道（见第 4 节）
  "channels": {},

  // AI 提供商（见第 5 节）
  "provider": {}
}
```

### 6.3 变量替换语法

| 语法 | 说明 |
|------|------|
| `{env:VAR_NAME}` | 读取环境变量 |
| `{file:path/to/file}` | 读取文件内容 |

### 6.4 会话级动态配置

| 配置项 | 聊天命令 | 说明 |
|--------|----------|------|
| 推理深度 | `/think <level>` | 本次会话的 thinking level |
| 详细程度 | `/verbose <level>` | 输出详细程度 |
| 模型 | `/model <id>` | 临时切换模型 |
| 群组激活 | `/activation mention\|always` | 群内触发模式 |

---

## 7. Gateway 架构

Gateway 是 OpenClaw 的核心控制组件，负责管理渠道连接、消息路由、AI 调用和 Skills 执行，以后台服务形式常驻运行。

### 7.1 绑定模式

| 模式 | 说明 | 适用场景 |
|------|------|----------|
| `loopback` | 只监听 127.0.0.1 | 默认，最安全，本机使用 |
| `lan` | 监听局域网 IP | 局域网内多设备访问 |
| `tailnet` | 通过 Tailscale 网络 | 远程安全访问（推荐）|
| `auto` | 自动检测 | — |
| `custom` | 自定义绑定地址 | 高级用法 |

### 7.2 Tailscale 集成

```jsonc
{
  "gateway": {
    "tailscale": {
      "mode": "serve"  // off | serve | funnel
    },
    "auth": {
      "mode": "password",      // funnel 模式必须启用
      "allowTailscale": true   // Tailscale 网络内免密
    }
  }
}
```

**Tailscale 模式说明**：
- `off`：不使用 Tailscale
- `serve`：内网穿透，只有你的 Tailscale 设备能访问
- `funnel`：暴露到公网，必须启用密码认证

---

## 8. Skills 系统

### 8.1 三个层级

| 层级 | 说明 | 来源 |
|------|------|------|
| **Bundled** | 内置技能，随 OpenClaw 安装 | 官方维护 |
| **Managed** | 从 ClawHub 安装的技能 | 社区贡献 |
| **Workspace** | 本地自定义技能 | 你自己写 |

### 8.2 ClawHub

ClawHub 是 OpenClaw 的技能注册中心，AI 可以自动搜索和安装所需技能：

```bash
openclaw skills install <skill-name>  # 手动安装
openclaw skills list                  # 查看已安装
```

### 8.3 创建自定义 Skill

```
~/.openclaw/skills/
└── daily-summary/
    └── SKILL.md
```

```markdown
---
name: daily-summary
description: >
  生成每日工作总结。触发词：日报、总结、daily summary。
---

# 每日总结流程

1. 询问今天完成的主要工作
2. 询问遇到的问题
3. 询问明天的计划
4. 整理成结构化日报格式输出
```

---

## 9. 自动化功能

### 9.1 Webhook 触发

```jsonc
{
  "automation": {
    "webhook": {
      "enabled": true,
      "path": "/webhook",
      "secret": "{env:WEBHOOK_SECRET}"
    }
  }
}
```

```bash
# 外部系统触发 OpenClaw
curl -X POST https://your-gateway/webhook \
  -H "X-Secret: your-secret" \
  -d '{"task": "发送告警到 Telegram：服务器 CPU 超过 90%"}'
```

### 9.2 Cron 定时任务

```jsonc
{
  "automation": {
    "cron": [
      {
        "schedule": "0 9 * * 1-5",
        "task": "发送今日工作提醒到 Telegram",
        "channel": "telegram"
      },
      {
        "schedule": "0 18 * * *",
        "task": "生成今日工作总结",
        "channel": "telegram"
      }
    ]
  }
}
```

### 9.3 Gmail Pub/Sub 集成

```jsonc
{
  "automation": {
    "gmail": {
      "enabled": true,
      "pubsubTopic": "projects/your-project/topics/gmail",
      "actions": [
        {
          "filter": "from:important@company.com",
          "task": "总结这封邮件并发送到 Telegram"
        }
      ]
    }
  }
}
```

---

## 10. 安全模型

### 10.1 dmPolicy — 私信策略

| 策略 | 说明 | 适用场景 |
|------|------|----------|
| `pairing`（默认）| 需要通过配对码验证才能发消息 | 个人使用，防陌生人 |
| `open` | 任何人都可以发消息 | 公开 Bot 场景 |

### 10.2 allowFrom — 用户白名单

```jsonc
{
  "allowFrom": {
    "telegram": ["@your_username", "@family_member"],
    "discord": ["123456789"],
    "whatsapp": ["+1234567890"]
  }
}
```

### 10.3 安全最佳实践

- 保持 `dmPolicy: "pairing"`，防止陌生人滥用
- Gateway 优先使用 `loopback` 或 `tailnet` 绑定
- 公网暴露（funnel）必须启用密码认证
- API Key 使用 `{env:VAR}` 环境变量，不硬编码
- 定期运行 `openclaw doctor` 检查配置

---

## 11. 会话管理

```bash
openclaw sessions list                    # 查看所有会话
openclaw sessions resume <session-id>     # 恢复指定会话
```

**聊天内会话命令**：

| 命令 | 说明 |
|------|------|
| `/new` | 开始新会话，清空上下文 |
| `/reset` | 重置当前会话 |
| `/compact` | 压缩上下文（节省 Token）|
| `/status` | 查看当前会话状态 |
| `/usage` | 查看 Token 使用量 |

---

## 12. 移动端与设备操作

### 12.1 iOS / Android Companion

OpenClaw 支持移动端伴侣 App，通过 Tailscale 连接本地 Gateway：

- iPhone / iPad：App Store 安装 OpenClaw companion
- Android：Google Play 安装
- 通过 Tailscale 与 Gateway 建立加密连接
- 支持语音输入（wake word 唤醒）

### 12.2 Android 设备命令

通过 OpenClaw 可远程控制 Android 设备：

| 命令类型 | 说明 |
|---------|------|
| 通知 | 查看 / 发送通知 |
| 位置 | 获取设备位置 |
| SMS | 发送短信 |
| 照片 | 访问相机 |
| 联系人 | 查询联系人 |
| 日历 | 查看 / 创建日历事件 |
| 应用更新 | 检查应用更新状态 |

### 12.3 语音支持

- 内置 wake word 检测
- TTS（文字转语音）输出
- 手语识别（Vision Extension）

---

## 13. 聊天命令

在任意已配置的消息渠道中，可以使用以下命令控制 OpenClaw：

| 命令 | 说明 |
|------|------|
| `/status` | 查看 Gateway 和渠道状态 |
| `/new` | 开始新会话 |
| `/reset` | 重置当前会话 |
| `/compact` | 压缩上下文 |
| `/think <level>` | 设置推理深度（off/minimal/low/medium/high/xhigh）|
| `/verbose <level>` | 设置输出详细程度 |
| `/model <id>` | 临时切换模型 |
| `/usage` | 查看 Token 使用量 |
| `/restart` | 重启 Gateway |
| `/activation mention\|always` | 切换群内激活模式 |

---

## 14. 与 Coding Agents 的区别

OpenClaw 和 Claude Code / Codex / Gemini CLI / OpenCode 是两类完全不同的工具：

| 维度 | OpenClaw | Coding Agents |
|------|----------|---------------|
| **主要场景** | 个人助手、日常任务、自动化 | 代码编写、调试、重构 |
| **交互方式** | WhatsApp / Telegram / Slack 等消息平台 | 终端 CLI |
| **使用时机** | 随时随地（手机、任何设备）| 坐在电脑前开发时 |
| **部署方式** | 自托管 Gateway，常驻后台 | 按需启动的命令行工具 |
| **典型用法** | "WhatsApp 发条消息提醒我下午 3 点开会" | `claude "帮我重构这个函数"` |
| **代码能力** | 有限（非主要功能）| 核心功能 |
| **开源** | MIT | 部分开源 |

**两者可以互补使用**：
- 用 OpenClaw 处理日常任务、提醒、信息查询
- 用 Claude Code / OpenCode 处理具体的编程任务

---

## 15. 快速速查

### 常用 CLI 命令

| 命令 | 说明 |
|------|------|
| `openclaw onboard` | 首次初始化引导 |
| `openclaw status` | 查看 Gateway 状态 |
| `openclaw doctor` | 健康检查 |
| `openclaw logs` | 查看日志 |
| `openclaw restart` | 重启 Gateway |
| `openclaw update` | 更新版本 |
| `openclaw channels list` | 查看渠道状态 |
| `openclaw channels login <channel>` | 登录渠道 |
| `openclaw models list` | 查看可用模型 |
| `openclaw models set <model>` | 切换模型 |
| `openclaw skills list` | 查看已安装技能 |
| `openclaw skills install <name>` | 安装技能 |

### 配置路径速查

| 配置项 | 路径 |
|--------|------|
| 全局配置 | `~/.openclaw/config.json` |
| Skills 目录 | `~/.openclaw/skills/` |
| 日志目录 | `~/.openclaw/logs/` |
| 凭证目录 | `~/.openclaw/credentials/` |

### 环境变量速查

| 变量 | 说明 |
|------|------|
| `ANTHROPIC_API_KEY` | Anthropic API Key |
| `OPENAI_API_KEY` | OpenAI API Key |
| `GOOGLE_GENERATIVEAI_API_KEY` | Google API Key |
| `TELEGRAM_BOT_TOKEN` | Telegram Bot Token |
| `DISCORD_BOT_TOKEN` | Discord Bot Token |
| `SLACK_BOT_TOKEN` | Slack Bot Token |
| `SLACK_APP_TOKEN` | Slack App Token |
| `OPENCLAW_CONFIG` | 自定义配置文件路径 |
| `OPENCLAW_NIX_MODE` | 启用 Nix 模式（禁用自动更新）|
| `OPENCLAW_SANDBOX` | 启用 Docker 沙盒 |

---

*2026-03-25 · 基于官方文档（docs.openclaw.ai）、GitHub 仓库（openclaw/openclaw）及社区实践编写*

*文档体系：[总导览](../README.md) · [General Agents 导引](./README.md)*
