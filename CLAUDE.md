# CLAUDE.md — ai-agent-tools

## 项目说明

本仓库是 AI Agent 工具的完整指南文档集合，覆盖 Coding Agents 和 General Agents 两大类别。

## 目录结构

```
ai-agent-tools/
├── README.md                    ← 总导览
├── coding-agents/
│   ├── README.md                ← Coding Agents 选型对比指南
│   ├── claude-code.md
│   ├── codex.md
│   ├── gemini-cli.md
│   └── opencode.md
└── general-agents/
    ├── README.md                ← General Agents 导引
    └── openclaw.md
```

## Git 规范

### 提交者信息

```
name: allen
email: summerjiee@163.com
```

### Commit 规范

- 格式：`type: 简短描述`
- type 类型：`docs`（文档更新）、`feat`（新增工具文档）、`fix`（修正错误内容）、`refactor`（结构调整）
- 示例：`docs: 更新 opencode 配置章节`
- **禁止**在 commit message 中出现 AI 模型信息（如 Co-Authored-By Claude 等）

## 文档规范

- 语言：中文为主，技术术语保留英文
- 配置示例：只写已确认存在的字段，不编造
- 文件命名：工具官方短名，全小写，连字符分隔（如 `claude-code.md`）
- 每份文档末尾注明编写日期和参考来源
