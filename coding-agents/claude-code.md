# Claude Code 最佳实践指南（2026）

> 面向个人开发者 · 从安装到精通 · 所有配置真实可用

---

## 目录

1. [安装与认证](#1-安装与认证)
2. [API 与代理配置](#2-api-与代理配置)
3. [目录结构总览](#3-目录结构总览)
4. [CLAUDE.md — 项目永久记忆](#4-claudemd--项目永久记忆)
5. [settings.json — 核心配置](#5-settingsjson--核心配置)
6. [Skills — 技能扩展](#6-skills--技能扩展)
7. [Plugins — 插件生态](#7-plugins--插件生态)
8. [Hooks — 自动化钩子](#8-hooks--自动化钩子)
9. [Sub-agents — 多智能体](#9-sub-agents--多智能体)
10. [MCP — 外部工具接入](#10-mcp--外部工具接入)
11. [VSCode 集成](#11-vscode-集成)

---

## 1. 安装与认证

### 1.1 环境要求

| 组件 | 要求 | 说明 |
|------|------|------|
| 操作系统 | macOS / Linux / Windows / WSL2 | 全平台支持 |
| **Git** | ≥ 2.34 | **必须安装**，Skill/Plugin 安装依赖 Git |
| Node.js | ≥ 18（仅 npm 方式需要） | 使用原生安装器则无需 Node.js |

### 1.2 安装 Git

```bash
# Ubuntu / Debian
sudo apt update && sudo apt install -y git

# CentOS / RHEL / Rocky
sudo dnf install -y git

# macOS
brew install git
# 或安装 Xcode 命令行工具（包含 Git）
xcode-select --install

# Windows
winget install Git.Git
```

验证：`git --version`

### 1.3 安装 Node.js（仅 npm 方式需要）

```bash
# Linux（官方 NodeSource 脚本，推荐）
curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
sudo apt install -y nodejs

# macOS
brew install node@20

# Windows
winget install OpenJS.NodeJS.LTS
```

### 1.4 安装 Claude Code

**推荐方式：原生安装器（无需 Node.js，支持自动更新）**

```bash
# macOS / Linux / WSL2
curl -fsSL https://claude.ai/install.sh | bash
```

```powershell
# Windows PowerShell
irm https://claude.ai/install.ps1 | iex
```

**其他方式**

```bash
# macOS Homebrew（不自动更新）
brew install --cask claude-code

# Windows WinGet（不自动更新）
winget install Anthropic.ClaudeCode

# npm（已废弃但仍可用，需 Node.js 18+）
npm install -g @anthropic-ai/claude-code

# Bun（社区方式，本质同 npm，可用）
bun install -g @anthropic-ai/claude-code
```

| 方式 | 依赖 | 自动更新 | 推荐 |
|------|------|---------|------|
| 原生脚本 | 无 | ✅ | ⭐ 首选 |
| Homebrew | Homebrew | ❌ 需手动 `brew upgrade` | macOS 用户 |
| winget | winget | ❌ | Windows 用户 |
| npm / Bun | Node.js / Bun | ❌ | 已有相应环境 |

### 1.5 认证

```bash
# 浏览器 OAuth 登录（推荐）
claude auth login

# 验证安装和配置
claude doctor

# 查看版本
claude --version
```

> 💡 如果你用的是代理/中转 API，不需要执行 `claude auth login`，直接在 settings.json 中配置 Key 即可（见第 2 节）。

### 1.6 自动化环境跳过引导

在 CI 或无人值守环境中使用时，跳过首次启动的交互引导：

```bash
cat > ~/.claude.json << 'EOF'
{
  "hasCompletedOnboarding": true
}
EOF
```

---

## 2. API 与代理配置

Claude Code 从 API 获取模型能力。你可以直接使用 Anthropic 官方 API，也可以接入代理/中转服务。

### 2.1 三种接入方式

| 方式 | 认证变量 | HTTP 头部 | 适用场景 |
|------|---------|---------|---------|
| 官方 API | `ANTHROPIC_API_KEY` | `x-api-key` | 有 Anthropic 账号直接付费 |
| 代理（Key 格式） | `ANTHROPIC_API_KEY` + `ANTHROPIC_BASE_URL` | `x-api-key` | 代理服务兼容 Anthropic 格式 |
| 代理（Token 格式） | `ANTHROPIC_AUTH_TOKEN` + `ANTHROPIC_BASE_URL` | `Authorization: Bearer` | LiteLLM / Requesty / 国内中转 |

> ⚠️ `ANTHROPIC_API_KEY` 和 `ANTHROPIC_AUTH_TOKEN` **只能设一个**，二者互斥。

### 2.2 配置方法

推荐写入 `~/.claude/settings.json` 永久生效（对所有项目有效）；
项目私有配置写入 `.claude/settings.local.json`（不提交 Git）。

**官方 API**

```json
{
  "env": {
    "ANTHROPIC_API_KEY": "sk-ant-api03-xxxxx"
  }
}
```

**代理中转（API Key 格式）**

```json
{
  "env": {
    "ANTHROPIC_API_KEY": "sk-proxy-xxxxx",
    "ANTHROPIC_BASE_URL": "https://your-proxy.com/v1"
  }
}
```

**代理中转（Auth Token 格式）**

```json
{
  "env": {
    "ANTHROPIC_AUTH_TOKEN": "Bearer sk-xxxxx",
    "ANTHROPIC_BASE_URL": "https://your-proxy.com/v1"
  }
}
```

### 2.3 常用环境变量

| 变量 | 说明 |
|------|------|
| `ANTHROPIC_API_KEY` | 官方或兼容格式代理 Key |
| `ANTHROPIC_AUTH_TOKEN` | Bearer Token 格式代理认证 |
| `ANTHROPIC_BASE_URL` | 自定义 API 端点地址 |
| `ANTHROPIC_MODEL` | 覆盖默认使用的模型 |
| `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC` | 设 `1` 禁用遥测和更新检查（隐私保护） |
| `CLAUDE_CODE_MAX_OUTPUT_TOKENS` | 单次最大输出 Token 数 |

### 2.4 动态凭证（密钥管理工具）

如果你使用 1Password、AWS Secrets Manager 等工具管理密钥，可以配置 `apiKeyHelper`，Claude Code 启动时执行该命令获取 Key：

```json
{
  "apiKeyHelper": "op read 'op://Personal/anthropic/api-key'"
}
```

---

## 3. 目录结构总览

Claude Code 有两级配置：全局（对所有项目生效）和项目级（仅当前项目）。

```text
~/.claude/                     ← 全局配置（你的所有项目都加载）
├── settings.json              ← 全局设置
├── settings.local.json        ← 全局本地覆盖（私密，不提交 Git）
├── CLAUDE.md                  ← 全局指令（适用所有项目的个人习惯）
├── rules/                     ← 全局规则文件
└── skills/                    ← 全局自定义技能

~/.claude.json                 ← OAuth 会话、MCP 配置（HOME 目录下，非 .claude/ 内）

your-project/
├── CLAUDE.md                  ← 项目指令（根目录，会被加载）
├── .mcp.json                  ← 项目 MCP 服务器配置
└── .claude/
    ├── settings.json          ← 项目设置（提交 Git，和团队共享）
    ├── settings.local.json    ← 项目本地覆盖（不提交 Git，放 .gitignore）
    ├── CLAUDE.md              ← 项目指令（.claude/ 内，也会加载）
    ├── rules/                 ← 项目路径规则
    ├── skills/                ← 项目自定义技能
    └── agents/                ← 子智能体定义
```

**优先级（高→低）**：企业管控 > `settings.local.json` > `settings.json`（项目） > `settings.json`（全局）

**`.gitignore` 必须添加**：

```gitignore
# 含 API Key，禁止提交
.claude/settings.local.json
```

---

## 4. CLAUDE.md — 项目永久记忆

### 什么是 CLAUDE.md？

CLAUDE.md 是你写给 Claude 的"永久工作说明"。每次会话启动，Claude 会自动读取它，从此不再需要每次重复解释项目背景、规范约束。

**加载顺序**（多个文件同时生效，内容合并）：

1. `~/.claude/CLAUDE.md` — 你的个人全局习惯
2. `CLAUDE.md`（项目根目录）
3. `.claude/CLAUDE.md`（项目 `.claude/` 内）
4. `.claude/rules/*.md` — 细分场景的规则

> ✅ CLAUDE.md **完整加载，无行数限制**。（200 行截断只适用于自动记忆 `MEMORY.md`）

### @引用语法

CLAUDE.md 内可以用 `@path` 引用其他文件，最多 5 层嵌套：

```markdown
@.claude/rules/go-style.md
@.claude/rules/testing.md
```

### 管理命令

```text
/memory      ← 查看当前会话加载的所有 CLAUDE.md 和记忆文件
```

### CLAUDE.md 示例

**`~/.claude/CLAUDE.md`**（全局个人习惯，所有项目生效）

```markdown
# 我的个人开发习惯

## 偏好
- 回复使用中文
- 代码注释使用中文
- 解释问题时先说结论，再讲原因

## 工具使用
- Go 项目使用 `go test ./...` 运行测试
- JavaScript 项目优先使用 pnpm
- 提交信息格式：`type(scope): message`（Conventional Commits）

## 我不喜欢的事
- 不要在没问我的情况下重构不相关的代码
- 不要添加我没有要求的功能
- 不要过度添加注释
```

**`CLAUDE.md`**（项目级，描述这个项目是什么）

```markdown
# 项目名称

## 这是什么
一个 Go + Gin 构建的 REST API 服务，用于 [功能描述]。

## 技术栈
- 语言：Go 1.22
- 框架：Gin + GORM
- 数据库：PostgreSQL 16
- 测试：testify

## 常用命令
- 启动：`make dev`
- 测试：`make test`
- 构建：`make build`
- Lint：`golangci-lint run`

## 代码约定
- API 响应格式：`{ "code": 0, "data": ..., "message": "ok" }`
- 错误用 `pkg/errors` 包装，不直接返回原始错误
- 所有公开 API 写 OpenAPI 注释

## 不要做的事
- 不修改 `.env` 文件
- 不在 handler 层写业务逻辑，调用 service
- 不引入未讨论的新依赖

@.claude/rules/api-conventions.md
```

**`.claude/rules/api-conventions.md`**（细分规则文件）

```markdown
# API 设计规范

## URL 约定
- 资源使用复数名词：`/users`、`/orders`
- 版本前缀：`/api/v1/`
- 禁止动词 URL（不用 `/getUser`，用 `GET /users/:id`）

## 分页
- 参数：`page`（从 1 起）、`page_size`（默认 20，最大 100）
- 响应包含 `total` 和 `items`

## 认证
- 除 `/health` 和 `/login` 外，所有接口需 JWT 认证
- Header：`Authorization: Bearer <token>`
```

---

## 5. settings.json — 核心配置

### 什么是 settings.json？

控制 Claude Code 行为的核心配置文件，包括：用哪个模型、有哪些权限、环境变量注入、Hooks 钩子等。

- **全局配置**：`~/.claude/settings.json`（对所有项目生效）
- **项目配置**：`.claude/settings.json`（可提交 Git 与他人共享）
- **私密配置**：`.claude/settings.local.json`（存放 API Key，不提交 Git）

### 5.1 模型选择

```json
{
  "model": "claude-sonnet-4-6"
}
```

| 别名 | 完整 ID | 特点 |
|------|---------|------|
| `sonnet` | `claude-sonnet-4-6` | 速度与质量平衡，日常首选 |
| `opus` | `claude-opus-4-6` | 最强推理，复杂任务用 |
| `haiku` | `claude-haiku-4-5-20251001` | 最快最省，简单任务用 |

### 5.2 权限配置

权限控制 Claude 能执行哪些操作。格式为 `工具名(模式)`，支持 `*` 通配符。

```json
{
  "permissions": {
    "allow": [
      "Bash(git status)",
      "Bash(git diff*)",
      "Bash(git log*)",
      "Bash(npm run lint)",
      "Bash(npm run test*)",
      "Bash(go test*)",
      "Bash(make *)"
    ],
    "ask": [
      "Bash(git commit*)",
      "Bash(git push*)"
    ],
    "deny": [
      "Read(./.env)",
      "Read(./.env.*)",
      "Read(./secrets/**)",
      "Bash(rm -rf*)"
    ],
    "defaultMode": "acceptEdits"
  }
}
```

**常用工具名**：`Read`、`Write`、`Edit`、`Bash`、`Glob`、`Grep`、`WebFetch`、`WebSearch`

**`defaultMode` 选项**：
- `"acceptEdits"`：自动接受文件读写，对未授权 Bash 命令才询问（推荐）
- `"askEdits"`：文件编辑也需要确认（更谨慎）

**规则执行顺序**：`deny` > `ask` > `allow`，即 deny 最优先。

### 5.3 完整个人配置示例

**`~/.claude/settings.json`**（全局，适用所有项目）

```json
{
  "model": "claude-sonnet-4-6",
  "language": "zh-CN",
  "autoUpdatesChannel": "stable",
  "permissions": {
    "allow": [
      "Read", "Glob", "Grep",
      "Bash(git *)",
      "Bash(npm *)",
      "Bash(pnpm *)",
      "Bash(bun *)",
      "Bash(go *)",
      "Bash(python3 *)",
      "Bash(make *)",
      "Bash(ls *)",
      "Bash(cat *)",
      "Bash(mkdir *)"
    ],
    "deny": [
      "Read(./.env)",
      "Read(./.env.*)"
    ],
    "defaultMode": "acceptEdits"
  },
  "env": {
    "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC": "1"
  }
}
```

**`~/.claude/settings.local.json`**（全局私密，含 API Key）

```json
{
  "env": {
    "ANTHROPIC_API_KEY": "sk-ant-xxxxx"
  }
}
```

---

## 6. Skills — 自定义技能

### 什么是 Skill？

Skill（技能）是用 Markdown 写的「工作流指南」，告诉 Claude 遇到特定任务时该怎么做。安装后，Claude 会在合适时机自动使用它，或者你通过斜杠命令触发。

Skills 分两类：
- **自定义技能**：你自己写的 `.claude/skills/*.md` 文件，定义项目专属 SOP
- **插件技能**：通过插件市场安装的社区技能（见第 7 节 Plugins）

### 6.1 创建自定义技能

技能文件放在 `.claude/skills/`（项目级）或 `~/.claude/skills/`（全局），带 YAML frontmatter 的 Markdown 格式：

```bash
mkdir -p .claude/skills
```

**示例：生产部署 SOP**

```markdown
name: deploy
description: 部署到生产环境，包含完整检查流程

# 生产部署流程

## 前置检查
1. `git status` — 确认无未提交更改
2. `npm run test` — 确认测试全部通过
3. `git branch --show-current` — 确认在 main 分支

## 部署
1. `npm run build` — 构建
2. `npm run db:migrate` — 数据库迁移
3. `npm run deploy:prod` — 部署

## 验证
- `curl https://api.example.com/health` — 检查健康状态

## 回滚
若出问题：`npm run deploy:rollback`
```

之后在会话中说"帮我部署"或输入 `/deploy`，Claude 会按这个流程执行。

**示例：React 组件创建规范**

```markdown
name: create-component
description: 按项目规范创建 React 组件（包含样式和测试文件）

# 创建 React 组件

## 确认信息
先问用户：
1. 组件名称（使用 PascalCase）
2. 是函数组件还是带状态的组件？
3. 需要哪些 props？

## 创建文件
在 `src/components/<ComponentName>/` 目录下创建：
1. `index.tsx` — 组件主文件
2. `styles.module.css` — 样式文件
3. `<ComponentName>.test.tsx` — 测试文件

## 代码规范
- 使用 TypeScript 强类型，所有 props 都要定义 interface
- 样式使用 CSS Modules
- 测试覆盖：渲染测试 + 核心交互测试

## 完成后
运行 `npm run test src/components/<ComponentName>` 确认测试通过
```

---

## 7. Plugins — 插件生态

### 什么是 Plugin？

Plugin（插件）是技能的**打包分发格式**。一个插件可以打包多个技能、子智能体定义、Hooks 钩子和 MCP 服务器配置，方便安装和跨项目复用。

**Skill vs Plugin 的区别**：

| | Skill | Plugin |
|---|---|---|
| 本质 | 单个 Markdown 工作流文件 | 打包了多个技能/智能体/Hooks 的完整扩展包 |
| 适合 | 项目专属 SOP、个人工作流 | 社区分发、跨项目复用 |
| 安装 | 手动创建文件 | `/plugin` 市场安装 |
| 技能命名 | `/skill-name` | `/<plugin>:skill-name` 或 `/skill-name` |

### 7.1 安装插件

**从官方市场安装**：

```text
/plugin
```

进入 **Discover** 标签，官方市场（`anthropics/claude-plugins-official`）已默认可用，选中插件回车安装。

**安装时选择作用域**：
- **User**（推荐）：安装到 `~/.claude/plugins/`，所有项目可用
- **Project**：安装到项目目录，跟随代码仓库

**添加第三方市场**（Superpowers 等热门插件）：

```text
/plugin marketplace add obra/superpowers-marketplace
```

其他格式：
```text
/plugin marketplace add https://github.com/company/plugins.git
/plugin marketplace add /path/to/local/marketplace
```

**管理已安装插件**：

```text
/plugin              ← 查看已安装插件
/reload-plugins      ← 安装/更新插件后刷新
```

**清除插件缓存**（安装异常时）：
```bash
rm -rf ~/.claude/plugins/cache
# 重启 Claude Code 并重新安装
```

### 7.2 精选插件推荐

#### 🦸 superpowers（必装）

**是什么**：一套强制工程化开发方法论。让 Claude 不再"想到什么写什么"，而是先分析、再规划、再 TDD 实现、最后验证——就像一个靠谱的高级工程师那样工作。

**安装**：
```text
/plugin marketplace add obra/superpowers-marketplace
```
然后 `/plugin` → Discover → 安装 `superpowers`。

**核心技能及使用方式**：

| 技能 | 何时触发 | 实际效果 |
|------|---------|---------|
| `brainstorming` | 开始新功能前 | 引导你明确需求、设计方案，而不是立即写代码 |
| `writing-plans` | 说"帮我实现 X" | 先产出分步计划让你确认，再动手实现 |
| `test-driven-development` | 实现功能/修 Bug | 强制先写失败测试，再写实现，再重构 |
| `systematic-debugging` | 遇到 Bug | 禁止猜测式修复，强制找根因、分析、验证 |
| `verification-before-completion` | 说"完成了" | 强制运行测试和检查，不允许仅凭"感觉"说完成 |
| `code-reviewer` | 完成一段代码后 | 从安全、质量、可维护性多维度审查 |

**使用示例**：

```text
你：帮我给用户系统加一个邮箱验证功能

（Superpowers 自动触发 brainstorming）

Claude：在开始实现之前，让我理解清楚需求...
- 验证流程是怎样的？发邮件还是即时验证？
- Token 有效期多长？
- 验证失败后能重发吗？
...（引导你想清楚边界条件）

你：确认了，开始吧

（Superpowers 触发 writing-plans）

Claude：好的，这是实现计划：
步骤 1：在 users 表添加 email_verified 字段...
步骤 2：创建 email_tokens 表...
...（让你确认后才开始写代码）
```

#### 🗂️ planning-with-files

**是什么**：Manus 风格的持久化规划。将任务分解和进度写入项目文件，即使会话中断也能无缝续接。

**安装**：官方市场直接搜索安装。

**使用方式**：

```text
/planning-with-files:plan      ← 开始任务规划
/planning-with-files:status    ← 随时查看当前在哪个阶段
```

Claude 会创建并维护：
```text
task_plan.md    ← 任务分解和阶段计划
findings.md     ← 调研结果和技术发现
progress.md     ← 当前执行进度
```

**适合场景**：重构、大型功能开发、任何需要多个会话才能完成的任务。

#### 🎨 frontend-design / ui-ux-pro-max

同为前端 UI 设计插件，二者侧重不同：

| | frontend-design | ui-ux-pro-max |
|---|---|---|
| 侧重 | 有设计感的组件实现 | 完整设计资产（161 色板 + 57 字体 + 25 图表） |
| 适合 | 日常前端开发 | 需要高完成度 UI 的场景 |

**安装**：官方市场安装。

**ui-ux-pro-max 使用示例**：

```text
你：帮我做一个 SaaS 产品的定价页面

（ui-ux-pro-max 触发设计思考）

Claude：在开始之前，让我了解设计方向：
- 产品面向哪类用户？技术开发者还是普通用户？
- 希望传达什么调性？专业可信 or 轻松易用？
- 竞品参考？想要与其区分还是对标？

（你回答后）

Claude：根据你的描述，我会采用...
```

#### 🧠 claude-mem

**是什么**：为 Claude 提供跨会话的持久记忆，基于 SQLite + 向量搜索。记住你的项目知识、技术偏好、过往决策，新会话开始时自动检索相关记忆注入上下文。

**安装**：官方市场安装。

**技能列表**：

| 技能 | 用途 | 使用方式 |
|------|------|---------|
| `mem-search` | 搜索记忆库 | `/mem-search` 或自然语言"我们之前怎么处理 X" |
| `smart-explore` | 用 AST 高效分析代码结构 | `/smart-explore` |
| `make-plan` | 带文档发现的实施计划 | `/make-plan` |
| `do` | 子智能体执行多步计划 | `/do` |

**使用示例**：

```text
你：记住我们决定用 JWT 而不是 Session，原因是要支持移动端

（claude-mem 自动存储这个决策）

（下个会话）

你：帮我实现用户登录

（claude-mem 自动检索，注入"用 JWT，支持移动端"的上下文）

Claude：好的，根据我们之前的决定，使用 JWT 方案...
```

#### 🔒 Trail of Bits 安全技能

**是什么**：安全公司 Trail of Bits 出品的代码安全审计技能集，包含静态分析（CodeQL/Semgrep）、密钥泄露检测、漏洞变体分析。

**安装**（Git 克隆方式）：
```bash
cd ~/.claude/skills
git clone https://github.com/trailofbits/claude-code-config
```

**适合场景**：开源项目、金融/安全类产品、上线前安全检查。

#### 📄 code-review

**是什么**：专业代码审查技能，针对当前代码变更进行系统审查，检查安全问题、代码质量和潜在缺陷。

**安装**：官方市场安装。

**使用**：
```text
/code-review:code-review
```

#### ✏️ simplify

**是什么**：检查刚写完的代码，找出可以简化、复用、优化的地方，防止过度工程化。

**安装**：官方市场安装。

**使用**：
```text
/simplify
```

#### 📝 claude-md-management

**是什么**：自动优化你的 CLAUDE.md，确保写得清晰有效，让 Claude 更好地理解你的项目。

**安装**：官方市场安装。

**使用**：
```text
/claude-md-management:revise-claude-md     ← 根据本次会话的经验更新 CLAUDE.md
/claude-md-management:claude-md-improver   ← 全面审计和改进 CLAUDE.md
```

#### 🤖 claude-api

**是什么**：使用 Anthropic SDK 开发 Claude 应用时的专用辅助，了解如何正确调用 API、处理流式响应、工具调用等。

**安装**：官方市场安装。

**触发**：在项目中导入 `anthropic` 或 `@anthropic-ai/sdk` 时自动激活。

### 7.3 开发自己的插件

如果你有一套适合多个项目的工具集，可以打包成插件分享：

```text
my-plugin/
├── .claude-plugin/
│   └── plugin.json        ← 插件元数据（可选，不写会自动发现）
├── skills/
│   ├── my-workflow.md     ← 你的技能
│   └── my-deploy.md
├── agents/
│   └── my-reviewer.md     ← 子智能体
└── README.md
```

**`.claude-plugin/plugin.json`**（可选）：

```json
{
  "name": "my-plugin",
  "version": "1.0.0",
  "description": "我的个人工具集"
}
```

---

## 8. Hooks — 自动化钩子

### 什么是 Hook？

Hook（钩子）是在特定事件发生时**自动触发**的脚本或操作，不依赖 Claude 的判断，**百分之百执行**。

典型用途：
- 每次保存文件后自动格式化（`PostToolUse`）
- 每次运行 Bash 命令前自动安全检查（`PreToolUse`）
- Claude 回复结束后自动发通知（`Stop`）

> ⚠️ Hooks 配置在 `settings.json` 的 `"hooks"` 字段中，**不是**独立脚本文件被自动发现。

### 8.1 配置结构

```json
{
  "hooks": {
    "事件名": [
      {
        "matcher": "工具名正则（可选）",
        "hooks": [
          {
            "type": "command",
            "command": "要执行的 Shell 命令"
          }
        ]
      }
    ]
  }
}
```

> ✅ 注意层级：外层数组元素有 `matcher` 和 `hooks`，内层 `hooks` 数组才是具体处理器。

### 8.2 常用事件

| 事件 | 触发时机 | 支持 Matcher |
|------|---------|------------|
| `PreToolUse` | 工具调用前 | ✅ 工具名正则 |
| `PostToolUse` | 工具调用成功后 | ✅ |
| `PostToolUseFailure` | 工具调用失败后 | ✅ |
| `UserPromptSubmit` | 你发消息前 | ❌ |
| `Stop` | Claude 完成一轮回复 | ❌ |
| `SessionStart` | 会话启动 | ✅ 启动方式 |
| `SessionEnd` | 会话结束 | ✅ 退出原因 |

完整事件列表（22 个）：`SessionStart`、`InstructionsLoaded`、`UserPromptSubmit`、`PreToolUse`、`PermissionRequest`、`PostToolUse`、`PostToolUseFailure`、`Notification`、`SubagentStart`、`SubagentStop`、`Stop`、`StopFailure`、`TeammateIdle`、`TaskCompleted`、`ConfigChange`、`WorktreeCreate`、`WorktreeRemove`、`PreCompact`、`PostCompact`、`SessionEnd`、`Elicitation`、`ElicitationResult`

### 8.3 Hook 类型

| 类型 | 说明 |
|------|------|
| `command` | 执行 Shell 命令，通过 stdin 读 JSON，stdout 写控制指令 |
| `http` | 发送 HTTP POST 请求（接入 Webhook、Slack 等） |
| `prompt` | 向 Claude 提问做判断（不带工具） |
| `agent` | 生成有工具权限的子智能体处理 |

### 8.4 command 钩子的输入输出

**stdin 接收的 JSON（部分字段）**：

```json
{
  "hook_event_name": "PreToolUse",
  "tool_name": "Bash",
  "tool_input": { "command": "rm -rf /tmp/*" },
  "cwd": "/home/user/project",
  "session_id": "xxx"
}
```

**stdout 可以返回**：

| 输出 | 效果 |
|------|------|
| `{}` 或空 | 继续正常执行 |
| `{"decision": "block", "reason": "原因"}` | 拦截这次操作 |
| `{"continue": false}` | 停止 Claude 继续 |
| `{"systemMessage": "消息"}` | 向 Claude 注入提示 |

> `PostToolUse` 钩子的 **stderr 输出**会反馈给 Claude 作为上下文。

> ⚠️ 钩子命令中**没有 `$file` 变量**，文件路径从 stdin JSON 中读取。

---

### 8.5 实用 Hooks 配置示例

**自动格式化：保存 Go/Python/TS 文件后自动 format**

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "python3 -c \"\nimport json,sys,subprocess\nd=json.load(sys.stdin)\nf=d.get('toolInput',{}).get('file_path','')\nif f.endswith('.go'):subprocess.run(['gofmt','-w',f])\nelif f.endswith('.py'):subprocess.run(['python3','-m','black',f])\nelif f.endswith(('.ts','.tsx','.js','.jsx')):subprocess.run(['npx','prettier','--write',f])\n\""
          }
        ]
      }
    ]
  }
}
```

**安全拦截：阻止危险命令**

先创建脚本 `.claude/hooks/guard.py`：

```python
#!/usr/bin/env python3
import json, sys

BLOCKED = ["rm -rf /", "rm -rf ~", "> /dev/sda", "mkfs.", "DROP DATABASE", ":(){:|:&};:"]

data = json.load(sys.stdin)
cmd = data.get("toolInput", {}).get("command", "")

for pat in BLOCKED:
    if pat.lower() in cmd.lower():
        json.dump({"decision": "block", "reason": f"检测到危险模式: {pat}"}, sys.stdout)
        sys.exit(0)

json.dump({}, sys.stdout)
```

再在 `settings.json` 中配置：

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "python3 .claude/hooks/guard.py"
          }
        ]
      }
    ]
  }
}
```

**会话开始时注入环境信息**

```json
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "echo '{\"systemMessage\": \"当前分支: '$(git branch --show-current 2>/dev/null || echo N/A)'\"}'"
          }
        ]
      }
    ]
  }
}
```

**Claude 完成后发送通知（macOS）**

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "osascript -e 'display notification \"Claude 完成了\" with title \"Claude Code\"'"
          }
        ]
      }
    ]
  }
}
```

