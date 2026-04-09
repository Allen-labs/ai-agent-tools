# OpenClaw Scripts

主文档先看：

- 使用：[../../README.md](../../README.md)
- 设计：[../../ARCHITECTURE.md](../../ARCHITECTURE.md)
- 任务追踪：[../../TASKS.md](../../TASKS.md)

这份文档只保留 OpenClaw 的特有差异。

## 统一使用方式

OpenClaw 仍然走统一入口和统一命令，只是它比 coding agents 多一层服务运维能力：

- 新装并应用推荐配置：`service install`
- 已装后重放配置、切访问模式、补飞书或安全策略：`service configure`
- 先看当前状态和建议动作：`service report`
- 详细排查：`service check`
- 看运行日志：`service logs`
- 技能和插件管理：`skill install`、`plugin install`
- 飞书接入检查：`feishu check`

## 工具特有点

- OpenClaw 属于服务型工具，不是单纯 CLI
- 常用命令面会比 coding agents 更完整
- 全局层遵循 OpenClaw 官方目录：`~/.openclaw/openclaw.json`、`~/.openclaw/exec-approvals.json`、`~/.openclaw/skills`、`~/.openclaw/extensions`
- 工具侧只保留仓库目录内的脚本、静态 wrapper 和默认备份目录，服务名与权限档位直接从配置文件读取
- 项目层遵循 OpenClaw 官方优先级：`<workspace>/skills` 优先于 `~/.openclaw/skills`

## 快速使用

```bash
cd /root/codes/ai-agent-tools/scripts

bash manage.sh service install --tool-name openclaw --config ./general-agents/openclaw/local.conf
bash manage.sh service configure --tool-name openclaw --config ./general-agents/openclaw/local.conf
bash manage.sh service report --tool-name openclaw --config ./general-agents/openclaw/local.conf
bash manage.sh service check --tool-name openclaw --config ./general-agents/openclaw/local.conf
bash manage.sh service logs --tool-name openclaw --config ./general-agents/openclaw/local.conf
```

## 三类典型场景

### 1. 从零开始安装

```bash
bash manage.sh service install --tool-name openclaw --config ./general-agents/openclaw/local.conf --yes
```

说明：

- 会安装 OpenClaw、Gateway、必要依赖和推荐配置
- 会按配置处理公网模式或 Tailscale 模式
- 会按配置尝试初始化默认 skill、plugin、记忆能力和安全基线

### 2. 已经用本工具安装，后续想增强或调整配置

```bash
bash manage.sh service configure --tool-name openclaw --config ./general-agents/openclaw/local.conf --yes
```

适用场景：

- 切换 `ACCESS_MODE`
- 调整公网模式、有无域名、证书和反向代理
- 打开或调整飞书接入
- 补装默认 skill / plugin / 记忆插件
- 收紧防火墙、限流和访问策略

### 3. 不是用本工具安装，但想升级到我们的推荐基线

```bash
bash manage.sh service configure --tool-name openclaw --config ./general-agents/openclaw/local.conf --yes
bash manage.sh service check --tool-name openclaw --config ./general-agents/openclaw/local.conf
```

如果不确定当前状态，先执行：

```bash
bash manage.sh service report --tool-name openclaw --config ./general-agents/openclaw/local.conf
```

## 常用配置项

- `ACCESS_MODE`
- `PUBLIC_MODE`
- `DOMAIN`
- `LETSENCRYPT_EMAIL`
- `GATEWAY_TOKEN`
- `FEISHU_APP_ID`
- `FEISHU_APP_SECRET`
- `FEISHU_VERIFICATION_TOKEN`
- `FEISHU_ENCRYPT_KEY`
- `MODEL_BASE_URL`
- `MODEL_PRIMARY`

## OpenClaw 特有能力

- systemd / nginx / 证书 / 防火墙
- Gateway 和访问模式
- 飞书接入
- skill / plugin 完整管理
- 长期记忆与上下文增强

## 访问模式

- `ACCESS_MODE=standard`
- `ACCESS_MODE=tailscale-private`
- `ACCESS_MODE=tailscale-public`
- `PUBLIC_MODE=public-ip`
- `PUBLIC_MODE=public-domain`

## 说明补充

- 有域名时建议 `ACCESS_MODE=standard` + `PUBLIC_MODE=public-domain`
- 只有公网 IP 时建议 `ACCESS_MODE=standard` + `PUBLIC_MODE=public-ip`
- 生产默认建议使用 `memory-lancedb-pro`
- 如需更长上下文保真，再额外启用 `lossless-claw`
- 如果在 Codex 一类受限沙箱里执行 `service report / check`，本机 WebSocket 探测会显示为 `restricted(sandbox-network)`，这表示当前执行环境受限，不代表现网 Gateway 异常
- 详细背景说明见 [OpenClaw 完整指南](../../../general-agents/openclaw.md)
