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
15. [生产部署最佳实践](#15-生产部署最佳实践)
16. [自动化安装方案](#16-自动化安装方案)
17. [目录模型与权限档位](#17-目录模型与权限档位)

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
openclaw onboard --install-daemon
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

渠道是 OpenClaw 与用户交互的入口，配置通常位于 `~/.openclaw/openclaw.json` 的 `channels` 字段。

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
| `~/.openclaw/openclaw.json` | 全局用户配置（默认）|
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

### 6.4 执行审批配置

| 位置 | 说明 |
|------|------|
| `~/.openclaw/exec-approvals.json` | Gateway / node 命令执行审批策略 |
| `openclaw approvals get --gateway` | 查看当前审批状态 |
| `openclaw approvals set --gateway --file ...` | 替换审批策略 |

### 6.5 会话级动态配置

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

说明：

- 第三方 skill 依赖 ClawHub 在线仓库
- 如果出现 `429 Rate limit exceeded`，通常是 ClawHub 上游限流
- 匿名状态下更容易触发限流，必要时应先执行 `clawhub login`

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


*2026-03-25 · 基于官方文档（docs.openclaw.ai）、GitHub 仓库（openclaw/openclaw）及社区实践编写*

*文档体系：[总导览](../README.md) · [General Agents 导引](./README.md)*

---

## 15. 生产部署最佳实践

基于实际 VPS 部署经验，OpenClaw 在生产环境中最容易出问题的不是模型配置，而是 **Gateway 托管方式、反向代理、证书续期和插件权限**。

### 15.1 推荐拓扑

```text
Internet
   ↓
nginx :443
   ↓
127.0.0.1:18789
   ↓
OpenClaw Gateway (systemd)
   ↓
Channels / Models / Skills
```

### 15.2 关键原则

- **Gateway 用 systemd 托管**
  不要用 `nohup openclaw gateway &`
- **Gateway 仅监听 loopback**
  公网流量统一从 `nginx` 进入
- **有域名时用 `certbot webroot`**
  不要优先用 `standalone`
- **`plugins.allow` 显式声明**
  只允许你实际使用的插件加载
- **公网入口做限流和恶意路径拦截**
  比“完全裸露 UI + 靠 token 硬扛”更稳
- **UFW 默认拒绝入站**
  只放 `22 / 80 / 443`

### 15.3 飞书场景的几个高频坑

- 飞书插件“已加载”不代表消息一定能进来
- 长连接模式正确后，还要确认订阅了 `im.message.receive_v1`
- 如果第一次消息特别慢，往往不是模型慢，而是：
  - 飞书联系人解析权限不足
  - 首次权限错误分支触发
  - 会话初始化 / 预热

### 15.4 性能建议

- 默认保留一个“主模型”和一个“快模型”
- 日常消息优先选响应快的模型
- 把慢和不稳定的问题分开看：
  - **第一次慢**：通常是权限或预热问题
  - **后续持续慢**：通常才是模型本身的问题

完整生产部署说明见：

- [scripts/general-agents/openclaw/README.md](../scripts/general-agents/openclaw/README.md)

## 16. 自动化安装方案

为了避免每次手工配置 `OpenClaw + systemd + nginx + certbot + ufw + 飞书`，建议直接使用配置文件驱动的自动化部署包。

### 16.1 目录

- [README.md](../scripts/general-agents/openclaw/README.md)
- [conf.example](../scripts/general-agents/openclaw/conf.example)
- [manage.sh](../scripts/general-agents/openclaw/manage.sh)

### 16.2 设计目标

- 用一份配置文件描述部署参数
- 支持 **无域名模式**
- 支持 **有域名 + HTTPS 模式**
- 支持 `ACCESS_MODE=standard`、`tailscale-private`、`tailscale-public`
- 可选启用飞书
- 可选启用 `ufw`
- 自动落 `systemd` 服务
- nginx 只管理 OpenClaw 站点文件和专用 `conf.d` 片段，不覆盖整份全局 `nginx.conf`
- 可选预装官方 / 第三方 skills
- 可选启用 `memory-lancedb-pro` 持久化记忆插件
- 支持官方状态目录与项目层初始化：全局层 / 项目层
- 支持执行权限档位：`safe` / `ops` / `admin`

### 16.3 典型用法

```bash
cd scripts
cp ./general-agents/openclaw/conf.example ./general-agents/openclaw/local.conf
vim ./general-agents/openclaw/local.conf
sudo bash manage.sh service install --tool-name openclaw --config ./general-agents/openclaw/local.conf
```

还可以单独使用：

```bash
cd scripts
sudo bash manage.sh config init --tool-name openclaw --config ./general-agents/openclaw/local.conf --scope global
sudo bash manage.sh config init --tool-name openclaw --config ./general-agents/openclaw/local.conf --scope workspace --path /path/to/workspace
sudo bash manage.sh config apply --tool-name openclaw --config ./general-agents/openclaw/local.conf --section access --level safe
sudo bash manage.sh config show --tool-name openclaw --config ./general-agents/openclaw/local.conf --section access
```

### 16.4 无域名模式

适合：

- 只用飞书 / Telegram / WhatsApp
- 暂时不做公网 HTTPS

只需要：

```bash
ACCESS_MODE=standard
PUBLIC_MODE=public-ip
```

### 16.5 有域名模式

适合：

- 需要 Web UI
- 需要 HTTPS

只需要：

```bash
ACCESS_MODE=standard
PUBLIC_MODE=public-domain
DOMAIN=example.com
LETSENCRYPT_EMAIL=ops@example.com
```

### 16.6 当前这套自动化更适合谁

- 自己维护 VPS 的个人用户
- 需要重复部署多台 OpenClaw 节点的人
- 希望把“能跑”升级成“可稳定复现”的团队

### 16.7 Skill 与记忆建议

- 默认生产预装建议控制在 5 到 10 个高频 skill
- 第三方 skill 很优秀，但建议直接显式维护 `SKILL_SPECS`
- 长期记忆默认建议用 `memory-lancedb-pro`
- 启用记忆插件前要补齐 `MEMORY_EMBEDDING_API_KEY`
- 如果还要超长上下文保真，再额外启用 `lossless-claw`

### 16.8 生命周期管理建议

推荐统一使用管理入口：

先记最小命令集：

- `manage.sh service install --tool-name openclaw --config ...`
- `manage.sh service configure --tool-name openclaw --config ...`
- `manage.sh service report --tool-name openclaw --config ...`
- `manage.sh service check --tool-name openclaw --config ...`
- `manage.sh service logs --tool-name openclaw --config ...`
- `manage.sh skill install --tool-name openclaw --config ...`
- `manage.sh plugin install --tool-name openclaw --config ...`
- `manage.sh feishu check --tool-name openclaw --config ...`

高级命令再按需使用：

- `manage.sh service update --tool-name openclaw --config ...`
- `manage.sh service diff --tool-name openclaw --config ...`
- `manage.sh service status --tool-name openclaw --config ...`
- `manage.sh service restart --tool-name openclaw --config ...`
- `manage.sh service reload --tool-name openclaw --config ...`
- `manage.sh service enable --tool-name openclaw --config ...`
- `manage.sh service disable --tool-name openclaw --config ...`
- `manage.sh service cert --tool-name openclaw --config ...`
- `manage.sh service uninstall --tool-name openclaw --config ...`
- `manage.sh config backup --tool-name openclaw --config ...`
- `manage.sh config restore --tool-name openclaw --config ... --path ...`
- `manage.sh config init --tool-name openclaw --config ... --scope global|workspace`
- `manage.sh config apply --tool-name openclaw --config ... --section access --level safe|ops|admin`
- `manage.sh config show --tool-name openclaw --config ... --section access`
- `manage.sh skill remove --tool-name openclaw --config ... --name ...`
- `manage.sh skill check --tool-name openclaw --config ...`
- `manage.sh skill recommend --tool-name openclaw --config ...`
- `manage.sh plugin remove --tool-name openclaw --config ... --name ...`
- `manage.sh feishu guide --tool-name openclaw`

这样比单纯的一次性安装脚本更适合长期维护，尤其是：

- 要反复调整飞书接入
- 要在有域名 / 无域名之间切换
- 要重跑 nginx / certbot / firewall
- 要分批增加 skill / plugin

另外：

- 不再单独保留 `skill sync`，统一用 `skill install`
- 不再单独保留 `plugin sync`，统一用 `plugin install`
- `service report` 看概览，`service status` 看原始 systemd 详情，`service check` 做完整排障

## 17. 目录模型与权限档位

脚本直接管理 OpenClaw 官方状态目录 `~/.openclaw`，工具侧只保留 `scripts/general-agents/openclaw` 目录内的脚本、静态包装脚本和默认备份目录，不再额外保留 `.runtime` 这一层。

官方状态目录：

- `~/.openclaw/openclaw.json`
- `~/.openclaw/exec-approvals.json`
- `~/.openclaw/skills`
- `~/.openclaw/extensions`

工具目录：

- `<repo>/scripts/general-agents/openclaw/bin`
- `<repo>/scripts/general-agents/openclaw/backups`

项目级最小结构：

- `<workspace>/skills`
- `<workspace>/.openclaw/config`
- `<workspace>/.openclaw/data`
- `<workspace>/.openclaw/logs`

执行权限三档：

- `safe`
  - 低风险读操作、日志读取、健康检查
- `ops`
  - 在 `safe` 基础上增加服务状态、网关日志、`nginx -t`
- `admin`
  - 在 `ops` 基础上增加受控的服务重启 / 重载，以及 `openclaw` CLI