---

## 9. Sub-agents — 多智能体

### 什么是 Sub-agent？

Sub-agent（子智能体）是拥有独立角色、权限和工具集的专用 Claude 实例。你可以定义多个专业化智能体，让它们各司其职——就像为不同工作聘请不同专家。

**一个完整的开发团队分工**：

```text
你的需求
  ├─→ architect（架构师）  → 设计技术方案，不写代码
  ├─→ developer（开发者）  → 实现代码
  ├─→ reviewer（审查员）   → 只读，检查安全和质量
  └─→ tester（测试员）    → 编写并运行测试
```

**三种触发方式**：

1. **自动**：Claude 根据 `description` 描述自动判断委派
2. **@提及**：在对话中 `@reviewer 帮我检查这段代码`
3. **CLI**：`claude --agent reviewer "review latest changes"`

### 9.1 定义子智能体

在 `.claude/agents/` 目录下创建 Markdown 文件，YAML frontmatter 是配置，正文是工作说明：

**Frontmatter 字段参考**：

| 字段 | 必填 | 说明 |
|------|------|------|
| `name` | ✅ | 唯一标识符（小写 + 连字符） |
| `description` | ✅ | 何时使用这个智能体（Claude 据此自动分配） |
| `model` | ❌ | 可指定不同模型（默认继承主对话模型） |
| `tools` | ❌ | 允许使用的工具白名单 |
| `disallowedTools` | ❌ | 禁用的工具黑名单 |
| `permissionMode` | ❌ | `default`/`acceptEdits`/`dontAsk`/`plan` |
| `maxTurns` | ❌ | 最大对话轮次 |
| `isolation` | ❌ | `worktree`：在独立 Git 工作树中运行 |

