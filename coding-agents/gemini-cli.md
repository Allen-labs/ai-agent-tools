# Google Gemini CLI 最佳实践指南（2026）

> 面向个人开发者 · 从安装到精通 · 所有配置真实可用

---

## 目录

1. [安装与认证](#1-安装与认证)
2. [API 与配置](#2-api-与配置)
3. [目录结构总览](#3-目录结构总览)
4. [GEMINI.md — 项目永久记忆](#4-geminimd--项目永久记忆)
5. [settings.json — 核心配置](#5-settingsjson--核心配置)
6. [沙盒与权限模型](#6-沙盒与权限模型)
7. [Skills — 技能扩展](#7-skills--技能扩展)
8. [Extensions — 插件生态](#8-extensions--插件生态)
9. [Hooks — 自动化钩子](#9-hooks--自动化钩子)
10. [多智能体](#10-多智能体)
11. [MCP — 外部工具接入](#11-mcp--外部工具接入)
12. [IDE 集成](#12-ide-集成)
13. [与 Claude Code / Codex 的对比](#13-与-claude-code--codex-的对比)

---

## 1. 安装与认证

### 1.1 环境要求

| 组件 | 要求 | 说明 |
|------|------|------|
| 操作系统 | macOS 15+ / Windows 11 24H2+ / Ubuntu 20.04+ | 全平台支持 |
| Node.js | ≥ 20.0.0 | 必须 |
| 内存 | 4GB+（轻度）/ 16GB+（深度使用） | |
| 网络 | 需要互联网连接 | |

### 1.2 安装 Gemini CLI

**方式一：npm 全局安装**

```bash
npm install -g @google/gemini-cli
```

**方式二：npx 免安装直接运行**

```bash
npx @google/gemini-cli
```

**方式三：Homebrew（macOS / Linux）**

```bash
brew install gemini-cli
```

**更新**

```bash
npm install -g @google/gemini-cli@latest   # 稳定版（每周二发布）
npm install -g @google/gemini-cli@preview  # 预览版
npm install -g @google/gemini-cli@nightly  # 每日构建
```

> ℹ️ Google Cloud Shell 和 Cloud Workstations 已预装，无需额外安装。

验证：`gemini --version`

### 1.3 认证

Gemini CLI 提供三种认证方式，个人用户推荐 Google 账户 OAuth 登录，有最慷慨的免费额度。

**方式一：Google 账户 OAuth 登录（推荐）**

```bash
gemini
# 启动后选择 "Sign in with Google" → 浏览器完成 OAuth 授权
```

| 账户类型 | 免费额度 |
|---------|---------|
| 个人 Google 账户 | 60 请求/分钟，1000 请求/天 |
| Gemini Advanced 订阅 | 更高额度 |

**方式二：Gemini API Key**

```bash
export GEMINI_API_KEY="你的 API Key"
gemini
```

从 [Google AI Studio](https://aistudio.google.com/apikey) 获取，同样享有免费额度（1000 请求/天）。

也可写入 `~/.gemini/.env` 文件永久生效：

```bash
# ~/.gemini/.env
GEMINI_API_KEY=你的 API Key
```

**方式三：Vertex AI（企业/高级用法）**

```bash
# A. Application Default Credentials（推荐）
gcloud auth application-default login
export GOOGLE_CLOUD_PROJECT="your-project-id"
export GOOGLE_CLOUD_LOCATION="us-central1"
export GOOGLE_GENAI_USE_VERTEXAI=true

# B. 服务账户 JSON Key
export GOOGLE_APPLICATION_CREDENTIALS="/path/to/keyfile.json"

# C. Google Cloud API Key
export GOOGLE_API_KEY="your-api-key"
```

---

## 2. API 与配置

### 2.1 模型选择

```bash
gemini -m gemini-2.5-pro    # 启动时指定
/model set gemini-2.5-flash  # 会话内切换（临时）
/model set gemini-2.5-pro --persist   # 切换并持久化到 settings.json
```

| 模型 | 特点 |
|------|------|
| `gemini-2.5-pro` | 最强推理，复杂任务首选 |
| `gemini-2.5-flash` | 速度快，日常使用 |

### 2.2 常用环境变量

| 变量 | 说明 |
|------|------|
| `GEMINI_API_KEY` | Gemini API Key |
| `GOOGLE_CLOUD_PROJECT` | GCP 项目 ID（Vertex AI 用） |
| `GOOGLE_CLOUD_LOCATION` | GCP 区域（默认 `us-central1`） |
| `GOOGLE_GENAI_USE_VERTEXAI` | 设 `true` 使用 Vertex AI |
| `GOOGLE_APPLICATION_CREDENTIALS` | 服务账户 JSON 路径 |
| `GEMINI_SANDBOX` | 沙盒模式（`true` / `docker` / `podman`） |

---

## 3. 目录结构总览

```text
~/.gemini/                     ← 全局配置（所有项目生效）
├── settings.json              ← 全局设置
├── GEMINI.md                  ← 全局指令（个人习惯）
├── .env                       ← 环境变量（API Key 等）
├── skills/                    ← 用户级技能
│   └── my-skill/
│       └── SKILL.md
└── policies/                  ← 权限策略文件（TOML）
    └── my-policy.toml

your-project/
├── GEMINI.md                  ← 项目指令（Git 根目录）
└── .gemini/
    ├── settings.json          ← 项目覆盖配置
    ├── skills/                ← 项目级技能
    └── policies/              ← 项目权限策略
```

**配置优先级（高→低）**：CLI 参数 > 环境变量 > 系统强制 > 项目 settings > 用户 settings > 系统默认值

**项目 `.gemini/settings.json` 需要信任后才生效**：

```json
{
  "security": {
    "folderTrust": { "enabled": true }
  }
}
```

或在会话内执行：`/permissions trust`

---

## 4. GEMINI.md — 项目永久记忆

### 什么是 GEMINI.md？

GEMINI.md 是 Gemini CLI 的项目指令文件，对应 Claude Code 的 CLAUDE.md。每次会话启动自动读取，无需重复解释项目背景。

**三级加载层级**（内容叠加，靠近当前目录的优先级更高）：

1. `~/.gemini/GEMINI.md` — 个人全局习惯
2. Git 根目录及父目录中的 `GEMINI.md` — 项目总体说明
3. 工具访问某目录时，自动加载该目录下的 `GEMINI.md` — 组件级精细指令

**自动生成骨架**（会话内）：

```text
/init
```

Gemini 会分析当前目录结构，自动生成 GEMINI.md 草稿。

**文件导入语法**（引用其他文件）：

```markdown
@./docs/architecture.md
@./docs/api-conventions.md
```

**自定义识别文件名**（在 settings.json 中配置）：

```json
{
  "context": {
    "fileName": ["GEMINI.md", "AGENTS.md", "CLAUDE.md", "CONTEXT.md"]
  }
}
```

**管理命令**：

```text
/memory show    ← 查看合并后的完整内容
/memory reload  ← 重新扫描所有指令文件
/memory list    ← 列出已加载的文件路径
/memory add <text>  ← 追加内容到全局 GEMINI.md
```

### GEMINI.md 示例

**`~/.gemini/GEMINI.md`**（全局个人习惯）

```markdown
# 我的个人开发习惯

## 偏好
- 回复使用中文
- 解释问题时先结论后原因
- 提交信息格式：`type(scope): message`（Conventional Commits）

## 约定
- Go 项目：`go test ./...` 运行测试
- Node 项目：优先使用 pnpm
- 不在没有询问的情况下重构无关代码
- 不添加未要求的功能
```

**`GEMINI.md`**（项目级）

```markdown
# 项目名称

## 这是什么
Go + Gin 构建的 REST API 服务。

## 技术栈
- 语言：Go 1.22
- 框架：Gin + GORM
- 数据库：PostgreSQL 16

## 常用命令
- 启动：`make dev`
- 测试：`make test`
- Lint：`golangci-lint run`

## 约定
- API 响应：`{ "code": 0, "data": ..., "message": "ok" }`
- 错误用 `pkg/errors` 包装
- handler 层只调用 service，不写业务逻辑

## 禁止
- 不修改 `.env` 文件
- 不引入未讨论的依赖

@./docs/architecture.md
@./docs/api-conventions.md
```

---

## 5. settings.json — 核心配置

### 什么是 settings.json？

Gemini CLI 使用 **JSON 格式**配置文件，控制模型、沙盒、审批、Hooks、MCP 等所有行为。

- **全局配置**：`~/.gemini/settings.json`
- **项目配置**：`your-project/.gemini/settings.json`

### 5.1 模型设置

```json
{
  "model": {
    "name": "gemini-2.5-pro",
    "maxSessionTurns": -1,
    "compressionThreshold": 0.5
  }
}
```

`compressionThreshold`：上下文使用超过该比例（0.0-1.0）时自动触发压缩，`-1` 禁用自动压缩。

### 5.2 界面设置

```json
{
  "ui": {
    "autoThemeSwitching": true,
    "hideBanner": false,
    "showLineNumbers": true,
    "loadingPhrases": "tips",
    "inlineThinkingMode": "off",
    "dynamicWindowTitle": true
  },
  "general": {
    "vimMode": false,
    "enableAutoUpdate": true,
    "enableNotifications": false
  }
}
```

### 5.3 工具设置

```json
{
  "tools": {
    "shell": {
      "enableInteractiveShell": true,
      "showColor": false
    },
    "useRipgrep": true,
    "truncateToolOutputThreshold": 40000
  }
}
```

### 5.4 文件过滤

```json
{
  "context": {
    "discoveryMaxDirs": 200,
    "fileFiltering": {
      "respectGitIgnore": true,
      "respectGeminiIgnore": true,
      "enableRecursiveFileSearch": true,
      "enableFuzzySearch": true,
      "customIgnoreFilePaths": [".myignore"]
    }
  }
}
```

> ✅ 可以在项目根目录创建 `.geminiignore` 文件排除特定文件，语法与 `.gitignore` 相同。

### 5.5 完整个人配置示例

**`~/.gemini/settings.json`**

```json
{
  "general": {
    "vimMode": false,
    "defaultApprovalMode": "default",
    "enableAutoUpdate": true,
    "enableNotifications": true,
    "retryFetchErrors": true
  },
  "model": {
    "name": "gemini-2.5-pro",
    "compressionThreshold": 0.7
  },
  "ui": {
    "autoThemeSwitching": true,
    "showLineNumbers": true,
    "loadingPhrases": "tips"
  },
  "tools": {
    "useRipgrep": true,
    "shell": {
      "enableInteractiveShell": true
    }
  },
  "security": {
    "toolSandboxing": false,
    "folderTrust": { "enabled": true }
  },
  "context": {
    "fileFiltering": {
      "respectGitIgnore": true,
      "respectGeminiIgnore": true
    }
  },
  "skills": { "enabled": true },
  "hooksConfig": { "enabled": true }
}
```

---

## 6. 沙盒与权限模型

### 什么是沙盒？

Gemini CLI 支持多种 OS 级沙盒机制，限制 AI 只能操作项目目录内的文件，防止意外修改系统文件。

### 6.1 沙盒模式

| 沙盒方式 | 平台 | 说明 |
|---------|------|------|
| **macOS Seatbelt** | macOS | `sandbox-exec`，限制项目目录外写入 |
| **Docker / Podman** | 跨平台 | 容器化隔离（推荐跨平台方案） |
| **gVisor (runsc)** | Linux | 用户态内核，最强隔离 |
| **LXC / LXD** | Linux | 完整系统容器（实验性） |

**启用方式**：

```bash
gemini -s                      # 命令行标志（自动选择最佳方式）
gemini --sandbox
GEMINI_SANDBOX=true gemini     # 环境变量
GEMINI_SANDBOX=docker gemini   # 指定具体方式
```

或在 settings.json：

```json
{
  "tools": { "sandbox": true }
}
```

### 6.2 审批模式

| 模式 | 说明 | 适用场景 |
|------|------|---------|
| `default` | 写操作需确认（默认） | 日常开发 |
| `auto_edit` | 放宽编辑操作限制 | 信任项目中快速迭代 |
| `plan` | 只读模式，先规划后执行 | 复杂任务前期分析 |
| `yolo` | 全部自动审批，不询问 | ⚠️ 隔离环境 / CI |

**切换方式**：
- `Shift+Tab` — 循环切换模式
- `Ctrl+Y` — 快速切换 YOLO 模式
- `gemini --approval-mode auto_edit` — 启动时指定

### 6.3 策略引擎（细粒度权限控制）

Gemini CLI 内置策略引擎，可通过 `policyPaths` 配置字段指定策略文件路径，对工具调用实施细粒度权限控制。

```json
// settings.json
{
  "policyPaths": [
    "~/.gemini/policies/team-policy.json",
    ".gemini/project-policy.json"
  ]
}
```

使用 `/policies list` 命令查看当前生效的策略列表。策略引擎支持的决策类型通常包括允许（allow）、拒绝（deny）、询问用户（ask_user）三种，具体策略文件格式请参考官方文档。

---

## 7. Skills — 技能扩展

### 什么是 Skill？

Skill（技能）是 Gemini CLI 的工作流扩展机制，以目录形式组织，包含 `SKILL.md` 文件告诉 Gemini 这个技能是什么、什么时候使用。

Gemini 可以**自动激活**合适的技能，也可以显式调用。

### 7.1 技能目录结构

```text
my-skill/
├── SKILL.md          ← 必需，YAML frontmatter + 工作流说明
├── scripts/          ← 可选，技能用到的脚本
├── references/       ← 可选，参考资料
└── assets/           ← 可选，静态资源
```

**`SKILL.md` 格式**：

```markdown
---
name: deploy
description: 部署到生产环境，包含完整前置检查和回滚流程。当用户说"部署"或"上线"时使用。
---

# 生产部署流程

## 前置检查
1. `git status` — 确认无未提交更改
2. `make test` — 确认测试全部通过
3. `git branch --show-current` — 确认在 main 分支

## 部署步骤
1. `make build`
2. `make db:migrate`
3. `make deploy:prod`

## 验证
- `curl https://api.example.com/health` — 检查健康状态

## 回滚
若出问题：`make deploy:rollback`
```

### 7.2 技能扫描位置

| 优先级 | 路径 | 说明 |
|--------|------|------|
| 高 | `.gemini/skills/` 或 `.agents/skills/` | 项目专属技能 |
| 中 | `~/.gemini/skills/` 或 `~/.agents/skills/` | 用户全局技能 |
| 低 | Extension 捆绑的技能 | 扩展内置技能 |

### 7.3 创建技能

**项目级技能**（仅当前项目可用）：

```bash
mkdir -p .gemini/skills/deploy
cat > .gemini/skills/deploy/SKILL.md << 'EOF'
---
name: deploy
description: 部署到生产环境，包含完整检查流程
---

# 生产部署流程
...
EOF
```

**用户级技能**（所有项目可用）：

```bash
mkdir -p ~/.gemini/skills/code-review
# 编写 SKILL.md ...
```

### 7.4 管理技能

```text
/skills list              ← 查看所有可用技能
/skills enable <name>     ← 启用技能
/skills disable <name>    ← 禁用技能
/skills reload            ← 重新扫描技能目录
```

在 settings.json 中全局启用/禁用：

```json
{
  "skills": { "enabled": true }
}
```

### 7.5 技能示例：React 组件规范

```markdown
---
name: create-component
description: 按项目规范创建 React 组件（含样式和测试）。当用户说"创建组件"或"新建组件"时使用。
---

# 创建 React 组件

## 确认信息
1. 组件名称（PascalCase）
2. 是否需要内部状态？
3. 需要哪些 props？

## 创建文件
在 `src/components/<ComponentName>/` 下创建：
- `index.tsx` — 组件主文件
- `styles.module.css` — 样式
- `<ComponentName>.test.tsx` — 测试

## 规范
- TypeScript 强类型，props 定义 interface
- 样式使用 CSS Modules
- 测试覆盖：渲染 + 核心交互

## 完成后
运行 `npm test src/components/<ComponentName>` 确认通过
```

---

## 8. Extensions — 插件生态

### 什么是 Extension？

Extension（扩展）是 Gemini CLI 的插件打包格式。一个扩展可以打包 MCP 服务器、自定义命令、主题、Hooks、子代理、技能等，方便安装和跨项目复用——类似 Claude Code 的 Plugin 机制。

**Extension 清单文件** `gemini-extension.json`：

```json
{
  "name": "my-extension",
  "version": "1.0.0",
  "description": "我的个人工具集",
  "mcpServers": {
    "my-server": {
      "command": "node",
      "args": ["${extensionPath}/server.js"],
      "cwd": "${extensionPath}"
    }
  }
}
```

### 8.1 安装扩展

```bash
# 从 GitHub 安装
gemini extensions install https://github.com/gemini-cli-extensions/workspace

# 会话内安装
/extensions install https://github.com/example/my-extension

# 从本地目录链接（开发模式）
/extensions link /path/to/local-extension
```

### 8.2 管理扩展

```text
/extensions list              ← 查看已安装扩展
/extensions enable <name>     ← 启用
/extensions disable <name>    ← 禁用
/extensions config <name>     ← 配置扩展参数
/extensions update <name>     ← 更新
/extensions restart <name>    ← 重启扩展
/extensions explore           ← 浏览扩展画廊
```

扩展画廊：https://geminicli.com/extensions/browse/

### 8.3 开发自己的扩展

```text
my-extension/
├── gemini-extension.json     ← 清单文件（必需）
├── skills/
│   └── my-workflow/
│       └── SKILL.md
├── hooks/
│   └── before-tool.sh
└── README.md
```

---

## 9. Hooks — 自动化钩子

### 什么是 Hook？

Gemini CLI 有完整的 Hooks 系统（比 Claude Code 更多事件类型），在生命周期的特定节点自动触发脚本，通过 JSON stdin/stdout 通信。

### 9.1 支持的事件（11 种）

| 事件 | 触发时机 | 典型用途 |
|------|---------|---------|
| `SessionStart` | 会话初始化 | 加载上下文、注入环境信息 |
| `SessionEnd` | 会话终止 | 清理、持久化状态 |
| `BeforeAgent` | 用户输入后、规划前 | 添加上下文、验证提示词 |
| `AfterAgent` | Agent 循环完成 | 审查输出、触发通知 |
| `BeforeModel` | LLM 请求前 | 修改提示、切换模型 |
| `AfterModel` | LLM 响应后 | 过滤响应、审计日志 |
| `BeforeToolSelection` | 工具选择前 | 限制可用工具集 |
| `BeforeTool` | 工具执行前 | 验证参数、阻止危险操作 |
| `AfterTool` | 工具执行后 | 自动格式化、运行测试 |
| `PreCompress` | 上下文压缩前 | 保存状态 |
| `Notification` | 系统警报 | 转发到外部系统 |

### 9.2 配置格式

Hooks 配置在 `settings.json` 的 `hooks` 字段中：

```json
{
  "hooks": {
    "BeforeTool": [
      {
        "matcher": "write_file",
        "hooks": [
          {
            "name": "auto-format",
            "type": "command",
            "command": "$GEMINI_PROJECT_DIR/.gemini/hooks/format.sh",
            "timeout": 5000
          }
        ]
      }
    ],
    "AfterTool": [
      {
        "matcher": "run_shell_command",
        "hooks": [
          {
            "name": "run-tests",
            "type": "command",
            "command": "$GEMINI_PROJECT_DIR/.gemini/hooks/test-check.sh"
          }
        ]
      }
    ],
    "SessionStart": [
      {
        "hooks": [
          {
            "name": "inject-context",
            "type": "command",
            "command": "echo '{\"systemMessage\": \"当前分支: '$(git branch --show-current 2>/dev/null || echo N/A)'\"}'"
          }
        ]
      }
    ]
  }
}
```

### 9.3 Hook 脚本 I/O

**stdin 接收的 JSON**（部分字段）：

```json
{
  "hook_event_name": "BeforeTool",
  "tool_name": "write_file",
  "tool_input": { "filename": "src/main.go", "content": "..." },
  "session_id": "xxx",
  "cwd": "/home/user/project"
}
```

**stdout 可以返回**：

| 输出 | 效果 |
|------|------|
| `{}` 或空 | 继续正常执行 |
| `{"decision": "block", "reason": "原因"}` | 阻止本次操作 |
| `{"systemMessage": "消息"}` | 注入提示给 Gemini |

**退出码**：
- `0` — 成功，解析 stdout JSON
- `2` — 关键错误，中止会话
- 其他 — 非致命警告，继续执行

**可用环境变量**：

```bash
GEMINI_PROJECT_DIR   # 项目根目录绝对路径
GEMINI_SESSION_ID    # 会话 ID
GEMINI_CWD           # 当前工作目录
```

### 9.4 实用 Hook 示例

**自动格式化（保存 Go/TS 文件后）**

```bash
#!/bin/bash
# .gemini/hooks/format.sh
input=$(cat)
file=$(echo "$input" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('filename',''))" 2>/dev/null)

if [[ "$file" == *.go ]]; then
  gofmt -w "$file"
elif [[ "$file" == *.ts || "$file" == *.tsx ]]; then
  npx prettier --write "$file"
fi

echo '{}'
```

**拦截危险命令**

```bash
#!/bin/bash
# .gemini/hooks/guard.sh
input=$(cat)
cmd=$(echo "$input" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('command',''))" 2>/dev/null)

for pattern in "rm -rf /" "rm -rf ~" "> /dev/sda" "DROP DATABASE"; do
  if echo "$cmd" | grep -qi "$pattern"; then
    echo "{\"decision\": \"block\", \"reason\": \"检测到危险命令: $pattern\"}"
    exit 0
  fi
done

echo '{}'
```

在 settings.json 中注册：

```json
{
  "hooks": {
    "BeforeTool": [
      {
        "matcher": "run_shell_command",
        "hooks": [
          {
            "name": "security-guard",
            "type": "command",
            "command": "$GEMINI_PROJECT_DIR/.gemini/hooks/guard.sh"
          }
        ]
      }
    ]
  }
}
```

### 9.5 管理 Hooks

```text
/hooks list           ← 查看所有 Hooks
/hooks enable <name>  ← 启用
/hooks disable <name> ← 禁用
/hooks enable-all     ← 全部启用
/hooks disable-all    ← 全部禁用
```

---

## 10. 多智能体

### 什么是子代理？

Gemini CLI 支持子代理（Sub-agents），可以定义专注于特定任务的 Agent，通过 `/agents` 命令管理。该功能目前为**实验性**，需在 settings.json 中启用。

### 10.1 Plan Mode（规划模式）

Plan Mode 是 Gemini CLI 的核心多步任务模式，先只读分析制定计划，确认后再执行：

```text
/plan             ← 进入 Plan Mode
Shift+Tab         ← 快速切换到 Plan Mode
```

Plan Mode 中 Gemini 会：
1. 只读分析代码库和需求
2. 制定详细的执行计划并展示给你
3. 等你确认后再开始执行

配置启用（settings.json）：

```json
{
  "experimental": { "plan": true }
}
```

### 10.2 子代理配置

```text
/agents list              ← 查看所有已发现的子代理
/agents reload            ← 重新扫描代理目录
/agents enable <name>     ← 启用子代理
/agents disable <name>    ← 禁用子代理
/agents config <name>     ← 调整代理模型和参数
```

### 10.3 GitHub Actions 集成

Gemini CLI 有官方 GitHub Action，可以在 CI 中自动处理 PR 审查、Issue 分类：

```yaml
# .github/workflows/gemini.yml
name: Gemini CLI
on:
  pull_request:
  issues:
    types: [opened, labeled]

jobs:
  gemini:
    runs-on: ubuntu-latest
    steps:
      - uses: google-github-actions/run-gemini-cli@v1
        with:
          gemini_api_key: ${{ secrets.GEMINI_API_KEY }}
          prompt: "审查这个 PR 的代码质量和安全问题"
```

---

## 11. MCP — 外部工具接入

### 什么是 MCP？

MCP（Model Context Protocol）让 Gemini 能连接外部工具：数据库、API、文件系统等。Gemini CLI MCP 配置写在 `settings.json` 的 `mcpServers` 字段中。

### 11.1 配置格式

```json
{
  "mcpServers": {
    "github": {
      "command": "docker",
      "args": [
        "run", "-i", "--rm",
        "-e", "GITHUB_PERSONAL_ACCESS_TOKEN",
        "ghcr.io/modelcontextprotocol/servers/github:latest"
      ],
      "env": {
        "GITHUB_PERSONAL_ACCESS_TOKEN": "${GITHUB_PERSONAL_ACCESS_TOKEN}"
      }
    },
    "filesystem": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-filesystem", "/path/to/dir"]
    },
    "postgres": {
      "command": "npx",
      "args": ["-y", "@anthropic-ai/mcp-server-postgres", "${DATABASE_URL}"]
    },
    "my-http-server": {
      "httpUrl": "https://mcp.example.com/api"
    },
    "my-sse-server": {
      "url": "https://mcp.example.com/sse"
    }
  }
}
```

连接优先级：`httpUrl` > `url` > `command`

> 🔒 Gemini CLI 自动过滤以下环境变量，防止泄露给 MCP 服务器：`GEMINI_API_KEY`、`GOOGLE_API_KEY`，以及匹配 `*TOKEN*`、`*SECRET*`、`*PASSWORD*`、`*KEY*`、`*AUTH*` 的变量。

### 11.2 使用 MCP 工具

```text
> @github 帮我列出最近的 open PR
> @postgres 查询 users 表中最近注册的 10 个用户
```

### 11.3 管理命令

```text
/mcp list              ← 列出已配置的服务器和工具
/mcp desc              ← 显示服务器和工具描述
/mcp schema            ← 显示工具的完整 schema
/mcp auth [server]     ← OAuth 认证
/mcp enable <name>     ← 启用服务器
/mcp disable <name>    ← 禁用服务器
/mcp refresh           ← 重启服务器并重新发现工具
```

### 11.4 常用 MCP 服务器

| 服务器 | 安装 / 配置 | 功能 |
|--------|-----------|------|
| GitHub（官方） | Docker 镜像 | PR、Issue、代码搜索 |
| `@modelcontextprotocol/server-filesystem` | npx | 受控文件系统访问 |
| `@anthropic-ai/mcp-server-postgres` | npx | PostgreSQL 查询 |
| `@anthropic-ai/mcp-server-sqlite` | npx | SQLite 本地数据库 |
| `@anthropic-ai/mcp-server-fetch` | npx | HTTP 请求 |

---

## 12. IDE 集成

### 12.1 支持的 IDE

| IDE | 集成方式 | 状态 |
|-----|---------|------|
| **VS Code** | "Gemini CLI Companion" 扩展 | ✅ 正式支持 |
| **Antigravity** | 原生内置 | ✅ 正式支持 |
| **Zed** | `--experimental-zed-integration` 标志 | 🧪 实验性 |

### 12.2 工作原理

IDE 扩展与 CLI **共享同一套 settings.json**：

```text
IDE Gemini CLI Companion 扩展
    ↓ 调用
本地 gemini CLI
    ↓ 读取
~/.gemini/settings.json   → 全局配置
.gemini/settings.json     → 项目配置
GEMINI.md                 → 项目指令
```

**IDE 上下文感知**：自动注入最近 10 个文件、当前光标位置、选中文本（最多 16KB）。

### 12.3 安装方式

```bash
# 方式一：CLI 自动提示（在支持的 IDE 中运行 Gemini 时会提示）

# 方式二：会话内安装
/ide install

# 方式三：VS Code Marketplace 搜索 "Gemini CLI Companion"
```

### 12.4 管理命令

```text
/ide enable     ← 激活 IDE 集成
/ide disable    ← 停用
/ide status     ← 查看集成状态
```

### 12.5 在 settings.json 中启用

```json
{
  "ide": { "enabled": true }
}
```

---

## 13. 与 Claude Code / Codex 的对比

| 维度 | Gemini CLI | Claude Code | Codex CLI |
|------|-----------|-------------|-----------|
| **默认模型** | Gemini 2.5 Pro/Flash | Claude Sonnet/Opus | GPT-5.4 |
| **配置格式** | JSON (`settings.json`) | JSON (`settings.json`) | TOML (`config.toml`) |
| **指令文件** | `GEMINI.md` | `CLAUDE.md` | `AGENTS.md` |
| **技能系统** | `SKILL.md`（`.gemini/skills/`） | Markdown（`.claude/skills/`） | `SKILL.md`（`.agents/skills/`） |
| **插件生态** | Extensions（画廊 + 自制） | Plugins（官方 + 第三方市场） | 无官方插件市场 |
| **Hooks 事件数** | **11 种**（最完整） | 22 种 | 2 种（实验性） |
| **沙盒实现** | OS 级 + Docker + gVisor | 容器级 | OS 级（macOS/Linux） |
| **审批模式** | default/auto_edit/plan/yolo | suggest/auto-edit/full-auto | untrusted/on-request/never |
| **多智能体** | 实验性（/agents） | 成熟（Sub-agents） | 内置原生并行 |
| **MCP 支持** | 完整，在 settings.json | 完整，在 .mcp.json | 完整，在 config.toml |
| **Web 搜索** | 内置（google_web_search） | 内置（WebSearch） | 需启用（--search） |
| **图片输入** | ✅ 原生多模态 | ✅ | ✅ |
| **GitHub Actions** | ✅ 官方 Action | ✅ | ✅ |
| **桌面应用** | 无 | 无 | 有（macOS） |
| **IDE 支持** | VS Code / Antigravity / Zed | VS Code | VS Code/Cursor/Windsurf/JetBrains |
| **免费使用** | ✅ Google 账户免费额度 | ❌（需订阅/付费） | ❌（需订阅/付费） |
| **开源协议** | Apache-2.0 | 闭源 | CLI Apache-2.0 |
| **强项** | 免费额度、多模态、Hooks 完整 | 插件生态、快速生成 | JetBrains、原生并行多智能体 |

**选择建议**：

- **想免费使用** → 优先 Gemini CLI（Google 账户 1000 请求/天）
- **重视 Hooks 自动化** → Gemini CLI（11 种事件）或 Claude Code（22 种）
- **最丰富的插件生态** → Claude Code
- **JetBrains IDE 用户** → Codex CLI
- **多模态（图片/PDF 输入）** → Gemini CLI 原生支持最佳
- **开源可审计** → Gemini CLI 或 Codex（均 Apache-2.0）

---

## 快速参考

### 常用 CLI 命令

```bash
gemini                              # 启动交互式 TUI
gemini -p "解释这段代码"            # 单次问答（非交互）
gemini -p "..." -i                  # 执行后进入交互模式
gemini -p "..." --output-format json       # JSON 输出
gemini -p "..." --output-format stream-json  # 流式 JSON
gemini -m gemini-2.5-flash          # 指定模型
gemini -s                           # 启用沙盒
gemini --approval-mode auto_edit    # 指定审批模式
gemini --resume <session-id>        # 恢复指定会话
gemini --list-sessions              # 列出所有会话
gemini update                       # 更新 Gemini CLI
```

### 会话内斜杠命令

**基础**

| 命令 | 说明 |
|------|------|
| `/help` 或 `/?` | 查看所有命令 |
| `/about` | 显示版本和配置信息 |
| `/clear` | 清屏 |
| `/quit` 或 `/exit` | 退出 |

**项目与记忆**

| 命令 | 说明 |
|------|------|
| `/init` | 分析项目，自动生成 GEMINI.md |
| `/memory show` | 查看合并后的 GEMINI.md 内容 |
| `/memory reload` | 重新加载指令文件 |
| `/memory list` | 列出已加载文件路径 |

**模型与配置**

| 命令 | 说明 |
|------|------|
| `/model set <name>` | 切换模型（临时） |
| `/model set <name> --persist` | 切换并持久化 |
| `/settings` | 查看当前配置 |
| `/auth` | 切换认证方式 |
| `/permissions trust` | 信任当前项目文件夹 |

**代码与规划**

| 命令 | 说明 |
|------|------|
| `/plan` | 进入只读规划模式 |
| `/plan copy` | 复制计划内容 |
| `/compress` | 压缩上下文释放 token |
| `/rewind` | 回退到上一步 |

**扩展与工具**

| 命令 | 说明 |
|------|------|
| `/extensions list` | 查看已安装扩展 |
| `/extensions explore` | 浏览扩展画廊 |
| `/mcp list` | 查看 MCP 工具 |
| `/skills list` | 查看可用技能 |
| `/agents list` | 查看子代理 |
| `/hooks list` | 查看 Hooks 配置 |

**会话管理**

| 命令 | 说明 |
|------|------|
| `/resume` | 恢复之前的会话 |
| `/resume save <tag>` | 保存当前会话检查点 |
| `/chat` | 管理多个聊天会话 |
| `/stats` | 查看 token 使用统计 |

### 常用快捷键

| 快捷键 | 说明 |
|--------|------|
| `Shift+Tab` | 循环切换审批模式 |
| `Ctrl+Y` | 快速切换 YOLO 模式 |
| `Ctrl+X` | 在外部编辑器编写长 prompt |
| `Ctrl+L` | 清屏 |
| `Ctrl+R` | 搜索历史 |
| `Esc+Esc` | 回退（Rewind） |
| `Tab` | 接受自动补全建议 |
| `!` 前缀 | 进入 Shell 模式 |
| `?` | 切换快捷键帮助面板 |

---

## 参考资源

| 资源 | 链接 |
|------|------|
| GitHub 仓库 | https://github.com/google-gemini/gemini-cli |
| 安装指南 | https://github.com/google-gemini/gemini-cli/blob/main/docs/get-started/installation.md |
| 认证文档 | https://github.com/google-gemini/gemini-cli/blob/main/docs/get-started/authentication.md |
| Settings 参考 | https://github.com/google-gemini/gemini-cli/blob/main/docs/reference/configuration.md |
| GEMINI.md 指南 | https://github.com/google-gemini/gemini-cli/blob/main/docs/cli/gemini-md.md |
| Skills 文档 | https://github.com/google-gemini/gemini-cli/blob/main/docs/cli/skills.md |
| Extensions 文档 | https://github.com/google-gemini/gemini-cli/blob/main/docs/extensions/index.md |
| Hooks 文档 | https://github.com/google-gemini/gemini-cli/blob/main/docs/hooks/index.md |
| MCP 文档 | https://github.com/google-gemini/gemini-cli/blob/main/docs/tools/mcp-server.md |
| CLI 参数参考 | https://github.com/google-gemini/gemini-cli/blob/main/docs/cli/cli-reference.md |
| 斜杠命令参考 | https://github.com/google-gemini/gemini-cli/blob/main/docs/reference/commands.md |
| 快捷键参考 | https://github.com/google-gemini/gemini-cli/blob/main/docs/reference/keyboard-shortcuts.md |
| 扩展画廊 | https://geminicli.com/extensions/browse/ |
| npm 包 | https://www.npmjs.com/package/@google/gemini-cli |

---

*2026-03-19 · 基于官方文档与社区实践编写*
