# OpenCode 完整指南（2026）

> 开源 · 多模型 · 终端优先 · LSP 原生支持
>
> 从安装配置到高级工作流的完整实践指南

---

## 目录

1. [什么是 OpenCode](#1-什么是-opencode)
2. [安装](#2-安装)
3. [快速开始](#3-快速开始)
4. [AI 提供商配置](#4-ai-提供商配置)
5. [配置系统](#5-配置系统)
6. [项目记忆文件（AGENTS.md）](#6-项目记忆文件agentsmd)
7. [内置 Agent 与工作模式](#7-内置-agent-与工作模式)
8. [Skills — 可复用工作流](#8-skills--可复用工作流)
9. [MCP — 外部工具接入](#9-mcp--外部工具接入)
10. [Hooks — 自动化触发器](#10-hooks--自动化触发器)
11. [权限与沙盒](#11-权限与沙盒)
12. [LSP 原生支持](#12-lsp-原生支持)
13. [多智能体](#13-多智能体)
14. [会话管理](#14-会话管理)
15. [TUI 界面与快捷键](#15-tui-界面与快捷键)
16. [非交互式 / CI 模式](#16-非交互式--ci-模式)
17. [Client/Server 架构](#17-clientserver-架构)
18. [IDE 集成](#18-ide-集成)
19. [插件系统](#19-插件系统)
20. [与其他工具对比](#20-与其他工具对比)

---

## 1. 什么是 OpenCode

OpenCode 是由 **SST 团队**（Serverless Stack，知名 AWS 无服务器框架团队）开发的开源 AI 编程助手，定位为「终端优先、提供商无关」的 AI Coding Agent。

与 Claude Code（绑定 Anthropic）或 Gemini CLI（绑定 Google）不同，OpenCode 可以自由切换任意 AI 提供商，包括 Anthropic、OpenAI、Google、本地 Ollama 模型等。

| 属性 | 详情 |
|------|------|
| **GitHub** | `github.com/sst/opencode` |
| **开源协议** | MIT |
| **GitHub Stars** | ~130K |
| **实现语言** | TypeScript（55.5%）+ Rust（性能组件） |
| **当前版本** | v1.3.2+（发布 740+ 次，迭代极快） |
| **运行时要求** | Node.js 24（推荐）或 Node 22.16+ |

**核心优势**：

- **100% 开源（MIT）**：代码完全可审计、可 fork、可自托管
- **提供商无关**：支持 Anthropic / OpenAI / Google / Bedrock / Ollama 等 20+ 提供商
- **原生 LSP 支持**：内置语言服务器协议，AI 能感知类型错误、定义跳转、引用关系
- **Client/Server 架构**：服务端可远程运行，TUI/Desktop App/移动端均可连接
- **OpenCode Zen**：团队维护的 AI 网关，按量付费，仅透传手续费，无额外加价

---

## 2. 安装

### 推荐方式（curl 脚本）

```bash
curl -fsSL https://opencode.ai/install | bash

# 指定安装目录
OPENCODE_INSTALL_DIR=/usr/local/bin curl -fsSL https://opencode.ai/install | bash
```

安装目录优先级：`$OPENCODE_INSTALL_DIR` → `$XDG_BIN_DIR` → `$HOME/bin` → `$HOME/.opencode/bin`

### 包管理器

```bash
# Node.js（npm / bun / pnpm / yarn）
npm i -g opencode-ai@latest
bun i -g opencode-ai@latest
pnpm i -g opencode-ai@latest

# macOS
brew install anomalyco/tap/opencode   # Tap（始终最新）
brew install opencode                  # 官方 formula（更新稍慢）

# Windows
scoop install opencode
choco install opencode

# Arch Linux
sudo pacman -S opencode    # 稳定版
paru -S opencode-bin       # AUR 最新版

# Nix
nix run nixpkgs#opencode
mise use -g opencode
```

### Desktop App（Beta）

提供 macOS / Windows / Linux 桌面应用：

```bash
brew install --cask opencode-desktop                             # macOS
scoop bucket add extras && scoop install extras/opencode-desktop # Windows
```

或直接从 [opencode.ai/download](https://opencode.ai/download) 下载对应平台安装包。

---

## 3. 快速开始

```bash
# 启动交互式 TUI
opencode

# 在指定目录启动
opencode --cwd /path/to/project

# 单次执行（非交互）
opencode run "帮我实现用户登录功能"

# 查看版本
opencode --version

# 运行健康检查
opencode doctor

# 引导式初始化（首次使用推荐）
opencode onboard
```

### 配置 API Key

最简单的方式是设置环境变量：

```bash
# Anthropic（Claude 模型）
export ANTHROPIC_API_KEY=sk-ant-...

# OpenAI
export OPENAI_API_KEY=sk-...

# Google
export GOOGLE_GENERATIVEAI_API_KEY=...

# Ollama（本地，无需 Key）
# 启动 Ollama 服务后直接可用
```

或通过 TUI 内的 `/connect` 命令交互式配置。

---

## 4. AI 提供商配置

### 4.1 支持的提供商

OpenCode 支持 20+ AI 提供商：

| 提供商 | Provider ID | 主要模型 |
|--------|------------|----------|
| Anthropic | `anthropic` | claude-opus-4-6, claude-sonnet-4-6 |
| OpenAI | `openai` | gpt-5.4, gpt-4o |
| Google | `google` | gemini-2.5-pro, gemini-2.5-flash |
| AWS Bedrock | `amazon-bedrock` | Claude/Llama via Bedrock |
| Azure OpenAI | `azure` | GPT 系列 via Azure |
| Groq | `groq` | Llama 3.x（超快推理）|
| Mistral | `mistral` | Mistral Large |
| Ollama | `ollama` | 任意本地模型 |
| OpenRouter | `openrouter` | 统一入口访问多模型 |
| LM Studio | `lmstudio` | 本地模型 GUI |
| xAI | `xai` | Grok 系列 |
| DeepSeek | `deepseek` | DeepSeek-V3 |
| **OpenCode Zen** | `opencode` | 团队精选最优模型 |

### 4.2 OpenCode Zen（推荐）

Zen 是 OpenCode 团队维护的 AI 网关，特点：

- 对各提供商模型持续做基准测试，只推荐验证过的最优组合
- Pay-as-you-go，仅透传信用卡手续费（4.4% + $0.30/笔），**不额外加价**
- 团队功能：成员管理、消费限额、模型访问控制
- 零数据保留（免费模型除外）

使用方式：
```bash
# 登录 Zen
opencode auth login

# 模型 ID 前缀为 opencode/
# 例：opencode/claude-sonnet-4-6
```

### 4.3 提供商配置（opencode.json）

```jsonc
{
  "model": "anthropic/claude-sonnet-4-6",
  "provider": {
    "anthropic": {
      "options": {
        "apiKey": "{env:ANTHROPIC_API_KEY}",
        "timeout": 600000,
        "chunkTimeout": 30000
      }
    },
    "openai": {
      "options": {
        "apiKey": "{env:OPENAI_API_KEY}"
      }
    },
    "ollama": {
      "options": {
        "baseUrl": "http://localhost:11434"
      }
    },
    "azure": {
      "options": {
        "apiKey": "{env:AZURE_API_KEY}",
        "endpoint": "https://my-instance.openai.azure.com/",
        "apiVersion": "2024-02-01"
      }
    }
  }
}
```

### 4.4 中转 / 代理配置

```jsonc
{
  "provider": {
    "anthropic": {
      "options": {
        "apiKey": "{env:ANTHROPIC_API_KEY}",
        "baseURL": "https://your-proxy.example.com/v1"
      }
    }
  }
}
```

或通过环境变量：

```bash
export ANTHROPIC_BASE_URL=https://your-proxy.example.com/v1
export OPENAI_BASE_URL=https://your-proxy.example.com/v1
```

### 4.5 模型切换

- **TUI 内**：`/model` 命令或 `M` 快捷键
- **配置文件**：修改 `model` 字段
- **命令行**：`opencode --model anthropic/claude-opus-4-6`

```jsonc
{
  "model": "anthropic/claude-sonnet-4-6",       // 默认模型
  "small_model": "anthropic/claude-haiku-4-5"   // 轻量模型（标题生成等低优先级任务）
}
```

---

## 5. 配置系统

### 5.1 配置文件位置与优先级

OpenCode 支持多层级配置，优先级从高到低：

| 优先级 | 位置 | 说明 |
|--------|------|------|
| 1（最高）| 命令行参数 | `--model`、`--cwd` 等 |
| 2 | `OPENCODE_CONFIG_CONTENT` 环境变量 | JSON 字符串内联配置 |
| 3 | 项目根 `opencode.json` / `opencode.jsonc` | 项目级配置 |
| 4 | 项目 `.opencode/config.json` | 项目级（`.opencode` 目录）|
| 5 | `~/.config/opencode/config.json` | 全局用户配置 |
| 6（最低）| 默认值 | 内置默认 |

TUI 专用配置（不影响 headless 模式）：`~/.config/opencode/tui.json` 或与项目配置同目录的 `tui.json`

### 5.2 完整配置示例

```jsonc
{
  // 配置 Schema 提示（VSCode 等编辑器自动补全）
  "$schema": "https://opencode.ai/config.json",

  // 模型
  "model": "anthropic/claude-sonnet-4-6",
  "small_model": "anthropic/claude-haiku-4-5",

  // 默认 Agent（build / plan 或自定义 Agent 名）
  "default_agent": "build",

  // 启动时自动更新：true | false | "notify"
  "autoupdate": "notify",

  // 会话分享："manual" | "auto" | "disabled"
  "share": "manual",

  // 跟踪文件变更以支持 undo（默认 true）
  "snapshot": true,

  // 额外指令文件（支持 glob 和远程 URL）
  "instructions": [
    "./docs/ai-guidelines.md",
    "https://example.com/shared-guidelines.md"
  ],

  // 禁用/启用特定提供商
  "disabled_providers": ["groq"],

  // 提供商配置
  "provider": {
    "anthropic": {
      "options": {
        "apiKey": "{env:ANTHROPIC_API_KEY}"
      }
    }
  },

  // MCP 服务器（见第 9 节）
  "mcp": {},

  // Hooks（见第 10 节）
  "hooks": {},

  // 权限（见第 11 节）
  "permission": {},

  // LSP 配置（见第 12 节）
  "lsp": {},

  // Server 配置（见第 17 节）
  "server": {
    "port": 4096,
    "hostname": "127.0.0.1"
  }
}
```

### 5.3 变量替换语法

| 语法 | 说明 |
|------|------|
| `{env:VAR_NAME}` | 读取环境变量，未设置时为空字符串 |
| `{file:path/to/file}` | 读取文件内容（相对于配置目录或绝对路径）|

---

## 6. 项目记忆文件（AGENTS.md）

OpenCode 遵循 **Open Agent Skills Standard**，使用 `AGENTS.md` 作为项目级记忆文件（与 Codex CLI 相同），每次会话启动时自动加载。

**加载顺序**（逐层叠加，子目录覆盖父目录）：

```
~/.config/opencode/AGENTS.md   ← 全局记忆
<Git 根>/AGENTS.md              ← 项目记忆
<当前目录>/AGENTS.md            ← 目录级记忆
```

也可通过 `instructions` 字段引入额外指令文件：

```jsonc
{
  "instructions": [
    "./AGENTS.md",
    "./docs/coding-standards.md"
  ]
}
```

**推荐模板**：

```markdown
# 项目名称

## 这是什么
一句话描述项目用途。

## 技术栈
- Go 1.23 + Gin + GORM
- PostgreSQL 16
- React 19 + Vite + TailwindCSS

## 常用命令
- 启动：`make dev`
- 测试：`make test`
- 构建：`make build`

## 代码约定
- 错误处理：`fmt.Errorf("context: %w", err)`，不吞错误
- 提交格式：`feat:` / `fix:` / `docs:` 前缀

## 禁止操作
- 不修改 .env 文件
- 不引入未讨论的新依赖
```

---

## 7. 内置 Agent 与工作模式

OpenCode 内置三个 Agent，通过 `Tab` 键在 TUI 中切换：

| Agent | 权限 | 适用场景 |
|-------|------|----------|
| **build**（默认）| 完整文件系统和工具访问 | 日常开发、代码编写、文件修改 |
| **plan** | 只读；拒绝文件编辑，执行 bash 前询问 | 代码探索、架构规划、不想让 AI 改文件时 |
| **general** | 内部子 Agent，擅长复杂搜索和多步任务 | 通过 `@general` 在消息中调用 |

**设置默认 Agent**：

```jsonc
{
  "default_agent": "plan"  // 默认以只读模式启动
}
```

**在消息中调用特定 Agent**：

```
@general 帮我搜索整个代码库中所有使用了 deprecated API 的地方
```

---

## 8. Skills — 可复用工作流

OpenCode 遵循 **Open Agent Skills Standard**，Skills 以 `SKILL.md` 文件定义，放在 `.opencode/skills/` 目录下。

### 8.1 目录结构

```
项目根/
└── .opencode/
    └── skills/
        ├── deploy/
        │   └── SKILL.md
        ├── code-review/
        │   └── SKILL.md
        └── release/
            ├── SKILL.md
            └── scripts/
                └── bump-version.sh
```

全局 Skills（三工具通用）：
```
~/.agents/skills/<skill-name>/SKILL.md
```

### 8.2 SKILL.md 格式

```markdown
---
name: deploy
description: >
  部署代码到生产环境。触发词：部署、上线、发版、release、deploy。
  不适用：测试环境部署（使用 deploy-staging）。
---

# 生产部署流程

1. `git status` — 确认工作树干净
2. `make test` — 全量测试必须通过
3. `git tag v$(date +%Y%m%d)` — 打版本标签
4. `make deploy:prod` — 执行部署
5. 报告部署结果和版本号
```

### 8.3 三级渐进加载

OpenCode 与其他支持该标准的工具一样，按需加载 Skills：

| 阶段 | 内容 | Token 消耗 |
|------|------|------------|
| Level 1 | 仅读 `name` 和 `description` | ~100 tokens |
| Level 2 | 加载完整 SKILL.md | <5,000 tokens |
| Level 3 | 按需加载 scripts / references | 按需 |

---

## 9. MCP — 外部工具接入

OpenCode 完整支持 MCP（Model Context Protocol），在 `opencode.json` 的 `mcp` 字段配置。

### 9.1 本地 MCP 服务器（stdio）

```jsonc
{
  "mcp": {
    "github": {
      "type": "local",
      "command": ["npx", "-y", "@anthropic-ai/mcp-server-github"],
      "environment": {
        "GITHUB_TOKEN": "{env:GITHUB_TOKEN}"
      },
      "enabled": true
    },
    "postgres": {
      "type": "local",
      "command": ["npx", "-y", "@anthropic-ai/mcp-server-postgres", "{env:DATABASE_URL}"],
      "enabled": true
    },
    "filesystem": {
      "type": "local",
      "command": ["npx", "-y", "@modelcontextprotocol/server-filesystem", "/tmp"],
      "enabled": true
    }
  }
}
```

### 9.2 远程 MCP 服务器（SSE/HTTP）

```jsonc
{
  "mcp": {
    "remote-tools": {
      "type": "remote",
      "url": "https://mcp.example.com/sse",
      "enabled": true
    }
  }
}
```

### 9.3 常用 MCP 服务器

| 包名 | 功能 |
|------|------|
| `@upstash/context7-mcp` | 实时查询框架最新文档 |
| `@anthropic-ai/mcp-server-github` | GitHub 操作 |
| `@anthropic-ai/mcp-server-postgres` | PostgreSQL 查询 |
| `@anthropic-ai/mcp-server-fetch` | HTTP 请求 |
| `@modelcontextprotocol/server-filesystem` | 文件系统操作 |

---

## 10. Hooks — 自动化触发器

Hooks 在特定事件发生时自动执行命令，配置在 `opencode.json` 的 `hooks` 字段下。

### 10.1 支持的事件

| 事件 | 触发时机 |
|------|----------|
| `file:write` | AI 写入文件后 |
| `file:read` | AI 读取文件时 |
| `session:start` | 会话开始时 |
| `session:end` | 会话结束时 |
| `agent:start` | Agent 开始处理请求时 |
| `agent:end` | Agent 完成响应时 |

### 10.2 配置格式

```jsonc
{
  "hooks": {
    // 写入 Go 文件后自动格式化
    "file:write": [
      {
        "command": ["bash", "-c", "[[ \"$FILE\" == *.go ]] && gofmt -w \"$FILE\" || true"]
      }
    ],
    // 写入 TS/JS 文件后自动用 Prettier 格式化
    "file:write": [
      {
        "command": ["bash", "-c", "[[ \"$FILE\" =~ \\.(ts|js|tsx|jsx)$ ]] && npx prettier --write \"$FILE\" || true"]
      }
    ],
    // 会话开始时加载环境
    "session:start": [
      {
        "command": ["bash", "-c", "echo 'Session started at $(date)' >> ~/.opencode/session.log"]
      }
    ],
    // Agent 完成后记录审计日志
    "agent:end": [
      {
        "command": ["bash", "-c", "echo \"[$(date -u +%FT%TZ)] agent completed\" >> ~/opencode-audit.log"]
      }
    ]
  }
}
```

### 10.3 Hook 中可用的环境变量

| 变量 | 说明 |
|------|------|
| `$FILE` | 触发 hook 的文件路径（`file:*` 事件）|
| `$SESSION_ID` | 当前会话 ID |
| `$AGENT` | 当前 Agent 名称 |

---

## 11. 权限与沙盒

### 11.1 权限配置

OpenCode 通过 `permission` 字段精细控制 AI 的操作权限：

```jsonc
{
  "permission": {
    // 允许的操作模式（allow / deny / ask）
    "allow": [
      "read",           // 读取文件
      "write",          // 写入文件
      "execute"         // 执行命令
    ],
    "deny": [
      "network"         // 禁止网络访问
    ]
  }
}
```

### 11.2 审批模式

| 模式 | 说明 |
|------|------|
| `ask`（默认）| 执行每个操作前询问用户 |
| `allow` | 自动允许，不询问 |
| `deny` | 拒绝该类操作 |

**通过 CLI 参数控制**：

```bash
# 全自动（谨慎使用）
opencode run "修复所有 lint 错误" --dangerously-skip-permissions

# 只读模式（使用 plan agent）
opencode --agent plan
```

### 11.3 沙盒

OpenCode 支持容器化沙盒运行，通过 Docker / Podman 隔离：

```bash
# Docker 模式（官方提供 Dockerfile）
docker-compose up opencode
```

---

## 12. LSP 原生支持

**LSP（Language Server Protocol）原生支持**是 OpenCode 相比其他 AI CLI 工具最具差异化的功能之一。

其他工具的 AI 只能看到文本内容；OpenCode 的 AI 能感知到：

- **类型错误**：知道哪行代码有类型不匹配
- **定义跳转**：理解函数/变量定义在哪个文件
- **引用关系**：知道某个函数被哪些地方调用
- **符号信息**：理解变量类型、函数签名
- **诊断信息**：实时感知编译错误和 lint 警告

### 12.1 配置 LSP

```jsonc
{
  "lsp": {
    // Go
    "go": {
      "command": "gopls"
    },
    // TypeScript
    "typescript": {
      "command": "typescript-language-server",
      "args": ["--stdio"]
    },
    // Python
    "python": {
      "command": "pylsp"
    },
    // Rust
    "rust": {
      "command": "rust-analyzer"
    }
  }
}
```

### 12.2 实际效果

配置 LSP 后，AI 修复 Bug 时会：
1. 主动读取编译错误信息
2. 追踪函数调用链找到根因
3. 修改后验证类型是否正确
4. 不会写出"看起来对但实际上类型错误"的代码

这使得 OpenCode 在强类型语言（Go、TypeScript、Rust）项目中的代码正确率显著高于没有 LSP 的工具。

---

## 13. 多智能体

### 13.1 自定义 Agent

在 `.opencode/` 目录下定义自定义 Agent：

```jsonc
// opencode.json
{
  "agent": {
    "reviewer": {
      "model": "anthropic/claude-opus-4-6",
      "description": "专职代码审查 Agent",
      "instructions": "./agents/reviewer.md",
      "permission": {
        "allow": ["read"],
        "deny": ["write", "execute"]
      }
    },
    "tester": {
      "model": "anthropic/claude-sonnet-4-6",
      "description": "专职测试编写 Agent",
      "instructions": "./agents/tester.md"
    }
  }
}
```

`.opencode/agents/reviewer.md`：

```markdown
# 代码审查专家

你是专职代码审查的 Agent，只读不写。

## 审查维度
1. 安全漏洞（SQL 注入、XSS、认证缺陷）
2. 性能问题（N+1 查询、内存泄漏）
3. 可读性和可维护性
4. 测试覆盖率

## 输出格式
按 Critical / Warning / Suggestion 分级，附文件名和行号。
```

### 13.2 调用子 Agent

在消息中使用 `@` 调用特定 Agent：

```
@reviewer 审查这次的认证模块修改
@general 搜索整个代码库中所有使用了废弃 API 的地方
@tester 为刚才实现的 API 写完整的测试
```

### 13.3 并发执行

OpenCode 支持多 Agent 并发处理独立任务，适合大型任务拆分：

```
同时执行：
@reviewer 检查安全问题
@tester 检查测试覆盖率
```

---

## 14. 会话管理

```bash
# 列出所有历史会话
opencode sessions list

# 恢复最近一次会话
opencode sessions resume

# 恢复指定会话
opencode sessions resume <session-id>

# 删除会话
opencode sessions delete <session-id>
```

**TUI 内会话命令**：

| 命令 | 说明 |
|------|------|
| `/new` | 开启新会话 |
| `/sessions` | 查看会话列表 |
| `/compact` | 压缩上下文（节省 Token）|
| `/undo` | 撤销最近一次文件修改（需启用 `snapshot: true`）|
| `/share` | 分享当前会话（生成可访问链接）|

---

## 15. TUI 界面与快捷键

OpenCode 由 Neovim 用户和 terminal.shop 创始人构建，TUI 体验针对终端重度用户优化。

### 15.1 布局

```
┌─────────────────────────────────────┐
│  opencode  [build ▼]  [model ▼]     │  ← 顶栏：Agent 和模型切换
├─────────────────────────────────────┤
│                                     │
│  AI 响应区域                         │
│                                     │
├─────────────────────────────────────┤
│  > 输入区域                          │  ← 底部：消息输入
└─────────────────────────────────────┘
```

### 15.2 常用快捷键

| 快捷键 | 功能 |
|--------|------|
| `Tab` | 切换 Agent（build ↔ plan ↔ 自定义）|
| `M` | 切换模型 |
| `Ctrl+C` | 中断当前 AI 响应 |
| `Ctrl+L` | 清空屏幕 |
| `Ctrl+R` | 搜索历史命令 |
| `↑` / `↓` | 浏览历史输入 |
| `Esc` | 取消当前操作 |

### 15.3 TUI 内命令

| 命令 | 说明 |
|------|------|
| `/new` | 开启新会话 |
| `/model` | 切换模型 |
| `/agent` | 切换 Agent |
| `/compact` | 压缩上下文 |
| `/undo` | 撤销文件修改 |
| `/share` | 分享会话 |
| `/connect` | 配置 AI 提供商 |
| `/sessions` | 会话管理 |
| `/help` | 查看帮助 |
| `/exit` | 退出 |

---

## 16. 非交互式 / CI 模式

```bash
# 单次执行，完成后退出
opencode run "审查本次 PR 的安全问题"

# 指定 Agent
opencode run "分析代码库架构" --agent plan

# 指定模型
opencode run "修复所有类型错误" --model anthropic/claude-opus-4-6

# 非交互模式（禁用所有交互提示）
opencode run "生成 API 文档" --non-interactive

# 输出 JSON 格式（便于脚本解析）
opencode run "检查代码质量" --output-format json
```

### GitHub Actions 示例

```yaml
name: AI Code Review
on:
  pull_request:
    types: [opened, synchronize]

jobs:
  review:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install opencode
        run: curl -fsSL https://opencode.ai/install | bash

      - name: Run AI review
        env:
          ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
        run: |
          opencode run "\
            审查本次 PR 的代码变更，检查：\
            1. 安全漏洞（SQL 注入、XSS、认证缺陷）\
            2. 性能问题\
            3. 测试覆盖率\
            输出 Markdown 格式报告" \
            --agent plan \
            --non-interactive
```

---

## 17. Client/Server 架构

OpenCode 采用 Client/Server 分离架构，这是它与其他 AI CLI 工具的重要架构差异。

### 17.1 架构原理

```
[Server（计算端）]  ←→  [Client（展示端）]
   本地 / 远程              TUI / Desktop App / 移动端
```

- **Server** 负责：AI 推理调用、文件操作、命令执行、会话状态
- **Client** 负责：用户界面展示、输入处理

### 17.2 Server 配置

```jsonc
{
  "server": {
    "port": 4096,
    "hostname": "0.0.0.0",   // 允许外部连接（默认 127.0.0.1）
    "mdns": true,             // mDNS 服务发现
    "mdnsDomain": "myproject.local",
    "cors": ["http://localhost:5173"]
  }
}
```

### 17.3 远程 Server 使用场景

```bash
# 在远程服务器上启动 opencode server
ssh user@remote-server
opencode server

# 本地 TUI 连接远程 server
opencode --server http://remote-server:4096
```

**典型场景**：
- 在性能更强的服务器上运行 AI 推理，本地只跑 TUI
- 团队共享一个 opencode server 实例
- 移动端（iOS/Android）连接桌面端 server 远程操控

---

## 18. IDE 集成

### VS Code 扩展

```bash
# 在 VS Code 扩展市场搜索 "opencode"
# 或通过命令行安装
code --install-extension opencode-ai.opencode
```

扩展提供：
- 侧边栏 AI 对话面板
- 文件差异预览（AI 修改前后对比）
- 快捷键触发 opencode

### Zed 编辑器

OpenCode 仓库内置 `.zed/` 配置，Zed 用户可直接使用。

### Neovim

OpenCode 由 Neovim 用户构建，社区有对应插件支持（参考 GitHub Discussions）。

### 通用：将终端内嵌 IDE

大多数情况下，直接在 IDE 的集成终端中运行 `opencode` 即可，无需专门的扩展。

---

## 19. 插件系统

OpenCode 支持通过 npm 包形式的插件扩展功能：

```jsonc
{
  "plugin": [
    "@opencode/plugin-prettier",
    "@opencode/plugin-eslint",
    "my-custom-opencode-plugin"
  ]
}
```

插件可以：
- 注册新的工具供 AI 调用
- 添加新的 Hook 事件处理器
- 扩展 TUI 界面
- 集成第三方服务

`.opencode/` 目录结构（完整）：

```
.opencode/
├── config.json      ← 项目配置
├── agents/          ← 自定义 Agent 指令文件
├── commands/        ← 自定义 TUI 命令
├── plugins/         ← 本地插件
├── skills/          ← Skills 目录
├── tools/           ← 自定义工具
└── themes/          ← TUI 主题
```

---

## 20. 与其他工具对比

### 20.1 核心差异速览

| 维度 | OpenCode | Claude Code | Codex CLI | Gemini CLI |
|------|----------|-------------|-----------|------------|
| **开源** | ✅ MIT | ❌ 闭源 | ✅ CLI Apache-2.0 | ✅ Apache-2.0 |
| **提供商** | 20+ 任意 | 仅 Anthropic | 仅 OpenAI | 仅 Google |
| **LSP 支持** | ✅ 原生内置 | ❌ | ❌ | ❌ |
| **本地模型** | ✅ Ollama/LMStudio | ❌ | ❌ | ❌ |
| **免费额度** | 需自备 Key | 无 | 无 | 1000次/天 |
| **SWE-bench** | 未公开 | **80.8%** 🥇 | ~72% | ~71% |
| **架构** | Client/Server | 单体 | 单体 | 单体 |
| **LSP 感知** |✅ 类型/定义/引用 | ❌ | ❌ | ❌ |
| **Desktop App** | ✅ macOS/Win/Linux | ❌ | ✅ macOS/Win | ❌ |
| **移动端** | ✅（连接 Server） | ❌ | ❌ | ❌ |
| **Hooks 事件数** | 6 种 | **22 种** 🥇 | 2 种（实验）| 11 种 |
| **多智能体** | ✅ 自定义 Agent | ✅ Agent Teams | ✅ 原生并行 | ⚠️ 实验性 |
| **稳定性** | ⭐⭐⭐（迭代极快）| ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ |

### 20.2 OpenCode 的独特优势

**提供商无关**是最核心的差异。当某个提供商涨价、限速、或某个模型在特定任务上表现不佳时，OpenCode 用户可以即时切换，不受任何单一厂商绑定。

**LSP 原生支持**使 AI 真正理解代码语义，而不只是文本。在强类型语言项目（Go / TypeScript / Rust）中，这带来可观的代码质量提升。

**Client/Server 架构**支持远程协作和移动端接入，适合需要在多设备间切换的开发者。

**本地模型支持**（Ollama / LMStudio）满足数据隐私要求严格或离线场景的需求。

### 20.3 OpenCode 的局限

- **代码生成质量**：尚无公开 SWE-bench 成绩，代码质量依赖所选模型，工具本身未做额外优化
- **生态成熟度**：相比 Claude Code 的 9,000+ 扩展，插件生态刚起步
- **稳定性**：v1.x 阶段，发布 740+ 次说明迭代极快，偶有 breaking change
- **Hooks 事件数**：6 种，少于 Claude Code（22 种）和 Gemini CLI（11 种）
- **社区规模**：比 Claude Code 和 Gemini CLI 小，问题排查时社区资源较少

### 20.4 选 OpenCode 的场景

- 不想被单一 AI 提供商锁定，需要灵活切换模型
- 使用本地模型（Ollama）或需要数据完全本地化
- 强类型语言项目（Go / TypeScript / Rust），需要 LSP 感知提升代码质量
- 已有 API Key，不想额外付订阅费（Zen 按量计费不加价）
- 需要自托管或完整代码审计（MIT 开源）
- 需要移动端或多设备接入（Client/Server 架构）

---


*2026-03-25 · 基于官方文档（opencode.ai/docs）、GitHub 仓库（sst/opencode）及社区实践编写*

*文档体系：[ai-cli-guide-2026.md](./ai-cli-guide-2026.md) · [claude-code-best-practice-2026.md](./claude-code-best-practice-2026.md) · [codex-best-practice-2026.md](./codex-best-practice-2026.md) · [gemini-cli-best-practice-2026.md](./gemini-cli-best-practice-2026.md)*