### 9.2 完整四智能体配置示例

**`.claude/agents/architect.md`**（架构师，只分析不写代码）

```markdown
name: architect
description: 技术架构师。当需要设计新功能方案、评估技术选型、拆解复杂需求、分析系统瓶颈时调用。在开始编码之前先咨询他。
model: claude-opus-4-6
tools:
  - Read
  - Glob
  - Grep
  - Bash(git log*)
  - Bash(git diff*)
disallowedTools:
  - Edit
  - Write
maxTurns: 20

# 技术架构师

你负责设计技术方案，**不直接写实现代码**。

## 工作流程
1. 充分理解需求和约束条件
2. 分析现有代码结构，找到关键依赖
3. 评估 2-3 种方案，分析各自利弊
4. 给出推荐方案，明确说明原因
5. 将任务拆解成可独立实现的子步骤

## 输出格式

### 方案对比
| 方案 | 优点 | 缺点 | 推荐 |
|------|------|------|------|
| 方案 A | ... | ... | ⭐ |

### 推荐方案
[详细说明]

### 实现步骤
1. 步骤一（负责人：developer）
2. 步骤二（负责人：developer）
...
```

**`.claude/agents/developer.md`**（开发者，实现代码）

```markdown
name: developer
description: 全栈开发工程师。当需要实现新功能、修复 Bug、重构代码时调用。接收 architect 的方案后负责编码实现。
model: claude-sonnet-4-6
tools:
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - Bash(git *)
  - Bash(go *)
  - Bash(npm *)
  - Bash(pnpm *)
  - Bash(make *)
permissionMode: acceptEdits
maxTurns: 50

# 开发工程师

## 工作原则
- 优先读懂现有代码，保持风格一致，再动手修改
- 每完成一个逻辑单元就用命令验证（编译/lint）
- 不引入未讨论的依赖
- 遇到模糊需求先确认，不自行假设

## 完成标准
- 代码可以编译/运行
- 核心逻辑有注释
- 没有留下 TODO（除非明确告知）
```

