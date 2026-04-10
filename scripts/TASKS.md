# Tasks

这份文档只负责两件事：

- 记录当前已经完成了什么
- 记录下一步按什么顺序推进

它不重复设计细节，不重复使用说明。

设计看：

- [ARCHITECTURE.md](./ARCHITECTURE.md)

使用看：

- [README.md](./README.md)

## 当前状态

### 已完成

- 这一节默认表示“脚本能力、文档与目录治理层已完成”，不等于所有工具都已经在当前机器完成实机安装验证
- 顶层统一入口已建立：`manage.sh`
- `openclaw` 和四个 coding agent 已接入统一路由
- 顶层文档、子文档、帮助输出、配置样例，已经基本按同一套场景化心智收敛：
  - 新装：`service install`
  - 已装重放：`service configure`
  - 项目初始化：`config init`
  - 先看状态：`service report`
  - 详细检查：`service check`
- 顶层已新增 `guide start`
  - 面向首次使用者
  - 只输出 1-2 条最短上手命令
- 顶层已新增 `scenario`
  - 面向需要交互式引导的场景
  - 可按场景自动串起 install / configure / report / check / init
  - 已补成步骤式全交互向导：选工具、选场景、选配置文件、补关键配置、确认执行
  - 已能在执行前补齐关键配置并写回 `local.conf`
  - 配置写入底层能力已收敛到顶层 `config set`，`scenario` 只做交互与编排
  - 已能在配置文件不存在时自动从 `conf.example` 创建
  - `openclaw` 已补“部署形态”引导，不再直接暴露访问模式细节给首次使用者
  - 常见安装 / 增强场景已默认沿用推荐模型和模式，只在用户明确要求时展开进阶项
  - 已补 `back / b / q` 导航链路，关键配置阶段可回到本阶段开头
- 四个 coding agent 已完成：
  - 安装 / 更新 / 卸载 / 配置重放 / 检查
  - 全局 / 项目初始化
  - 能力包配置模型
  - manifest 生成
  - `service report`
  - `config show`
- 四个 coding agent 已补官方 `agents/` 目录治理层：
  - `global-governance.md`
  - `engineering-standards.md`
  - `delivery-checklist.md`
  - `memory-rules.md`
  - `planner.md`
  - `implementer.md`
  - `reviewer.md`
  - `tester.md`
- `service report / check` 已把全局治理模板和全局角色模板补齐度纳入输出
- OpenClaw 已补 `~/.openclaw` 治理文件：
  - `GOVERNANCE.md`
  - `ENGINEERING.md`
  - `DELIVERY.md`
  - `MEMORY-RULES.md`
- 目录模型已收敛：
  - 官方目录保留在工具默认位置
  - 工具侧生成的备份、清单、包装命令写回各自工具目录
  - 不再额外引入独立中间运行层
- 能力项元信息已建立：
  - `source`
  - `install`
  - `risk`
- `tool review` 已覆盖：
  - 语法检查
  - 全局初始化回归
  - 项目初始化回归
  - 默认报告回归
  - 文档关键内容检查
  - 旧概念残留检查
  - 能力项元信息完整性
  - 帮助输出可读性
- `tool review` 的全局初始化回归已切到隔离临时目录，不会触碰真实官方全局目录
- `openclaw`、`coding agents` 的帮助输出与配置样例，已按三类典型场景补齐：
  - 从零安装
  - 已装增强
  - 迁移接管
- 顶层入口、分类入口和 OpenClaw 入口的帮助输出，已进一步收敛为彩色分层结构：
  - 主命令
  - 全局参数
  - 配置起步模板
  - 默认记忆
  - 场景闭环
  - 支持功能 / 按需能力
- 共享日志、分节标题和报告输出已统一走彩色结构化样式，减少纯文本提示造成的歧义
- 四个 coding agent 的 `service check / report` 已补“建议动作”输出，可直接提示下一条该执行 `service install` 还是 `service configure`
- 四个 coding agent 的 `service check / report` 已补“未就绪原因”输出，可直接说明当前为什么没有达到推荐基线
- 四个 coding agent 的 `service check / report` 已补“能力包策略”输出，可直接看默认包、增强包、实验包的启用状态
- 四个 coding agent 的 `service check / report` 已补“双口径统计”输出：
  - `核心能力统计`
  - `能力项统计`
- 四个 coding agent 的 `conf.example` 已按工具改成“通用增强包 + 工具专属增强包”的组合，不再只给一套统一的增强包列表
- Coding Agents 正在把用户侧配置收敛为 `MODE=standard|advanced|exploration`，减少增强开关与实验开关的理解成本

### 已完成但仍需深化

