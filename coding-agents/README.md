# AI 编程助手 CLI 选型与全景指南（2026）

> Claude Code · OpenAI Codex CLI · Google Gemini CLI · OpenCode
>
> 基于基准测试数据、社区实践与用户实际体验的选型决策指南

---

## 文档体系

本文是三份详细文档的**选型导引与全景总览**，建议先读本文确定选择，再阅读对应工具的完整指南：

| 文档 | 说明 |
|------|------|
| **本文**（`ai-cli-guide-2026.md`） | 选型决策、横向对比、共性原理、混合工作流 |
| [`./claude-code.md`](./claude-code.md) | Claude Code 完整指南（安装→精通） |
| [`./codex.md`](./codex.md) | OpenAI Codex CLI 完整指南 |
| [`./gemini-cli.md`](./gemini-cli.md) | Google Gemini CLI 完整指南 |
| [`./opencode.md`](./opencode.md) | OpenCode 完整指南（开源·多模型·LSP）|

---

## 目录

1. [四工具核心定位](#1-四工具核心定位)
2. [Claude Code — 深度解析](#2-claude-code--深度解析)
3. [Codex CLI — 深度解析](#3-codex-cli--深度解析)
4. [Gemini CLI — 深度解析](#4-gemini-cli--深度解析)
5. [OpenCode — 深度解析](#5-opencode--深度解析)
6. [客观数据：基准测试](#6-客观数据基准测试)
7. [费用：真实成本分析](#7-费用真实成本分析)
8. [稳定性与成熟度](#8-稳定性与成熟度)
9. [选型决策指南](#9-选型决策指南)
10. [共性原理：四工具同构设计](#10-共性原理四工具同构设计)
11. [核心概念对照表](#11-核心概念对照表)
12. [横向深度对比](#12-横向深度对比)
13. [Open Agent Skills Standard](#13-open-agent-skills-standard)
14. [MCP — 通用工具接入协议](#14-mcp--通用工具接入协议)
15. [混合使用工作流](#15-混合使用工作流)
16. [快速速查表](#16-快速速查表)

---

## 1. 四工具核心定位

```
Claude Code  →  "质量优先"  —— 代码正确性最高，生态最丰富，复杂任务首选
Codex CLI    →  "安全高效"  —— 终端操作最强，OS 级沙盒，Token 效率最高
Gemini CLI   →  "免费开放"  —— 零成本入门，1M 上下文，多模态唯一选择
OpenCode     →  "开源自由"  —— 提供商无关，LSP 原生，本地模型，MIT 开源
```

**社区 2026 Power Stack**（Reddit 500+ 开发者调研最高票策略）：

> "Codex for keystrokes, Claude Code for commits."
>
> 日常编码用 Codex（快速省 Token），提交前用 Claude Code 把质量关。

四个工具共享 MCP 协议和 Open Agent Skills Standard，可无缝混合使用。

| 指标 | Claude Code | Codex CLI | Gemini CLI | OpenCode |
|------|------------|-----------|------------|----------|
| **开发商** | Anthropic | OpenAI | Google | SST 团队 |
| **底层模型** | Claude Sonnet 4.6 / Opus 4.6 | GPT-5.3-Codex / 5.4 | Gemini 2.5 Pro / Flash | 任意（20+ 提供商）|
| **实现语言** | TypeScript（闭源） | Rust（95.7%，Apache-2.0） | Node.js（Apache-2.0） | TypeScript（MIT）|
| **GitHub Stars** | ~80K | ~66K | ~98K | ~130K |
| **开源协议** | 闭源 | CLI 层 Apache-2.0 | Apache-2.0 | **MIT** |

---

## 2. Claude Code — 深度解析

> **定位**：代码正确性最高，扩展生态最成熟，复杂多文件任务首选

### 2.1 三大核心优势

**① 代码质量领先**

SWE-bench Verified（真实 GitHub Issue 自动修复）中，Opus 4.6 得分 **80.8%**，是当前所有工具最高公开成绩。在多文件复杂重构的盲测中胜率达 **67%**（Codex 18%，Gemini 15%）。

这个差距在任务复杂度提升时会被放大：涉及文件越多、跨层依赖越复杂，Claude Code 的优势越明显。

**② Agent Teams — 多智能体双向协作（独有）**

2026 年 2 月随 Opus 4.6 发布。与其他工具的子智能体（只能单向向父级汇报）不同，Agent Teams 中的智能体可以**互相直接通信、共享发现、挑战彼此的结论**。

- 最多 10 个并发子智能体，tmux 分面板实时可视化各智能体状态
- 内置文件锁机制防止并发写入冲突，自动解除依赖阻塞
- 标志性案例：16 个智能体协作完成了 10 万行 Rust C 编译器（能编译 Linux 内核）

**③ 最完整的扩展生态**

六层扩展体系，社区积累 9,000+ 扩展：

| 扩展层 | 说明 |
|--------|------|
| `CLAUDE.md` | 项目记忆与约定 |
| Skills | 可复用工作流 SOP |
| Sub-agents | 专职角色智能体 |
| Hooks | 22 种事件，四类处理器（Command / Prompt / Agent / HTTP） |
| Plugins | 官方市场 72+ 插件，社区 9,000+ |
| Agent Teams | 智能体双向协作网络 |

### 2.2 独有功能

| 功能 | 说明 |
|------|------|
| **四类 Hooks 处理器** | Command（确定性脚本）/ Prompt（语义判断）/ Agent（独立智能体深度分析）/ HTTP（远程调用外部服务） |
| **三层记忆系统** | user / project / local 三个作用域，跨会话持久化；输入 `#` 立即保存到记忆 |
| **Agent Teams 双向通信** | 子智能体可互相发消息、共享上下文，其他工具无此架构 |
| **Code Security** | 内置代码安全审查功能，独立于通用代码审查流程 |

### 2.3 适合场景

- 生产环境核心代码、关键模块重构（质量优先）
- 涉及 3+ 文件的复杂架构修改（多文件协调能力最强）
- 深度集成 CI/CD 自动化流水线（Hooks 生态最成熟）
- 长期项目（记忆系统让 AI 保持项目上下文，越用越准）

### 2.4 注意事项

- 无官方免费额度，Claude Pro $20/月 起步
- 闭源，代码不可审计
- Max 方案（$100-200/月）有用量上限，重度使用需提前评估

---

## 3. Codex CLI — 深度解析

> **定位**：终端任务表现最强，OS 级沙盒最可靠，Token 效率最高，DevOps 首选

### 3.1 三大核心优势

**① OS 级原生沙盒（安全性最强）**

Codex 的沙盒是真正的系统级强制隔离，而非依赖 AI 配合的权限提示：

- **Linux**：使用 `bubblewrap`，在内核 namespace 层面隔离，AI 物理上无法访问受限资源
- **macOS**：使用 Apple 官方 Seatbelt（`sandbox-exec`），内核级沙盒

即使 AI 被提示词注入攻击控制，也无法突破系统级限制。对金融、医疗等有强安全合规要求的场景，这是决定性优势。

**② 终端任务最强（Terminal-Bench 77.3%）**

Terminal-Bench 2.0 得分 **77.3%**，领先其他工具约 10 个百分点。响应速度 240+ tokens/s（Claude Opus 的 2.5 倍），同等任务 Token 消耗约为 Claude Code 的 1/4。

在以下任务上优势明显：Shell 脚本、CI/CD 配置、IaC、系统管理操作。

**③ 云端异步 Automations（独有）**

其他工具没有的能力：

- `codex cloud exec`：提交任务后关闭终端，稍后取回结果；`--attempts 1-4` 支持 best-of-N 运行
- **云端触发器**（开发中）：GitHub push 自动触发、定时任务、告警响应——将 Codex 从 CLI 工具升级为 SaaS 级 DevOps 智能体

### 3.2 独有功能

| 功能 | 说明 |
|------|------|
| **OS 级原生沙盒** | Linux bubblewrap + macOS Seatbelt，内核级强制隔离 |
| **Codex Desktop App** | macOS + Windows 桌面应用，多智能体任务可视化管理 |
| **Automations 云端触发** | 无人值守自动运行，处理 issue 分类、告警响应、CI 例行任务 |
| **`spawn_agent` 原语** | 底层智能体生命周期管理（spawn / wait / send_input），精确控制并发 |
| **JetBrains 全系原生** | 唯一原生支持 IntelliJ / PyCharm / WebStorm / Rider / GoLand |
| **TOML 配置** | 支持注释，类型安全，配置可读性高于 JSON |

### 3.3 适合场景

- DevOps / 基础设施工程师（终端任务日常，Token 消耗敏感）
- 安全合规严格的组织（金融、医疗，需要可验证的沙盒隔离）
- 已有 ChatGPT Plus 订阅的用户（Codex CLI 本质上附带在内）
- JetBrains IDE 用户（唯一原生支持）
- 需要云端异步批量处理的场景

### 3.4 注意事项

- Hooks 仍为实验性，仅 2 种事件（SessionStart / Stop），不适合复杂自动化
- Apps 生态刚起步（v0.113+），远不如 Claude Code 成熟
- 多智能体为单向汇报架构，子智能体无法互相协调
- MCP 支持有限，不如 Claude Code 和 Gemini CLI 完整

---

## 4. Gemini CLI — 深度解析

> **定位**：唯一免费入门，超长上下文，原生多模态，Apache-2.0 完全开源

### 4.1 三大核心优势

**① 真正可用的免费额度**

唯一不需要信用卡的主流 AI CLI 工具：**1,000 请求/天，60 请求/分钟**，个人 Google 账号即可。

**需要了解的真实情况**：免费层使用的是 Flash 模型（非 Pro），上下文窗口限制 32K，连续深度推理后可能降级。需要 Gemini 2.5 Pro 完整能力，需订阅 Gemini Advanced（$20/月）。

**② 1M Token 超长上下文**

付费用户可用 **100 万 token 上下文窗口**，约等于 50,000 行代码，是竞品的 5-10 倍。

这在以下场景是决定性优势：
- 理解大型遗留代码库全貌
- 跨越数十个文件的架构分析和重构规划
- 需要 AI 在同一上下文内"看到"完整项目

**③ 原生多模态**

三个工具中唯一支持将**图片、PDF、音频、视频**直接作为 CLI 输入的工具。典型场景：Figma 截图 → 组件规范提取 → 代码实现；API 文档 PDF → 客户端代码生成。

### 4.2 独有功能

| 功能 | 说明 |
|------|------|
| **原生多模态** | 图片 / PDF / 音频 / 视频直接输入，258 tokens/图 |
| **1M Token 上下文** | 付费专享，竞品最高约 200K |
| **Policy Engine** | Admin > User > Workspace > Default 四级优先级（0-999 精度），精细控制每个工具调用的 allow / deny / ask 行为 |
| **4 种沙盒实现** | macOS Seatbelt / Docker / Podman / gVisor（runsc）/ LXC，灵活适配不同部署环境 |
| **Extensions Gallery** | 100+ 扩展可浏览市场，含 GitHub / Redis / DynaTrace 等官方扩展，一键安装 |
| **Apache-2.0 完全开源** | 代码可审计、可自托管、可定制 |

### 4.3 适合场景

- 零预算学生和个人开发者（免费额度）
- 超大代码库的理解和分析（1M token 上下文）
- 多模态工作流：设计稿转代码、PDF 文档解析
- 对开源可审计有要求的组织（Apache 2.0）
- 安全策略复杂的场景（4 种沙盒 + Policy Engine 组合）

### 4.4 注意事项

- 复杂多文件任务代码质量落后于 Claude Code（SWE-bench ~71% vs 80.8%）
- 免费层是 Flash + 32K，与宣传的"Pro + 1M"有差距
- 多智能体（`/agents`）仍为实验性，不建议在关键流程中使用
- 迭代最快，breaking change 频率较高，稳定性低于前两者
- Deep Think 推理模式锁在 Ultra 订阅（$249.99/月），且尚未集成到 CLI

---

## 5. OpenCode — 深度解析

> **定位**：提供商无关，LSP 原生支持，MIT 完全开源，支持本地模型，Client/Server 架构

### 5.1 三大核心优势

**① 提供商无关——真正的模型自由**

OpenCode 支持 20+ AI 提供商，包括 Anthropic、OpenAI、Google、AWS Bedrock、Ollama（本地）、DeepSeek、Groq 等。不被任何单一厂商锁定，可随时切换最优模型。

团队还维护 **OpenCode Zen** 网关：持续对各提供商模型做基准测试，按量计费，仅透传信用卡手续费（4.4% + $0.30/笔），不额外加价。

**② LSP 原生支持（独有）**

三个主流工具（Claude Code / Codex / Gemini CLI）的 AI 只能看到文件文本；OpenCode 内置 LSP 客户端，AI 能感知：

- 类型错误和编译诊断（实时）
- 函数/变量定义位置（跨文件跳转）
- 引用关系（谁调用了这个函数）
- 符号类型和函数签名

在强类型语言（Go / TypeScript / Rust）项目中，这使 AI 修复 Bug 时能追踪调用链、验证类型正确性，显著减少"看起来对但编译报错"的情况。

**③ Client/Server 架构（独有）**

OpenCode 的计算端（Server）和界面端（Client）分离，支持：
- Server 跑在远程机器，本地 TUI 连接操作
- 移动端（iOS/Android）连接桌面 Server 远程控制
- 团队共享一个 Server 实例

### 5.2 独有功能

| 功能 | 说明 |
|------|------|
| **LSP 原生支持** | AI 感知类型/定义/引用，强类型项目代码质量更高 |
| **本地模型（Ollama/LMStudio）** | 完全离线，数据不离开本机 |
| **OpenCode Zen 网关** | 团队精选最优模型，按量计费不加价 |
| **Client/Server 分离** | 远程 Server + 移动端接入 |
| **Desktop App** | macOS / Windows / Linux 桌面应用 |
| **MIT 完全开源** | 代码可审计、可自托管、可定制 |
| **内置三 Agent** | build（默认）/ plan（只读）/ general（搜索）|

### 5.3 适合场景

- 不想被单一 AI 提供商锁定，需要灵活切换模型
- 本地模型场景（Ollama），数据隐私要求严格或离线开发
- 强类型语言项目（Go / TypeScript / Rust），需要 LSP 感知
- 已有 API Key，不想额外付订阅费
- 需要自托管或代码审计（MIT 开源）
- 需要移动端或多设备接入（Client/Server 架构）

### 5.4 注意事项

- 无公开 SWE-bench 成绩，代码质量依赖所选模型
- 插件生态刚起步，远不如 Claude Code 成熟
- v1.x 阶段，740+ 次发布说明迭代极快，偶有 breaking change
- Hooks 仅 6 种事件，少于 Claude Code（22 种）和 Gemini CLI（11 种）

---

## 6. 客观数据：基准测试

### 6.1 主要测试结果

| 基准测试 | 内容 | Claude Code (Opus 4.6) | Codex CLI | Gemini CLI | OpenCode |
|---------|------|----------------------|-----------|------------|----------|
| **SWE-bench Verified** | 真实 GitHub Issue 自动修复 | **80.8%** 🥇 | ~72% | ~71% | 未公开（依赖所选模型）|
| **Terminal-Bench 2.0** | 终端 / DevOps / Shell 任务 | ~68% | **77.3%** 🥇 | ~65% | 未公开 |
| **复杂多文件重构（盲测）** | 多轮盲测胜率 | **67%** 🥇 | 18% | 15% | 未公开 |
| **上下文窗口** | 最大可用 token 数 | ~200K | ~192K | **1M**（付费）🥇 | 取决于所选模型 |
| **响应速率** | tokens/s | ~100 | **240+** 🥇 | ~120 | 取决于所选模型 |
| **安全漏洞生成率** | PR 中含漏洞概率 | 87% ⚠️ | 87% ⚠️ | 87% ⚠️ | 87% ⚠️ |

> **安全警告（四工具通用）**：研究表明，所有 AI 工具生成的代码中 87% 的 PR 包含至少一处安全漏洞（SQL 注入、认证缺陷、硬编码密钥等）。**无论使用哪个工具，AI 生成的代码都必须经过安全审查，不能直接上线。**

### 6.2 任务类型适配矩阵

| 任务类型 | 最佳工具 | 原因 |
|---------|---------|------|
| 复杂 Bug 修复 / 多文件重构 | **Claude Code** | SWE-bench 80.8%，盲测胜率 67% |
| Shell 脚本 / CI 配置 / DevOps | **Codex CLI** | Terminal-Bench 77.3%，Token 效率最高 |
| 图片 / PDF / 多模态输入 | **Gemini CLI** | 其他工具不支持 |
| 超大代码库全局分析 | **Gemini CLI** | 1M token，竞品的 5-10 倍 |
| 并行批量任务 | **Codex CLI** | 原生 `spawn_agent`，云端 Automations |
| 零预算原型开发 | **Gemini CLI** | 每天 1000 次免费（Flash 模型）|
| CI/CD Hooks 深度集成 | **Claude Code** | 22 种事件，四类处理器，生态最成熟 |
| 安全合规场景 | **Codex CLI** | OS 内核级沙盒，可验证强制隔离 |
| JetBrains IDE 用户 | **Codex CLI** | 唯一原生支持 |
| 长期项目跨会话记忆 | **Claude Code** | 三层记忆系统，上下文持久化 |

---

## 7. 费用：真实成本分析

### 7.1 订阅套餐对比

| 套餐 | 月费 | 实际可用能力 | 备注 |
|------|------|------------|------|
| **Gemini CLI（免费）** | $0 | Flash 模型，32K 上下文 | 1000 次/天，无需绑卡 |
| **Claude Pro** | $20 | Claude Sonnet 4.6，SWE-bench ~79% | 个人入门首选 |
| **ChatGPT Plus** | $20 | Codex CLI 完整能力 | GPT-5.3-Codex 接入 |
| **Gemini Advanced** | $20 | Gemini 2.5 Pro + 1M 上下文 | Flash → Pro 升级 |
| **Claude Max** | $100 | Opus 4.6，5x 用量上限 | 重度用户方案 |
| **ChatGPT Pro** | $200 | 含 o3 推理模型 | 高端用户方案 |

### 7.2 社区性价比共识

**方案 A：双订阅（$40/月）**——社区最高票推荐

```
Claude Pro ($20) + ChatGPT Plus ($20，包含 Codex CLI)
= 复杂代码任务用 Claude（质量最高）+ DevOps 终端任务用 Codex（效率最高）
```

两个工具能力互补而非重叠，$40 的双订阅覆盖面比 $100 Claude Max 更广。

**方案 B：免费入门（$0）**

```
Gemini CLI（Google 账号，Flash 模型，1000 次/天）
→ 学习阶段 / 小型项目 / 评估期
→ 需要 Pro 能力：$20/月 升级 Gemini Advanced
```

### 7.3 API Key 直连费用

| 模型 | 输入 | 输出 | 适用 |
|------|------|------|------|
| Claude Sonnet 4.6 | $3/MTok | $15/MTok | 日常任务主力 |
| Claude Opus 4.6 | $15/MTok | $75/MTok | 复杂任务按需 |
| GPT-5.3-Codex | $7.5/MTok | $30/MTok | Codex CLI API 直连 |
| Gemini 2.5 Pro | $1.25/MTok | $10/MTok | 长上下文最经济 |
| Gemini Flash | $0.075/MTok | $0.3/MTok | 高频简单任务 |

---

## 8. 稳定性与成熟度

### 8.1 稳定性排名

```
Claude Code  ██████████  最稳定 ── 破坏性变更少，生产环境可放心依赖
Codex CLI    ████████    较稳定 ── v0.100+ 后显著提升，Rust 架构稳固
Gemini CLI   ██████      迭代最快── 功能更新频率高，偶有 breaking change
OpenCode     █████       极速迭代── v1.x，740+ 次发布，最活跃，偶有 breaking change
```

### 8.2 关键功能成熟度

| 功能 | Claude Code | Codex CLI | Gemini CLI | OpenCode |
|------|------------|-----------|------------|----------|
| Hooks | ✅ 22 种，生产就绪 | ⚠️ 2 种，实验性 | ✅ 11 种，生产就绪 | ✅ 6 种，生产就绪 |
| 多智能体 | ✅ Agent Teams（双向通信） | ✅ 原生并行，生产就绪 | ⚠️ 实验性 | ✅ 自定义 Agent |
| 插件 / 扩展 | ✅ 9,000+ 生态成熟 | ⚠️ 新兴（v0.113+） | ✅ 100+ 稳定 | ⚠️ 新兴 |
| 云端异步 | ❌ | ✅ Codex Cloud | ❌ | ❌ |
| MCP | ✅ 完整 | ⚠️ 有限 | ✅ 完整 | ✅ 完整 |
| 沙盒 | ✅ 容器级 | ✅ OS 内核级（最强） | ✅ 4 种可选（最灵活） | ✅ Docker/容器 |
| 跨会话记忆 | ✅ 三层作用域 | ❌ | ❌ | ❌ |
| LSP 支持 | ❌ | ❌ | ❌ | ✅ 原生内置（唯一）|
| 本地模型 | ❌ | ❌ | ❌ | ✅ Ollama/LMStudio |

---

## 9. 选型决策指南

### 9.1 决策树

```
开始
 │
 ├─ 预算 = $0？
 │   └─ → Gemini CLI（Flash 免费 1000 次/天）
 │          需要 Pro 能力则 $20/月 升级 Advanced
 │
 ├─ 主力 IDE 是 JetBrains？
 │   └─ → Codex CLI（唯一原生支持）
 │
 ├─ 任务主要是 Shell / CI / DevOps / 基础设施？
 │   └─ → Codex CLI（Terminal-Bench 77.3%，Token 效率 4x）
 │
 ├─ 需要图片 / PDF / 音视频输入？
 │   └─ → Gemini CLI（其他工具不支持多模态）
 │
 ├─ 需要理解 10 万行以上代码库全貌？
 │   └─ → Gemini CLI（1M token，竞品 5-10 倍）
 │
 ├─ 安全合规要求高（金融 / 医疗 / 企业）？
 │   └─ → Codex CLI（OS 内核级沙盒，可向审计方验证）
 │
 ├─ 主要做复杂代码重构 / 多文件架构修改？
 │   └─ → Claude Code（SWE-bench 80.8%，盲测胜率 67%）
 │
 ├─ 需要深度 CI/CD Hooks 集成？
 │   ├─ 需要 15+ 种事件 / 语义判断 / HTTP 回调 → Claude Code
 │   └─ 11 种足够 → Gemini CLI
 │
 ├─ 不想被单一提供商锁定 / 需要本地模型？
 │   └─ → OpenCode（20+ 提供商，支持 Ollama 本地模型）
 │
 ├─ 强类型语言项目（Go / TypeScript / Rust），需要 LSP 感知？
 │   └─ → OpenCode（唯一原生 LSP 支持）
 │
 ├─ 对开源可审计 / 自托管有要求？
 │   ├─ MIT 完全开源 → OpenCode
 │   └─ Apache 2.0 → Gemini CLI
 │
 ├─ 需要云端异步任务 / 无人值守自动化？
 │   └─ → Codex CLI（Codex Cloud + Automations）
 │
 ├─ 重视长期项目的跨会话上下文？
 │   └─ → Claude Code（三层记忆系统）
 │
 └─ 综合体验，$20/月 → Claude Code
    最优性价比，$40/月 → Claude Pro + ChatGPT Plus 双订阅
    已有 API Key，不想付订阅 → OpenCode（Zen 按量不加价）
```

### 9.2 按用户类型推荐

| 用户类型 | 首选 | 次选 | 核心理由 |
|---------|------|------|---------|
| **学生 / 零预算** | Gemini CLI | OpenCode | Flash 免费，足够学习和小项目 |
| **JetBrains 用户** | Codex CLI | Claude Code | 唯一原生 IDE 深度集成 |
| **全栈独立开发者** | Claude Code | Codex CLI | SWE-bench 领先，生态最成熟 |
| **DevOps / 基础设施** | Codex CLI | Claude Code | Terminal-Bench 领先，OS 沙盒安全 |
| **多模态场景** | Gemini CLI | — | 图片 / PDF / 音频，其他工具做不到 |
| **大型遗留代码库** | Gemini CLI | Claude Code | 1M 上下文，其他工具容量不足 |
| **CI/CD 自动化重度用户** | Claude Code | Gemini CLI | 22 种 Hooks + 四类处理器 |
| **安全合规优先** | Codex CLI | — | OS 内核级沙盒，可验证强制限制 |
| **不想被厂商锁定** | OpenCode | — | 20+ 提供商，随时切换 |
| **本地模型 / 数据隐私** | OpenCode | — | Ollama/LMStudio，数据不出本机 |
| **强类型语言开发** | OpenCode | Claude Code | LSP 原生支持，AI 理解类型系统 |
| **开源 / 可审计** | OpenCode | Gemini CLI | MIT 完全开源，Apache 2.0 次选 |
| **预算充足追求最强** | Claude Code + Codex CLI | + Gemini / OpenCode 免费补充 | $40/月，两工具互补全覆盖 |

---

## 10. 共性原理：四工具同构设计

四个工具架构高度同构，**掌握一个再学另一个通常只需 1-2 天**。

### 10.1 项目记忆文件（Memory File）

每个工具在项目根目录读取一个 Markdown 文件，每次会话启动时自动加载，作为 AI 的持久化项目上下文。

```
CLAUDE.md    ← Claude Code
AGENTS.md    ← Codex CLI / OpenCode
GEMINI.md    ← Gemini CLI
```

**加载机制完全一致**：`~` 全局文件 → Git 根 → 当前目录，逐层叠加，子目录覆盖父目录。

**推荐模板**：

```markdown
# 项目名称

## 这是什么
一句话描述项目用途和规模。

## 技术栈
- Go 1.23 + Gin + GORM
- PostgreSQL 16
- React 19 + Vite + TailwindCSS

## 常用命令
- 启动：`make dev`
- 测试：`make test`
- 构建：`make build`

## 代码约定
- 错误处理：`fmt.Errorf("context: %w", err)` 包裹，不吞错误
- 命名：Go 风格驼峰，数据库字段蛇形命名
- 提交格式：`feat:` / `fix:` / `docs:` 前缀

## 禁止操作
- 不修改 .env 文件
- 不引入未讨论的新依赖
- 不删除数据库 migration 文件
```

### 10.2 Skills — 可复用工作流

将 SOP 写成 Markdown，AI 按步骤执行。四工具格式完全相同，详见第 13 节。

```
.claude/skills/   ← Claude Code
.agents/skills/   ← Codex CLI
.gemini/skills/   ← Gemini CLI
```

### 10.3 MCP — 外部工具接入

四工具完整支持 MCP（Model Context Protocol），一个 MCP 服务器同时被四个工具调用，详见第 14 节。

### 10.4 沙盒模式

```
完全只读  →  工作区写入  →  完全放开（⚠️ 仅隔离环境）
最保守                          最宽松
```

日常开发推荐"工作区写入"：可修改代码，默认禁止出站网络。

### 10.5 审批模式

| 模式 | Claude Code | Codex CLI | Gemini CLI |
|------|-------------|-----------|------------|
| 每步确认（默认） | `suggest` | `--approval-mode suggest` | `suggest` |
| 自动编辑，危险操作确认 | `auto-edit` | `--approval-mode on-failure` | `auto-edit` |
| 全自动 ⚠️ | `--dangerously-skip-permissions` | `--full-auto` | `--approval-mode yolo` |

### 10.6 非交互式 / CI 模式

```bash
# Claude Code
claude -p "审查本次 PR 的安全问题" --output-format json

# Codex CLI
codex exec "修复所有 lint 错误" --sandbox workspace-write --ask-for-approval never

# Gemini CLI
gemini -p "生成发布说明" --output-format json
```

---

## 11. 核心概念对照表

| 概念 | Claude Code | Codex CLI | Gemini CLI | OpenCode |
|------|-------------|-----------|------------|----------|
| **项目记忆文件** | `CLAUDE.md` | `AGENTS.md` | `GEMINI.md` | `AGENTS.md` |
| **全局记忆文件** | `~/.claude/CLAUDE.md` | `~/.codex/AGENTS.md` | `~/.gemini/GEMINI.md` | `~/.config/opencode/AGENTS.md` |
| **配置格式** | JSON | TOML | JSON | JSON |
| **全局配置** | `~/.claude/settings.json` | `~/.codex/config.toml` | `~/.gemini/settings.json` | `~/.config/opencode/config.json` |
| **项目配置** | `.claude/settings.json` | `.codex/config.toml` | `.gemini/settings.json` | `opencode.json` |
| **技能目录** | `.claude/skills/` | `.agents/skills/` | `.gemini/skills/` | `.opencode/skills/` |
| **插件 / 扩展** | Plugins（`/plugin install`） | Apps（`/apps`，v0.113+） | Extensions（`gemini-extension.json`） | npm 插件包 |
| **MCP 配置** | `.mcp.json` | `config.toml [mcp_servers]` | `settings.json mcpServers` | `opencode.json mcp` |
| **Hooks 配置** | `settings.json hooks` | `hooks.json`（实验性） | `settings.json hooks` | `opencode.json hooks` |
| **多智能体定义** | `.claude/agents/*.md` | `.codex/agents/*.toml` | `.gemini/agents/`（实验性） | `.opencode/agents/*.md` |
| **启动命令** | `claude` | `codex` | `gemini` | `opencode` |
| **非交互执行** | `claude -p "..."` | `codex exec "..."` | `gemini -p "..."` | `opencode run "..."` |
| **初始化记忆文件** | `/init` | `/init` | `/init` | `opencode onboard` |
| **上下文压缩** | `/compact` | `/compact` | `/compress` | `/compact` |
| **模式切换** | `Shift+Tab` | `Shift+Tab` | `Shift+Tab` | `Tab` |

---

## 12. 横向深度对比

### 11.1 配置格式对比

```toml
# TOML（Codex）— 支持注释，类型安全
model = "gpt-5.3-codex"
model_reasoning_effort = "medium"  # low / medium / high

[mcp_servers.github]
command = "npx"
args = ["-y", "@github/mcp-server"]
env = { GITHUB_TOKEN = "${GITHUB_TOKEN}" }
```

```json
{
  "model": "claude-sonnet-4-6",
  "mcpServers": {
    "github": {
      "command": "npx",
      "args": ["-y", "@github/mcp-server"],
      "env": { "GITHUB_TOKEN": "${GITHUB_TOKEN}" }
    }
  }
}
```

Claude Code 和 Gemini CLI 的 JSON 结构完全一致，仅文件路径不同。

### 11.2 Hooks 对比

| 工具 | 事件数量 | 成熟度 | 处理器类型 |
|------|---------|--------|-----------|
| **Claude Code** | **22 种** | ✅ 生产就绪 | Command / Prompt / Agent / HTTP |
| **Gemini CLI** | **11 种** | ✅ 生产就绪 | Command |
| **Codex CLI** | **2 种** | ⚠️ 实验性 | Command |

Claude Code Hooks 配置示例（PostToolUse — 写入后自动格式化）：

```json
{
  "hooks": {
    "PostToolUse": [{
      "matcher": "Write|Edit",
      "hooks": [{ "type": "command", "command": "gofmt -w \"$CLAUDE_TOOL_INPUT_PATH\"" }]
    }]
  }
}
```

Gemini CLI Hooks 配置示例（工具调用前记录审计日志）：

```json
{
  "hooksConfig": {
    "hooks": [{
      "name": "audit-log",
      "event": "BeforeTool",
      "command": "echo \"[$(date -u +%FT%TZ)] $GEMINI_TOOL_NAME\" >> ~/gemini-audit.log"
    }]
  }
}
```

### 11.3 多智能体架构对比

| 工具 | 通信架构 | 最大并发 | 特点 |
|------|---------|---------|------|
| **Claude Code** | 双向通信，智能体可互相协调 | 最多 10 个 | Agent Teams，tmux 分屏可视化 |
| **Codex CLI** | 单向汇报 | 无上限 | `spawn_agent` 原语，支持云端并行 |
| **Gemini CLI** | 单向汇报 | 有限 | 实验性，不建议生产使用 |

### 11.4 沙盒安全层级对比

| 工具 | 沙盒技术 | 隔离层级 |
|------|---------|---------|
| Claude Code | 容器级隔离 | 应用层 |
| **Codex CLI** | macOS Seatbelt / Linux bubblewrap | **OS 内核层**（最强） |
| Gemini CLI | OS 级 + Docker + Podman + gVisor + LXC | 4 种可选（最灵活） |

### 11.5 IDE 支持对比

| IDE | Claude Code | Codex CLI | Gemini CLI |
|-----|-------------|-----------|------------|
| VS Code | ✅ | ✅ | ✅ |
| Cursor / Windsurf | ✅（VS Code 扩展） | ✅ 原生 | ✅（VS Code 扩展） |
| **JetBrains 全系** | ❌ | ✅ **唯一原生** | ❌ |
| Zed | ❌ | ❌ | ✅ |
| Neovim | ✅（社区插件） | ❌ | ❌ |

---

## 13. Open Agent Skills Standard

由 Anthropic 提出并开放，已被 30+ AI 工具采用（Claude Code / Codex CLI / Gemini CLI / GitHub Copilot / Cursor / Amp 等）。

**核心价值**：一套 Skills 跨工具通用，零迁移成本。

### 标准格式

```
skill-name/
├── SKILL.md          ← 必须（name + description frontmatter）
├── scripts/          ← 可选
├── references/       ← 可选
└── assets/           ← 可选
```

```markdown
---
name: deploy
description: >
  部署代码到生产环境时使用。触发词：部署、上线、发版、release、deploy。
  不适用：测试环境部署（使用 deploy-staging 技能）。
---

# 生产部署流程

1. `git status` — 确认工作树干净
2. `make test` — 全量测试通过
3. `make deploy:prod` — 执行部署
4. 输出版本号和部署时间
```

### 三级渐进加载（节省 Token）

| 阶段 | 内容 | 开销 |
|------|------|------|
| Level 1 | 仅读 frontmatter（name + description） | ~100 tokens |
| Level 2 | 加载完整 SKILL.md | <5,000 tokens |
| Level 3 | 按需加载 scripts / references | 按需 |

AI 只在判断相关时才进入下一层，不影响常规对话的 Token 消耗。

### description 写法

```markdown
# 好 ✅ — 明确触发词和排除场景
description: >
  部署代码到生产环境。触发词：部署、上线、release、deploy。
  不适用：测试环境部署（使用 deploy-staging）。

# 差 ❌ — 太模糊，AI 难以精确匹配
description: 部署脚本
```

### 跨工具复用

```bash
# 全局路径，三工具均扫描
~/.agents/skills/my-skill/SKILL.md
```

---

## 14. MCP — 通用工具接入协议

MCP（Model Context Protocol）是独立于 AI 工具的开放协议，一个 MCP 服务器可同时被三个工具调用。

### 配置对比

**Claude Code**（`.mcp.json`）/ **Gemini CLI**（`settings.json`）：

```json
{
  "mcpServers": {
    "github": {
      "command": "npx",
      "args": ["-y", "@anthropic-ai/mcp-server-github"],
      "env": { "GITHUB_TOKEN": "${GITHUB_TOKEN}" }
    }
  }
}
```

**Codex CLI**（`config.toml`）：

```toml
[mcp_servers.github]
command = "npx"
args = ["-y", "@anthropic-ai/mcp-server-github"]
env = { GITHUB_TOKEN = "${GITHUB_TOKEN}" }
```

### 常用 MCP 服务器

| 包名 | 功能 | 适用场景 |
|------|------|---------|
| `@upstash/context7-mcp` | 实时查询框架最新文档 | 避免 AI 使用过时 API |
| `@anthropic-ai/mcp-server-github` | GitHub 操作 | PR 审查、Issue 管理 |
| `@anthropic-ai/mcp-server-postgres` | PostgreSQL 查询 | 数据库操作 |
| `@anthropic-ai/mcp-server-sqlite` | SQLite 本地库 | 本地数据分析 |
| `@anthropic-ai/mcp-server-fetch` | HTTP 请求 | 调用外部 API |
| Figma MCP | 读取 Figma 设计稿 | 设计 → 代码自动化 |

---

## 15. 混合使用工作流

### 工作流一：开发 + 安全审查

```bash
# Step 1：Claude Code 实现功能（SWE-bench 最强）
claude "根据 PRD 实现用户注册 API"

# Step 2：Codex CLI 安全审查（OS 级沙盒 + 只读，保证 AI 无法修改代码）
codex exec "审查刚才的代码变更，检查 SQL 注入、认证漏洞、敏感信息暴露" \
  --sandbox read-only \
  --ask-for-approval never

# Step 3：Claude Code 根据审查结果修复
claude "根据上述安全问题逐一修复"
```

### 工作流二：设计稿 → 代码

```bash
# Step 1：Gemini CLI 解析设计图（唯一支持多模态）
gemini -p "分析此 Figma 截图，提取组件结构、颜色值和间距规范" \
  --image design.png --output-format json > design-spec.json

# Step 2：Claude Code 实现代码
claude "根据 design-spec.json 用 React + Tailwind 实现此页面"
```

### 工作流三：大代码库分析 → 精准修改

```bash
# Step 1：Gemini CLI 全局分析（1M 上下文，能读入整个项目）
gemini -p "分析整个代码库，识别认证模块的设计问题和安全隐患" \
  --model gemini-2.5-pro > analysis.md

# Step 2：Claude Code 精准重构（SWE-bench 最强）
claude "参考 analysis.md 的分析，重构认证模块"
```

### 工作流四：Codex 并行多任务

```bash
# Codex 自动派遣多个并行 Worker
codex exec "对此次 PR 做全面审查，四项任务并行执行：
  1. 安全：OWASP Top 10
  2. 性能：N+1 查询、内存泄漏
  3. 测试覆盖：边界条件和错误路径
  4. 文档同步：API 注释和 README
输出综合报告"
```

### 工作流五：共享 Skills 四工具通用

```bash
mkdir -p ~/.agents/skills/code-review
cat > ~/.agents/skills/code-review/SKILL.md << 'EOF'
---
name: code-review
description: >
  全面审查代码变更。触发词：审查代码、code review、review、检查代码。
  不适用：只做格式检查（使用 lint 技能）。
---

# 代码审查流程

## 审查维度
1. **安全**：SQL 注入、XSS、认证漏洞、硬编码密钥
2. **性能**：N+1 查询、低效循环、内存泄漏
3. **可读性**：命名规范、函数职责单一、注释完整
4. **测试覆盖**：边界条件和错误路径是否有测试

## 输出格式
按严重程度：Critical / Warning / Suggestion，附文件名和行号
EOF

# 四个工具都能触发同一套审查流程
claude "帮我审查代码"
codex "review the latest changes"
gemini "检查代码"
opencode run "审查代码变更"
```

### 工作流六：OpenCode LSP 感知修复 + Claude Code 验证

适合强类型语言（Go / TypeScript / Rust）项目，利用 OpenCode 的 LSP 能力精准定位类型问题，Claude Code 把关代码质量：

```bash
# Step 1：OpenCode 利用 LSP 追踪类型错误（AI 能感知编译诊断和调用链）
opencode run "找出所有类型错误和编译警告，追踪根因，给出修复方案" \
  --agent plan  # 只读模式，先分析不改代码

# Step 2：OpenCode 执行修复（LSP 验证修复后类型正确）
opencode run "按照上述方案修复所有类型错误，修复后确认编译通过"

# Step 3：Claude Code 全面审查（SWE-bench 最强，质量把关）
claude "审查刚才的修改，确认逻辑正确性和边界条件处理"
```

### 工作流七：本地模型原型 → 云端模型精修

用 OpenCode + 本地 Ollama 做快速原型（零成本、数据不出本机），满意后切换到 Claude Code 精修：

```bash
# Step 1：OpenCode + 本地 Ollama 快速原型（免费，数据不离开本机）
export OLLAMA_BASE_URL=http://localhost:11434
opencode run "根据需求快速实现用户认证模块原型" \
  --model ollama/qwen2.5-coder:32b

# Step 2：原型满意后，Claude Code 精修（SWE-bench 80.8%，代码质量最高）
claude "审查并精化刚才的认证模块，提升代码质量、补充错误处理和测试"
```

---

## 16. 快速速查表

### 安装

| 工具 | npm | Homebrew | 其他 |
|------|-----|---------|------|
| Claude Code | `npm i -g @anthropic-ai/claude-code` | — | — |
| Codex CLI | `npm i -g @openai/codex` | `brew install --cask codex` | — |
| Gemini CLI | `npm i -g @google/gemini-cli` | — | — |
| OpenCode | `npm i -g opencode-ai` | `brew install sst/tap/opencode` | `curl -fsSL https://opencode.ai/install | bash` |

### 常用命令

| 操作 | Claude Code | Codex CLI | Gemini CLI | OpenCode |
|------|-------------|-----------|------------|----------|
| 启动交互 | `claude` | `codex` | `gemini` | `opencode` |
| 单次任务 | `claude -p "..."` | `codex "..."` | `gemini -p "..."` | `opencode run "..."` |
| CI 执行 | `claude -p "..." --output-format json` | `codex exec "..."` | `gemini -p "..." --output-format json` | `opencode run "..." --output-format json` |
| 恢复会话 | `claude --continue` | `codex resume --last` | `gemini --resume` | TUI 内 `/sessions` |
| 指定模型 | `claude --model claude-opus-4-6` | `codex --model gpt-5.3-codex` | `gemini -m gemini-2.5-pro` | `opencode --model anthropic/claude-opus-4-6` |
| 全自动 ⚠️ | `claude --dangerously-skip-permissions` | `codex --full-auto` | `gemini --approval-mode yolo` | `--mode auto` |

### 会话内命令

| 功能 | Claude Code | Codex CLI | Gemini CLI | OpenCode |
|------|-------------|-----------|------------|----------|
| 初始化记忆文件 | `/init` | `/init` | `/init` | — |
| 压缩上下文 | `/compact` | `/compact` | `/compress` | `/compact` |
| 查看技能列表 | `/skills` | `/skills` | `/skills` | — |
| 查看 MCP 状态 | `/mcp` | `/mcp` | `/mcp` | — |
| 切换审批模式 | `Shift+Tab` | `Shift+Tab` | `Shift+Tab` | `Tab`（切换 Agent）|
| 新建会话 | `/clear` | — | — | `/new` |
| 撤销文件修改 | — | — | — | `/undo` |
| 退出 | `/exit` / `Ctrl+C` | `/exit` | `/quit` / `Ctrl+C` | `/exit` |

### 核心指标速查

| 指标 | Claude Code | Codex CLI | Gemini CLI | OpenCode |
|------|------------|-----------|------------|----------|
| SWE-bench Verified | **80.8%** 🥇 | ~72% | ~71% | 取决于底层模型 |
| Terminal-Bench 2.0 | ~68% | **77.3%** 🥇 | ~65% | 取决于底层模型 |
| 上下文窗口 | ~200K | ~192K | **1M**（付费）🥇 | 取决于底层模型 |
| Hooks 事件数 | **22 种** 🥇 | 2 种（实验） | 11 种 | 6 种 |
| 插件 / 扩展数 | **9,000+** 🥇 | 少量（新兴） | 100+ | npm 生态 |
| 免费额度 | 无 | 无 | **1000 次/天** 🥇 | 取决于提供商 |
| 开源协议 | 闭源 | CLI Apache-2.0 | Apache-2.0 | **MIT** 🥇 |
| 多模态 | ❌ | ❌ | **✅** 🥇 | 取决于底层模型 |
| JetBrains 原生 | ❌ | **✅** 🥇 | ❌ | ❌ |
| OS 内核级沙盒 | ❌ | **✅** 🥇 | ❌ | Docker 沙盒 |
| 跨会话记忆系统 | **✅** 🥇 | ❌ | ❌ | ✅（AGENTS.md）|
| 云端异步任务 | ❌ | **✅** 🥇 | ❌ | ❌ |
| LSP 原生支持 | ❌ | ❌ | ❌ | **✅** 🥇 |
| 提供商无关 | ❌ | ❌ | ❌ | **✅** 🥇 |
| 稳定性 | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐ |
| 最低月费 | $20 | $20（含 Plus） | $0 | $0（自带 Key）|

---

*2026-03-25 · 基于官方文档、基准测试数据、社区调研（500+ 开发者）综合编写*

*文档体系：本文 + ./claude-code.md + ./codex.md + ./gemini-cli.md + ./opencode.md*