**`.claude/agents/reviewer.md`**（审查员，只读，用 opus 保证质量）

```markdown
name: reviewer
description: 代码审查专家。当用户完成功能实现、修复 Bug 或需要检查代码质量、安全问题时调用。
model: claude-opus-4-6
tools:
  - Read
  - Glob
  - Grep
  - Bash(git diff*)
  - Bash(git log*)
disallowedTools:
  - Edit
  - Write
maxTurns: 20

# 代码审查专家

你**只能读取代码，不能修改任何文件**。发现问题给出位置和建议，由 developer 负责修复。

## 审查维度

### 🔴 安全（必须报告）
- SQL 注入、XSS、命令注入
- 硬编码密钥或 Token
- 权限校验缺失、越权访问

### 🟡 正确性（必须报告）
- 逻辑错误、边界条件未处理
- 错误未被捕获或处理不当
- 并发竞态条件

### 🟠 质量（建议修复）
- 函数超过 50 行
- 重复代码（DRY 原则）
- 命名含糊、注释缺失

### 🔵 性能（可选）
- N+1 查询
- 不必要的重复计算

## 输出格式

```
### 🔴 安全问题
- `path/to/file.go:42` — [描述] → [建议]

### 🟡 正确性问题
- ...

### ✅ 总体评价
[一句总结 + 是否可以合并]
```
```

