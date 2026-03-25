# OpenAI Codex CLI 最佳实践指南（2026）

> 面向个人开发者 · 从安装到精通 · 所有配置真实可用

---

## 目录

1. [安装与认证](#1-安装与认证)
2. [API 与代理配置](#2-api-与代理配置)
3. [目录结构总览](#3-目录结构总览)
4. [AGENTS.md — 项目永久记忆](#4-agentsmd--项目永久记忆)
5. [config.toml — 核心配置](#5-configtoml--核心配置)
6. [沙盒与权限模型](#6-沙盒与权限模型)
7. [Skills — 技能扩展](#7-skills--技能扩展)
8. [Apps 与插件](#8-apps-与插件)
9. [Hooks — 自动化钩子](#9-hooks--自动化钩子)
10. [多智能体](#10-多智能体)
11. [MCP — 外部工具接入](#11-mcp--外部工具接入)
12. [IDE 集成](#12-ide-集成)
13. [与 Claude Code 的对比](#13-与-claude-code-的对比)

---

## 1. 安装与认证

### 1.1 环境要求

| 组件 | 要求 | 说明 |
|------|------|------|
| 操作系统 | macOS / Linux / Windows（WSL2） | Windows 原生为实验性支持 |
| Node.js | ≥ 22（npm 安装方式需要） | 使用预编译二进制则无需 |
| Git | ≥ 2.34 | 项目操作依赖 |

### 1.2 安装 Codex CLI

**方式一：npm（最通用）**

```bash
npm install -g @openai/codex
```

**方式二：Homebrew（macOS）**

```bash
brew install --cask codex
```

**方式三：预编译二进制（无需 Node.js，最快）**

在 [GitHub Releases](https://github.com/openai/codex/releases) 下载对应平台包：

```bash
# macOS arm64 示例
curl -L https://github.com/openai/codex/releases/latest/download/codex-aarch64-apple-darwin.tar.gz | tar xz
sudo mv codex /usr/local/bin/
```

**升级**

```bash
npm i -g @openai/codex@latest
```

验证安装：`codex --version`

### 1.3 认证

**方式一：ChatGPT 账户登录（推荐，无需 API Key）**

```bash
codex login
```

浏览器 OAuth 流程完成后即可使用。Plus / Pro / Business / Enterprise 账户均包含 Codex 使用权限。退出登录：`codex logout`

**方式二：API Key**

```bash
export OPENAI_API_KEY="sk-proj-xxxxx"
codex
```

---

## 2. API 与代理配置

### 2.1 支持的提供商

Codex CLI 支持 OpenAI、Azure OpenAI、本地模型（Ollama/LM Studio）及任意兼容代理，在 `~/.codex/config.toml` 中配置：

**Azure OpenAI**

```toml
[model_providers.azure]
name = "Azure OpenAI"
base_url = "https://your-resource.openai.azure.com/openai/deployments/your-deployment"
env_key = "AZURE_OPENAI_API_KEY"
wire_api = "responses"

[wire_api_params]
query_params = { "api-version" = "2024-12-01-preview" }
```

**自定义代理/中转**

```toml
[model_providers.proxy]
name = "My Proxy"
base_url = "https://your-proxy.com/v1"
env_key = "PROXY_API_KEY"
```

启动时指定：

```bash
codex --config model_provider=proxy
```

**本地模型（Ollama / LM Studio）**

```toml
# ~/.codex/config.toml
oss_provider = "ollama"   # 或 "lmstudio"
```

```bash
codex --oss   # 命令行快捷方式
```

### 2.2 常用环境变量

| 变量 | 说明 |
|------|------|
| `OPENAI_API_KEY` | OpenAI API Key |
| `AZURE_OPENAI_API_KEY` | Azure OpenAI Key |
| `CODEX_UNSAFE_ALLOW_NO_SANDBOX` | 设 `1` 在不支持沙盒的系统上运行 |

---

## 3. 目录结构总览

```text
~/.codex/                  ← 全局配置（所有项目生效）
├── config.toml            ← 全局设置
├── AGENTS.md              ← 全局指令（个人习惯）
├── hooks.json             ← 全局 Hooks（实验性）
└── agents/                ← 自定义智能体定义
    └── reviewer.toml

~/.agents/
└── skills/                ← 用户级全局技能
    └── my-skill/
        └── SKILL.md

~/.codex.json              ← 登录凭证（OAuth Token，勿手动编辑）

your-project/
├── AGENTS.md              ← 项目指令（Git 根目录）
├── .codex/
│   ├── config.toml        ← 项目级配置（需信任才生效）
│   ├── hooks.json         ← 项目级 Hooks
│   └── agents/            ← 项目级智能体定义
│       └── reviewer.toml
└── .agents/
    └── skills/            ← 项目级技能
        └── my-skill/
            └── SKILL.md
```

**配置优先级（高→低）**：CLI 参数 > Profile 值 > 项目 config > 用户 config > 系统 config > 内置默认值

**项目 config 需要信任才生效**，可在用户 config 中预授信：

```toml
# ~/.codex/config.toml
[projects."/path/to/my/project"]
trust_level = "trusted"   # trusted | untrusted
```

---

## 4. AGENTS.md — 项目永久记忆

### 什么是 AGENTS.md？

AGENTS.md 是 Codex 的项目指令文件，对应 Claude Code 的 CLAUDE.md。每次会话启动自动读取，告诉 Codex 项目背景、技术栈和约定规范。

**加载顺序**（从根目录到当前目录逐层叠加）：

1. `~/.codex/AGENTS.md` — 个人全局习惯
2. Git 根目录 `AGENTS.md` — 项目总体说明
3. 各子目录 `AGENTS.md` — 模块级补充说明

> ✅ 合并后最大 **32 KiB**（可通过 `project_doc_max_bytes` 调整）

**自动生成骨架**（会话内输入）：

```text
/init
```

Codex 会分析项目结构，自动生成 AGENTS.md 草稿。

**自定义文件名**（可在 config.toml 中设置回退名称列表）：

```toml
project_doc_fallback_filenames = ["CODEX.md", "TEAM_GUIDE.md", ".agents.md"]

# 或完全替换为指定文件
model_instructions_file = "docs/AI_INSTRUCTIONS.md"
```

### AGENTS.md 示例

**`~/.codex/AGENTS.md`**（全局个人习惯）

```markdown
# 我的个人开发习惯

## 偏好
- 回复使用中文
- 解释问题时先结论后原因
- 提交信息格式：`type(scope): message`（Conventional Commits）

## 约定
- Go 项目：`go test ./...` 运行测试
- Node 项目：优先使用 pnpm
- 不在没有询问我的情况下重构无关代码
```

**`AGENTS.md`**（项目级）

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
```

---

## 5. config.toml — 核心配置

### 什么是 config.toml？

Codex 使用 **TOML 格式**配置文件（不是 JSON/YAML），控制模型、沙盒、审批、MCP 等所有行为。

- **全局配置**：`~/.codex/config.toml`
- **项目配置**：`your-project/.codex/config.toml`（需信任）

### 5.1 模型设置

```toml
model = "gpt-5.4"
model_provider = "openai"

# 推理深度：minimal | low | medium | high | xhigh
model_reasoning_effort = "medium"

# 推理摘要：auto | concise | detailed | none
model_reasoning_summary = "auto"

# 回复详细程度：low | medium | high
model_verbosity = "medium"

model_context_window = 200000

# 服务层级：flex（节省费用）| fast（优先速度）
service_tier = "flex"

# 个性风格：none | friendly | pragmatic
personality = "pragmatic"
```

### 5.2 Profiles（场景预设）

定义一次，随时切换：

```toml
[profiles.fast]
model_reasoning_effort = "low"
service_tier = "fast"

[profiles.deep]
model_reasoning_effort = "xhigh"
service_tier = "fast"
```

使用：

```bash
codex --profile deep "帮我分析这个算法的时间复杂度"
codex --profile fast  "帮我写一个简单函数"
```

### 5.3 Shell 环境策略

控制哪些宿主机环境变量传入沙盒：

```toml
[shell_environment_policy]
# all：继承所有 | core：仅继承基础变量（PATH/HOME/LANG 等）| none：全不继承
inherit = "core"

# 排除含敏感词的变量（glob 模式）
exclude = ["*SECRET*", "*TOKEN*", "*KEY*", "*PASSWORD*"]
```

### 5.4 界面设置

```toml
[tui]
animations = true
show_tooltips = true
theme = "Monokai"
alternate_screen = "auto"   # auto | always | never

# 点击代码引用时用哪个编辑器打开
file_opener = "cursor"      # vscode | vscode-insiders | cursor | windsurf | none
```

### 5.5 历史、搜索与通知

```toml
[history]
persistence = "save-all"    # save-all | none
# max_bytes = 10485760      # 历史文件大小上限

# 网络搜索：disabled | cached（复用缓存）| live（实时）
web_search = "cached"

# 完成通知（顶层数组，非区块）
notify = [
  "osascript -e 'display notification \"Codex 完成\" with title \"Codex\"'"
]
```

### 5.6 上下文压缩

```toml
# 自动压缩阈值（token 数），超过时自动执行 /compact
model_auto_compact_token_limit = 160000

# 自定义压缩提示词
compact_prompt = "请总结对话，保留所有关键决策、代码变更和待处理任务"
```

### 5.7 完整个人配置示例

**`~/.codex/config.toml`**

```toml
# 模型
model = "gpt-5.4"
model_reasoning_effort = "medium"
model_verbosity = "medium"
service_tier = "flex"
personality = "pragmatic"
web_search = "cached"

# 沙盒和审批（见第 6 节）
approval_policy = "on-request"
sandbox_mode = "workspace-write"

[sandbox_workspace_write]
network_access = false

# Shell 环境
[shell_environment_policy]
inherit = "core"
exclude = ["*SECRET*", "*TOKEN*", "*KEY*"]

# 界面
[tui]
theme = "Monokai"
file_opener = "cursor"

# 历史
[history]
persistence = "save-all"

# 完成通知（macOS）
notify = [
  "osascript -e 'display notification \"Codex 完成\" with title \"Codex\"'"
]

# 上下文自动压缩
model_auto_compact_token_limit = 160000

# 场景预设
[profiles.fast]
model_reasoning_effort = "low"
service_tier = "fast"

[profiles.deep]
model_reasoning_effort = "xhigh"

# 信任项目
[projects."/home/user/my-project"]
trust_level = "trusted"
```

---

## 6. 沙盒与权限模型

### 什么是沙盒？

Codex 在 OS 级沙盒中运行命令（macOS: `sandbox-exec`，Linux: namespace 隔离），即使是全自动模式，默认也**禁止出站网络访问**。

### 6.1 沙盒模式

| 模式 | 文件权限 | 网络 | 适用场景 |
|------|---------|------|---------|
| `read-only` | 只读 | 禁止 | 代码审查、问答 |
| `workspace-write` | 可写工作区 | 默认禁止 | 日常开发（推荐） |
| `danger-full-access` | 无限制 | 允许 | 隔离容器/CI 环境 |

### 6.2 审批策略

| 策略 | 说明 | 推荐场景 |
|------|------|---------|
| `untrusted` | 只有已知安全的只读命令自动执行 | 高安全要求 |
| `on-request` | 模型自判断何时需要确认（默认） | 日常开发 |
| `never` | 从不提示 | ⚠️ 危险，仅限隔离环境 |
| `granular` | 按类别细粒度控制 | 高级用户 |

**粒度控制（granular 模式）**：

```toml
approval_policy = "granular"

[approval_policy.granular]
sandbox_approval = true        # 沙盒变更需确认
skill_approval = false         # 技能调用不需确认
mcp_elicitations = true        # MCP 工具调用需确认
request_permissions = true     # 权限请求需确认
```

### 6.3 网络访问控制

```toml
[sandbox_workspace_write]
network_access = true          # 允许出站网络

[permissions.default.network]
enabled = true
mode = "limited"               # limited | full
allowed_domains = ["api.github.com", "registry.npmjs.org"]
```

### 6.4 常用快捷标志

```bash
codex --full-auto "帮我修复所有 lint 错误"
# 等同于 --ask-for-approval on-request --sandbox workspace-write

codex --yolo "..."
# ⚠️ 跳过所有审批和沙盒（--dangerously-bypass-approvals-and-sandbox 的别名）
# 仅在完全隔离的容器环境中使用
```

---

## 7. Skills — 技能扩展

### 什么是 Skill？

Skill（技能）是 Codex 的工作流扩展机制，遵循**开放代理技能标准（Open Agent Skills Standard）**。技能以目录形式组织，包含一个带 YAML frontmatter 的 `SKILL.md` 文件，告诉 Codex 这个技能是什么、什么时候使用。

Codex 可以**自动匹配**合适的技能（根据任务描述），也可以显式调用。

### 7.1 技能目录结构

```text
my-skill/
├── SKILL.md          ← 必需，包含 name + description 的 YAML frontmatter
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
- `curl https://api.example.com/health`

## 回滚
若出问题：`make deploy:rollback`
```

### 7.2 技能扫描位置

Codex 按以下优先级扫描技能（高→低）：

| 位置 | 路径 | 说明 |
|------|------|------|
| REPO | `.agents/skills/`（从当前目录向上搜索 Git 根） | 项目专属技能 |
| USER | `~/.agents/skills/` | 用户全局技能 |
| ADMIN | `/etc/codex/skills/` | 系统级技能 |
| SYSTEM | 内置技能 | Codex 自带 |

### 7.3 创建技能

**项目级技能**（仅当前项目可用）：

```bash
mkdir -p .agents/skills/deploy
cat > .agents/skills/deploy/SKILL.md << 'EOF'
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
mkdir -p ~/.agents/skills/my-workflow
# 编写 SKILL.md ...
```

### 7.4 配置技能

在 `config.toml` 中可以管理技能路径和启用状态：

```toml
[[skills.config]]
path = "/path/to/custom-skills"
enabled = true

[[skills.config]]
path = ".agents/skills/legacy"
enabled = false
```

### 7.5 调用技能

**自动调用**：Codex 根据 `description` 字段自动匹配任务并调用技能。

**显式调用**（会话内）：

```text
/skills            ← 查看所有可用技能
$deploy            ← 用 $ 前缀显式调用指定技能
```

### 7.6 技能示例：React 组件规范

```markdown
---
name: create-component
description: 按项目规范创建 React 组件（包含样式和测试）。当用户说"创建组件"或"新建组件"时使用。
---

# 创建 React 组件

## 确认信息
1. 组件名称（PascalCase）
2. 是否需要状态？
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

## 8. Apps 与插件

### 什么是 Apps？

Codex v0.113.0 引入了 **Plugin/Apps 系统**，通过 `/apps` 命令可以发现和安装 ChatGPT 连接器（Connector）。Apps 在会话中以 `$connector-name` 语法调用，让 Codex 与外部服务（如 GitHub Copilot、Linear、Notion）集成。

> 与 Skills 的区别：Skills 是本地工作流指令扩展；Apps 是运行时与外部服务的动态连接。

### 8.1 发现与管理

```text
/apps              ← 列出已安装和可用的 App
```

在 prompt 中用 `$` 符号引用已安装的连接器：

```text
$linear 帮我创建一个 bug issue：登录按钮在 Safari 下不响应点击
```

### 8.2 App 配置格式

Apps 通过 `.app.json` 文件定义，存放在 `.codex/apps/` 目录下：

```json
{
  "connector_id": "linear",
  "display_name": "Linear",
  "description": "项目管理和 Issue 跟踪",
  "mcp_tool": "linear_api"
}
```

### 8.3 与 MCP 的关系

Apps 本质上是对 MCP 工具的声明性封装，安装 App 后，Codex 通过对应的 `codex_apps` MCP 服务器与外部系统交互。如果只需要工具调用能力，直接配置 MCP 服务器即可；Apps 提供更友好的发现和调用体验。

---

## 9. Hooks — 自动化钩子

> ⚠️ **Codex 的 Hooks 目前处于实验阶段**，仅支持 `SessionStart` 和 `Stop` 两个事件。更完整的 PreToolUse/PostToolUse 等钩子是社区活跃的 Feature Request（[Issue #2109](https://github.com/openai/codex/issues/2109)）。

### 9.1 Hooks 配置文件

Hooks 配置在独立的 `hooks.json` 文件中，**不在** `config.toml` 里：

- 全局：`~/.codex/hooks.json`
- 项目级：`your-project/.codex/hooks.json`

```json
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "echo '会话开始' >> ~/.codex/log/session.log",
            "statusMessage": "初始化会话...",
            "timeout": 10
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "echo '会话结束' >> ~/.codex/log/session.log",
            "statusMessage": "收尾...",
            "timeout": 10
          }
        ]
      }
    ]
  }
}
```

> 注意：事件名为 `SessionStart` 和 `Stop`（不是 `SessionStop`）。

### 9.2 完成通知

```toml
# config.toml 中的顶层数组，不是区块
notify = [
  "osascript -e 'display notification \"Codex 完成\" with title \"Codex\"'"
]
```

### 9.3 用 codex exec 替代复杂 Hooks

对于更复杂的自动化需求，用非交互模式 + shell 脚本：

```bash
#!/bin/bash
# git pre-commit 钩子示例

# 让 Codex 自动修复 lint
codex exec "修复所有 golangci-lint 报告的问题，不要改变功能逻辑" \
  --sandbox workspace-write \
  --ask-for-approval never \
  --output-last-message /tmp/codex-fix.md

# 验证
go test ./...
```

---

## 10. 多智能体

### 什么是多智能体？

Codex CLI **原生内置**多智能体支持，可以同时运行多个并行 worker 处理不同子任务，无需额外插件。

### 10.1 全局配置

```toml
[agents]
max_threads = 6                    # 最大并发线程数（默认 6）
max_depth = 1                      # 最大嵌套深度（默认 1，即只允许一级子智能体）
job_max_runtime_seconds = 1800     # 单个 worker 超时（秒）
```

### 10.2 自定义智能体定义

自定义智能体以独立 TOML 文件定义，存放在 `~/.codex/agents/`（全局）或 `.codex/agents/`（项目级）：

**`.codex/agents/reviewer.toml`**：

```toml
name = "reviewer"
description = "代码审查专家，只读不修改，深入检查安全性和代码质量"
model = "gpt-5.4"
model_reasoning_effort = "high"
sandbox_mode = "read-only"
approval_policy = "never"
developer_instructions = """
你是一个严格的代码审查员。
只分析和报告问题，不做任何修改。
重点关注：安全漏洞、性能问题、代码规范。
"""
```

**`.codex/agents/tester.toml`**：

```toml
name = "tester"
description = "测试工程师，编写和运行测试用例"
model = "gpt-5.4"
sandbox_mode = "workspace-write"
approval_policy = "never"
developer_instructions = """
专注于编写全面的测试用例。
优先覆盖边界条件和错误路径。
"""
```

### 10.3 内置多智能体工具

| 工具 | 说明 |
|------|------|
| `spawn_agent` | 创建并启动子智能体 |
| `send_input` | 向已有智能体发送输入 |
| `resume_agent` | 恢复暂停的智能体 |
| `wait_agent` | 等待智能体完成并取回结果 |
| `close_agent` | 关闭智能体 |
| `spawn_agents_on_csv` | 批量对 CSV 每行启动智能体（实验性） |

### 10.4 典型并行工作流

```text
你：帮我全面审查这次 PR

Codex 自动并行派遣：
├─→ worker-1（read-only，high reasoning）：检查安全和代码质量
├─→ worker-2：检查测试覆盖率
└─→ worker-3：检查文档是否需要更新

各 worker 并行执行，结果汇总呈现
```

### 10.5 非交互式批量任务

```bash
# 对多个文件并行分析
for file in src/*.go; do
  codex exec "审查 $file 的安全问题" \
    --sandbox read-only \
    --ask-for-approval never \
    --json &
done
wait
```

---

## 11. MCP — 外部工具接入

### 什么是 MCP？

MCP（Model Context Protocol）让 Codex 能连接外部工具：数据库、API、文件系统等。Codex MCP 配置直接写在 `config.toml` 中，无需单独的 `.mcp.json`。

### 10.1 配置 MCP 服务器

```toml
# STDIO 本地进程
[mcp_servers.context7]
command = "npx"
args = ["-y", "@upstash/context7-mcp"]
enabled = true
startup_timeout_sec = 30
tool_timeout_sec = 60

# HTTP 远程服务器
[mcp_servers.figma]
url = "https://mcp.figma.com/mcp"
bearer_token_env_var = "FIGMA_OAUTH_TOKEN"

# 带 OAuth 的服务器
[mcp_servers.github]
url = "https://api.github.com/mcp"
scopes = ["repo", "read:org"]

# 工具白名单/黑名单
[mcp_servers.github]
url = "https://api.github.com/mcp"
enabled_tools = ["search_code", "list_prs", "get_issue"]
disabled_tools = ["delete_repo"]

# OAuth 全局设置
mcp_oauth_callback_port = 8080
mcp_oauth_credentials_store = "auto"   # auto | file | keyring
```

### 10.2 CLI 命令

```bash
# 添加 stdio MCP 服务器
codex mcp add context7 -- npx -y @upstash/context7-mcp

# 添加带环境变量的服务器
codex mcp add my-server --env API_KEY=xxx -- /path/to/server

# OAuth 认证
codex mcp login my-oauth-server
```

### 10.3 常用 MCP 服务器

| 服务器 | 安装 | 功能 |
|--------|------|------|
| `@upstash/context7-mcp` | npx | 文档和代码上下文检索 |
| `@anthropic-ai/mcp-server-github` | npx | GitHub 操作 |
| `@anthropic-ai/mcp-server-postgres` | npx | PostgreSQL 查询 |
| `@anthropic-ai/mcp-server-sqlite` | npx | SQLite 本地数据库 |
| `@anthropic-ai/mcp-server-fetch` | npx | HTTP 请求 |
| Figma MCP | HTTP | 读取 Figma 设计稿 |

---

## 12. IDE 集成

### 12.1 安装

在各 IDE 扩展市场搜索 **"Codex"** 安装官方扩展：

| IDE | 说明 |
|-----|------|
| VS Code | VS Code Marketplace 搜索 "Codex -- OpenAI's coding agent" |
| Cursor | 同上，需在 activity bar 右键勾选显示图标 |
| Windsurf | 扩展市场安装 |
| JetBrains | IntelliJ / PyCharm / WebStorm / Rider，支持 JetBrains AI 订阅认证 |

### 12.2 工作原理

IDE 扩展与 CLI **共享同一套 `config.toml`**，配置效果完全一样：

```text
IDE Codex 扩展
    ↓ 调用
本地 codex CLI
    ↓ 读取
~/.codex/config.toml   → 全局配置
.codex/config.toml     → 项目配置
AGENTS.md              → 项目指令
.agents/skills/        → 技能
```

### 12.3 编辑器关联

```toml
# ~/.codex/config.toml
file_opener = "cursor"   # 点击代码引用时打开的编辑器
```

### 12.4 Codex App（macOS 桌面应用）

macOS 用户可以使用独立的桌面应用，提供 GUI 界面和 **worktree 支持**（在隔离 Git 工作树中运行任务）：

```bash
codex app   # 启动桌面应用
```

> ℹ️ Worktree 功能目前**仅 Codex App 支持**，CLI 尚无原生 `--worktree` flag。

### 12.5 常见问题

| 问题 | 解决方法 |
|------|---------|
| 扩展找不到 codex 命令 | 确认 `codex` 在 `PATH`；重启 IDE |
| 认证失败 | 重新运行 `codex login`；检查 API Key |
| MCP 不生效 | 检查 `config.toml` TOML 格式；查看日志 `~/.codex/log/codex-tui.log` |
| Cursor 找不到图标 | activity bar 右键 → 勾选 Codex |

---

## 13. 与 Claude Code 的对比

| 维度 | Codex CLI | Claude Code |
|------|-----------|-------------|
| **底层语言** | Rust | TypeScript |
| **默认模型** | GPT-5.4 | Claude Sonnet/Opus |
| **配置格式** | TOML (`config.toml`) | JSON (`settings.json`) |
| **指令文件** | `AGENTS.md` | `CLAUDE.md` |
| **技能系统** | `SKILL.md`（Open Agent Skills Standard） | Markdown（`.claude/skills/`） |
| **插件/Apps** | Plugin/Apps 系统（v0.113+，`/apps` 命令） | 有（官方 + 第三方市场） |
| **沙盒实现** | OS 级（macOS sandbox / Linux namespace） | 容器级 |
| **审批模式** | `untrusted` / `on-request` / `never` | `suggest` / `auto-edit` / `full-auto` |
| **Hooks** | 实验性（仅 SessionStart/Stop） | 成熟（22 种事件） |
| **多智能体** | 内置原生并行（`spawn_agent` 等工具） | 内置（Sub-agents） |
| **MCP 支持** | 完整，配置在 `config.toml` | 完整，配置在 `.mcp.json` |
| **云端任务** | 有（`codex cloud` 异步远程任务） | 无 |
| **桌面应用** | 有（macOS，含 worktree 支持） | 无 |
| **IDE 支持** | VS Code / Cursor / Windsurf / JetBrains | VS Code |
| **开源协议** | CLI Apache-2.0 | 闭源 |
| **计费** | ChatGPT Plus/Pro 包含 | Claude Pro/Max 包含 |
| **强项** | JetBrains 生态、安全审查、OS 级沙盒 | Hooks 自动化、插件生态、快速代码生成 |

**选择建议**：

- 用 **JetBrains IDE** → 优先 Codex（原生支持）
- 需要**丰富的 Hooks 自动化** → 优先 Claude Code
- 需要**更成熟的插件生态** → 优先 Claude Code（Codex Apps 仍在成长中）
- 注重**开源可审计** → 优先 Codex（CLI Apache-2.0）
- **混合使用**（推荐）：Claude Code 快速生成代码，Codex `/review` 在合并前做安全审查

---

## 快速参考

### 常用 CLI 命令

```bash
codex                                        # 启动交互式 TUI
codex "帮我解释这段代码"                      # 单次问答
codex exec "修复 lint 问题"                  # 非交互执行
codex exec "..." --json                      # JSON 格式输出
codex exec "..." --output-last-message out.md  # 将最终消息写入文件
codex exec "..." --ephemeral                 # 不持久化会话
codex resume --last                          # 恢复上一个会话
codex fork                                   # 从当前会话分叉新线程
codex --profile deep "..."                  # 使用预设 profile
codex --full-auto "..."                     # 低阻力自动模式
codex --sandbox read-only "..."             # 强制只读沙盒
codex --model gpt-5.4 "..."                # 指定模型
codex --oss "..."                           # 使用本地 Ollama 模型
codex --search "..."                        # 启用实时 Web 搜索
codex --yolo "..."                          # ⚠️ 跳过所有限制
codex login / codex logout                  # 认证管理
codex mcp list                              # 查看 MCP 服务器
codex features                              # 管理 feature flags
codex cloud                                 # 浏览/执行云端任务
codex app                                   # 启动 macOS 桌面应用
```

### 会话内斜杠命令与快捷键

**斜杠命令**

| 命令 | 说明 |
|------|------|
| `/init` | 自动生成 AGENTS.md 骨架 |
| `/plan` | 切换计划模式（先规划再执行） |
| `/review` | 审查工作树的代码变更 |
| `/permissions` | 调整审批和沙盒模式 |
| `/skills` | 查看可用技能列表 |
| `/apps` | 查看和管理已安装的 App 连接器 |
| `/agent` | 切换/查看多智能体线程 |
| `/mcp` | 查看 MCP 服务器状态 |
| `/compact` | 压缩对话上下文，释放 token |
| `/ps` | 查看正在运行的进程 |
| `/diff` | 查看当前变更差异 |
| `/model` | 切换模型 |
| `/fork` | 从当前状态分叉新线程 |
| `/new` | 开始新会话 |
| `/status` | 查看当前会话状态 |
| `/theme` | 切换语法高亮主题 |
| `/exit` | 退出 |

**快捷键**

| 快捷键 | 说明 |
|--------|------|
| `Shift+Tab` | 切换计划模式 |
| `@` | 模糊搜索附加文件 |
| `$skill-name` | 显式调用指定技能 |
| `!` 前缀 | 直接执行 shell 命令 |
| `Ctrl+G` | 在外部编辑器编写长 prompt |
| `Ctrl+C` | 中断当前操作 |

### 常见场景推荐配置

| 场景 | 推荐配置 |
|------|---------|
| 日常开发 | `approval_policy = "on-request"` + `sandbox_mode = "workspace-write"` |
| 代码审查 | `--sandbox read-only` + `model_reasoning_effort = "high"` |
| CI 自动化 | `codex exec ... --ask-for-approval never --sandbox workspace-write` |
| 复杂问题 | `--profile deep`（`model_reasoning_effort = "xhigh"`） |
| 快速问答 | `--profile fast`（`model_reasoning_effort = "low"`） |

---

## 参考资源

| 资源 | 链接 |
|------|------|
| 官方文档首页 | https://developers.openai.com/codex |
| CLI 快速入门 | https://developers.openai.com/codex/cli |
| Config 完整参考 | https://developers.openai.com/codex/config-reference |
| AGENTS.md 指南 | https://developers.openai.com/codex/guides/agents-md |
| Skills 文档 | https://developers.openai.com/codex/skills |
| MCP 文档 | https://developers.openai.com/codex/mcp |
| CLI 参数参考 | https://developers.openai.com/codex/cli/reference |
| 斜杠命令参考 | https://developers.openai.com/codex/cli/slash-commands |
| 最佳实践 | https://developers.openai.com/codex/learn/best-practices |
| GitHub 仓库 | https://github.com/openai/codex |

---

*2026-03-19 · 基于官方文档与社区实践编写*