- `config init --scope project`
  - 已能生成项目骨架
  - 已生成并增强共享的 `project-context / architecture / workflow / checklist`
  - 已补角色分工、持续记忆、测试基线、发布与回滚检查单
  - 还需要继续补更强的工具级使用指引
- 官方目录治理层
  - 已能自动补齐并纳入检查
  - 还需要继续补更完整的实机验证与失败降级说明
- 能力包模型
  - 已能配置和检查
  - `codex / claude-code / gemini-cli / opencode` 已进入第一批真实落地
  - `codex / claude-code` 第三方来源已进入第一批自动化
  - `gemini-cli` 已补官方名称、`github:org/repo`、`org/repo`、GitHub URL、本地路径的 extension 规格
  - `opencode` 已把远程 GitHub / URL 来源纳入状态快照，并明确官方仍以 npm 包或本地 JS/TS 插件文件为准
  - `service check / report` 已补第一批最佳实践就绪度
  - 还需要继续补更广生态、深度校验和最佳实践引导

### 当前主要缺口

- `openclaw` 和四个 coding agent 还缺少更完整的非破坏性实机生命周期验证
- 默认精选能力包还需要继续按“双口径统计 + 实机反馈”收敛成更明确、更强的推荐组合
- 登录、授权、429、未注册等第三方来源问题，还需要按工具分别补清晰提示和降级说明
- 各工具“最佳使用方式”的引导还需要继续加强，尤其是官方全局目录与项目目录如何配合使用
- `scenario` 还可以继续补更细的工具级最佳实践提示，但主链路已经可用

## 三类场景验证矩阵

### 当前目标场景

1. 从零开始安装
2. 已经由本工具安装，后续增强或改配置
3. 不是由本工具安装，迁移到推荐基线

### 当前验证状态

- `openclaw`
  - 场景 1：命令、文档、配置样例已收敛；实机生命周期验证待补
  - 场景 2：命令、文档、配置样例已收敛；实机配置重放验证待补
  - 场景 3：命令、文档、配置样例已收敛；实机迁移接管验证待补
- `codex`
  - 场景 1：隔离初始化回归已通过；实机 install / configure 待补
  - 场景 2：报告、建议动作、模式切换路径已具备；实机 configure 待补
  - 场景 3：报告已能给出 install / configure 建议；实机迁移接管待补
- `claude-code`
  - 场景 1：隔离初始化回归已通过；实机 install / configure 待补
  - 场景 2：报告、建议动作、模式切换路径已具备；实机 configure 待补
  - 场景 3：报告已能给出 install / configure 建议；实机迁移接管待补
- `gemini-cli`
  - 场景 1：隔离初始化回归已通过；实机 install / configure 待补
  - 场景 2：报告、建议动作、模式切换路径已具备；实机 configure 待补
  - 场景 3：报告已能给出 install / configure 建议；实机迁移接管待补
- `opencode`
  - 场景 1：隔离初始化回归已通过；实机 install / configure 待补
  - 场景 2：报告、建议动作、模式切换路径已具备；实机 configure 待补
  - 场景 3：报告已能给出 install / configure 建议；实机迁移接管待补

## 当前优先级

### P1

- 完成 `openclaw` 和四个 coding agent 的非破坏性实机生命周期验证
- 先补三类场景验证记录：
  - 新装
  - 已装增强
  - 迁移接管
- 深化 `codex` 的第三方 skill 来源策略与更新策略
- 深化 `claude-code` 的第三方 marketplace / plugin 来源策略
- 深化 `gemini-cli` 的 extension 可用性校验
- 深化 `opencode` 的 plugin 已配置 / 已安装 / 未生效 校验
- 对官方目录治理层补更多实机验证和失败提示

### P2

- 安装后可用性校验
- 登录前提和人工授权提示
- 失败重试、降级和回退
- 默认能力包的进一步收敛与增强包边界整理

### P3

- 默认 role / memory 模板
- 架构说明、开发规范、测试计划、发布检查单
- 各工具最佳使用指南

## 下一步执行顺序

1. `openclaw` 和四个 coding agent 的三类场景验证记录补齐
2. 四个 coding agent 的非破坏性实机生命周期验证
3. `codex`
4. `claude-code`
5. 第三方来源与深度校验
6. 深化 `gemini-cli`
7. 深化 `opencode`
8. 工具级最佳使用指南增强

## 完成标准

只有满足下面这些条件，才算进入下一阶段完成：

- `service install` 能真正把默认能力装起来
- `service check` 能说明：
  - 已安装
  - 已配置
  - 未生效
  - 需要人工登录或授权
- `config init --scope project` 能生成可直接进入开发的项目模板
- 文档、帮助、实现保持一致
- `bash manage.sh tool review` 通过