**`.claude/agents/tester.md`**（测试员，编写并运行测试）

```markdown
name: tester
description: 测试工程师。当需要为新功能编写测试、提升覆盖率、修复失败的测试，或验证 Bug 修复是否有效时调用。
model: claude-sonnet-4-6
tools:
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - Bash(go test*)
  - Bash(npm run test*)
  - Bash(pnpm test*)
  - Bash(pytest*)
  - Bash(npx vitest*)
maxTurns: 40

# 测试工程师

## 工作流程
1. 读取被测代码，理解公开接口和边界
2. 分析已有测试，保持风格一致
3. 设计测试矩阵：正常路径 / 边界条件 / 错误路径
4. 编写测试后立即运行，确认全部通过

## 覆盖要求
- 核心业务逻辑：100% 覆盖
- 错误处理路径：必须有用例
- 边界值（空值、零值、最大值）：必须覆盖

## 禁止
- 不写空的测试占位（`// TODO: add test`）
- 不用 mock 绕过真实逻辑（除非外部 IO）
- 测试必须能稳定运行，不允许随机失败
```

### 9.3 调用智能体

```bash
# CLI 直接指定智能体
claude --agent architect "分析一下如何给现有 REST API 加 WebSocket 支持"
claude --agent developer "实现 architect 设计的方案"
claude --agent reviewer "检查最新一次提交的代码"
claude --agent tester "为 UserService 生成完整测试"
```

```text
# 会话中 @ 提及
> @architect 我需要加一个用户通知系统，帮我设计方案
> @developer 按照上面的方案实现
> @reviewer 实现完了，帮我看看有没有问题
> @tester 写一下这个通知系统的测试

# 让 Claude 自动判断（description 写得准确时）
> 帮我检查这次修改有没有安全问题
# ← Claude 识别审查需求，自动调用 reviewer

# 会话中查看已配置的智能体
/agents
```

### 9.4 典型开发流程（四智能体协作）

```text
你：我要给订单系统加一个退款功能

1. Claude 自动（或 @architect）→ architect 设计方案
   └─ 输出：数据库变更 + API 设计 + 实现步骤

2. 你确认方案，说"开始实现"
   → @developer 按方案实现退款逻辑

3. 实现完成后
   → @reviewer 审查代码安全性和正确性
   → @tester 为退款功能编写完整测试

4. reviewer 发现问题 → @developer 修复
   tester 测试全绿 → 可以提交 PR
```

配合 Superpowers 的 `dispatching-parallel-agents` 技能，reviewer 和 tester 可以**并行执行**，节省时间。

---

## 10. MCP — 外部工具接入

### 什么是 MCP？

MCP（Model Context Protocol）是一个开放协议，让 Claude 能够连接和调用外部工具：数据库、API、文件系统、监控系统……任何可以提供接口的服务都能接入。

**没有 MCP 时**：Claude 只能读写你项目里的文件和执行命令。

**有了 MCP 后**：Claude 可以直接查询你的数据库、搜索你的 GitHub 仓库、调用你的内部 API。

### 10.1 配置文件

| 文件 | 范围 | 提交 Git |
|------|------|---------|
| `<project>/.mcp.json` | 项目级 | ✅ 可以 |
| `~/.claude.json` | 用户个人级 | ❌ |

> ⚠️ MCP 配置在独立的 `.mcp.json` 文件中，**不在** `settings.json` 里。

`.mcp.json` 支持 `${VAR}` 和 `${VAR:-默认值}` 引用环境变量，**不要把 Key 硬编码进文件**：

```json
{
  "mcpServers": {
    "github": {
      "type": "http",
      "url": "https://api.githubcopilot.com/mcp/",
      "headers": {
        "Authorization": "Bearer ${GITHUB_TOKEN}"
      }
    }
  }
}
```

### 10.2 传输协议

| 协议 | 状态 | 用于 |
|------|------|------|
| `http` | ✅ 推荐 | 远程服务、云端 MCP Server |
| `stdio` | ✅ 活跃 | 本地进程（npx 启动） |
| `sse` | ⚠️ 已废弃 | 请迁移到 http |

### 10.3 CLI 命令

```bash
# 添加 HTTP MCP Server
claude mcp add --transport http my-server https://mcp.example.com

# 添加本地 stdio MCP Server（--scope project 写入 .mcp.json）
claude mcp add --transport stdio --scope project sqlite -- \
  npx -y @anthropic-ai/mcp-server-sqlite ./data/local.db

# 从已有 Claude Desktop 配置导入
claude mcp add-from-claude-desktop

# 管理
claude mcp list
claude mcp get my-server
claude mcp remove my-server

# 查看可用工具
/mcp
```

### 10.4 常用 MCP Server 配置

**`.mcp.json` 完整示例**：

```json
{
  "mcpServers": {
    "filesystem": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "@anthropic-ai/mcp-server-filesystem", "."]
    },
    "github": {
      "type": "http",
      "url": "https://api.githubcopilot.com/mcp/",
      "headers": {
        "Authorization": "Bearer ${GITHUB_TOKEN}"
      }
    },
    "postgres": {
      "type": "stdio",
      "command": "npx",
      "args": [
        "-y", "@anthropic-ai/mcp-server-postgres",
        "${DATABASE_URL:-postgresql://localhost:5432/mydb}"
      ]
    },
    "fetch": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "@anthropic-ai/mcp-server-fetch"]
    },
    "sqlite": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "@anthropic-ai/mcp-server-sqlite", "./data/db.sqlite"]
    }
  }
}
```

**官方可用的 MCP Server**：

| 包名 | 功能 | 典型用法 |
|------|------|---------|
| `@anthropic-ai/mcp-server-filesystem` | 受控文件系统 | 访问项目目录以外的文件 |
| `@anthropic-ai/mcp-server-github` | GitHub 操作 | 搜索代码、读 PR、查 Issue |
| `@anthropic-ai/mcp-server-postgres` | PostgreSQL | 直接查询数据库 |
| `@anthropic-ai/mcp-server-sqlite` | SQLite | 本地数据库分析 |
| `@anthropic-ai/mcp-server-fetch` | HTTP 请求 | 访问外部 API |

### 10.5 自建 MCP Server（Python 示例）

将你自己的工具包装成 MCP Server，让 Claude 直接调用。先安装依赖：

```bash
pip install mcp
```

```python
# mcp/server.py — 将本地工具暴露给 Claude
from mcp.server.fastmcp import FastMCP

mcp = FastMCP("my-tools")

@mcp.tool()
def query_logs(keyword: str, lines: int = 100) -> str:
    """查询应用日志，支持关键词过滤。

    Args:
        keyword: 过滤关键词
        lines: 返回最多多少行，默认 100
    """
    import subprocess
    result = subprocess.run(
        ["grep", "-n", keyword, "/var/log/app.log"],
        capture_output=True, text=True
    )
    output = result.stdout.splitlines()
    return "\n".join(output[-lines:]) if output else "没有找到匹配的日志"

if __name__ == "__main__":
    mcp.run()
```

**注册**：

```json
{
  "mcpServers": {
    "my-tools": {
      "type": "stdio",
      "command": "python3",
      "args": ["mcp/server.py"]
    }
  }
}
```

之后在对话中：
```text
你：查一下最近的 ERROR 日志

Claude：我来查询... (调用 query_logs 工具)
```

---

## 11. VSCode 集成

### 11.1 安装

扩展 ID：**`anthropic.claude-code`**

在 VS Code 扩展市场搜索 "Claude Code"，安装 Anthropic 官方扩展（2M+ 安装量）。

### 11.2 工作原理

VS Code 扩展本质是本地 `claude` CLI 的图形界面，**共享同一套配置**：

```text
VS Code Claude 扩展
        ↓ 调用
本地 claude CLI
        ↓ 读取
~/.claude/settings.json  →  连接 API
.claude/settings.json    →  项目配置
CLAUDE.md                →  项目指令
```

在 CLI 里的设置、在 VS Code 里的设置，效果完全一样。

### 11.3 VS Code 专有设置

在 `.vscode/settings.json` 中配置（VS Code 扩展专属，不影响 CLI）：

```json
{
  "claudeCode.selectedModel": "claude-sonnet-4-6",
  "claudeCode.useTerminal": false,
  "claudeCode.initialPermissionMode": "acceptEdits",
  "claudeCode.preferredLocation": "panel",
  "claudeCode.autosave": true
}
```

| 设置 | 说明 |
|------|------|
| `selectedModel` | 新会话默认模型 |
| `useTerminal` | `false`：图形面板（默认）；`true`：终端模式 |
| `initialPermissionMode` | `acceptEdits`（推荐）或 `default` |
| `preferredLocation` | `panel` 或 `sidebar` |
| `autosave` | 编辑前自动保存文件 |

### 11.4 代理配置（三种方式）

> ⚠️ **已知问题**：部分版本的 VS Code 扩展不能读取 `~/.claude/settings.json` 中 `env` 字段的代理配置。以下方式更可靠。

**方式一：VS Code 环境变量（最可靠）**

在用户 VS Code 设置（`Cmd+,` → User Settings → 搜索 Claude Code）：

```json
{
  "claudeCode.disableLoginPrompt": true,
  "claudeCode.environmentVariables": [
    { "name": "ANTHROPIC_AUTH_TOKEN", "value": "Bearer sk-xxxxx" },
    { "name": "ANTHROPIC_BASE_URL",   "value": "https://your-proxy.com/v1" },
    { "name": "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC", "value": "1" }
  ]
}
```

> 💡 用 VS Code **User Settings**（而非 Workspace Settings），避免 Token 进入版本控制。

**方式二：从终端启动 VS Code（最简单）**

```bash
export ANTHROPIC_AUTH_TOKEN="Bearer sk-xxxxx"
export ANTHROPIC_BASE_URL="https://your-proxy.com/v1"
code .
```

**方式三：共享 settings.json（CLI 和 VS Code 都生效）**

```json
// ~/.claude/settings.json
{
  "env": {
    "ANTHROPIC_API_KEY": "sk-ant-xxxxx"
  }
}
```

### 11.5 常见问题

| 问题 | 解决方法 |
|------|---------|
| API 连接失败 | 运行 `claude doctor`；确认 Token 格式正确 |
| 代理不生效 | 改用 `claudeCode.environmentVariables` 配置 |
| 技能不出现 | `/reload-plugins`；或重启 VS Code |
| 模型列表为空 | 检查 API Key 是否有效 |

---

## 快速参考

### 最有价值的 Skills/Plugins

| 名称 | 安装途径 | 解决的核心问题 |
|------|---------|-------------|
| superpowers | `/plugin marketplace add obra/superpowers-marketplace` | Claude 直接写代码，不分析不规划 |
| planning-with-files | 官方市场 | 长任务会话中断、进度丢失 |
| ui-ux-pro-max | 官方市场 | AI 生成 UI 千篇一律 |
| claude-mem | 官方市场 | 每次都要重新介绍项目 |
| simplify | 官方市场 | 代码写完后的质量把关 |

### 常用斜杠命令

**会话管理**

| 命令 | 说明 |
|------|------|
| `/help` | 查看所有可用命令 |
| `/clear` | 清空当前对话 |
| `/compact` | 压缩上下文（对话变长时） |
| `/model` | 切换模型 |
| `/doctor` | 诊断配置和连接问题 |
| `/terminal-setup` | 配置 shell 集成，让 Claude 感知终端状态 |

**项目与记忆**

| 命令 | 说明 |
|------|------|
| `/init` | 在当前项目自动生成 CLAUDE.md |
| `/memory` | 查看已加载的 CLAUDE.md 和记忆文件 |

**代码与审查**

| 命令 | 说明 |
|------|------|
| `/review` | 对当前文件或 git diff 做代码审查（内置） |
| `/bug` | 上报 bug / 查看已知问题 |
| `/pr-comments` | 拉取并处理当前 PR 的 Review 评论 |

**插件与扩展**

| 命令 | 说明 |
|------|------|
| `/plugin` | 管理插件（安装、更新、查看） |
| `/reload-plugins` | 安装/更新插件后刷新 |
| `/agents` | 查看和管理子智能体 |
| `/mcp` | 查看已连接的 MCP 工具 |

### 常用 CLI 参数

```bash
claude                          # 启动交互会话
claude "帮我解释这段代码"        # 单次问答（非交互）
claude -p "问题"                 # 同上，--print 简写
claude --continue               # 续接上一个会话
claude --resume <session-id>    # 续接指定会话
claude --agent reviewer "..."   # 直接调用指定智能体
claude --model opus "..."       # 指定模型单次运行
claude mcp list                 # 查看 MCP 服务器
claude doctor                   # 诊断环境配置
```

---

## 参考资源

| 资源 | 链接 |
|------|------|
| 官方文档 | https://docs.anthropic.com/en/docs/claude-code |
| 快速入门 | https://docs.anthropic.com/en/docs/claude-code/quickstart |
| Settings 参考 | https://docs.anthropic.com/en/docs/claude-code/settings |
| Hooks 参考 | https://docs.anthropic.com/en/docs/claude-code/hooks |
| Sub-agents 文档 | https://docs.anthropic.com/en/docs/claude-code/sub-agents |
| MCP 配置 | https://docs.anthropic.com/en/docs/claude-code/mcp |
| 官方插件库 | https://github.com/anthropics/claude-plugins-official |
| awesome-claude-code | https://github.com/hesreallyhim/awesome-claude-code |

---

*2026-03-19 · 基于官方文档与社区实践编写*
