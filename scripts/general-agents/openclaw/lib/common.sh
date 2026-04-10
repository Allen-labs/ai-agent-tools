#!/usr/bin/env bash

color_enabled=0
if [[ -t 1 ]] && command -v tput >/dev/null 2>&1; then
  color_enabled=1
fi

color() {
  if [[ "${color_enabled}" != "1" ]]; then
    return
  fi
  tput setaf "$1"
}

reset_color() {
  if [[ "${color_enabled}" == "1" ]]; then
    tput sgr0
  fi
}

log() {
  local level="$1"
  shift
  case "${level}" in
    info) color 6 ;;
    ok) color 2 ;;
    warn) color 3 ;;
    err) color 1 ;;
  esac
  printf '[%s] %s\n' "${level^^}" "$*"
  reset_color
}

die() {
  log err "$*"
  exit 1
}

confirm() {
  local prompt="$1"
  if [[ "${ASSUME_YES}" == "1" ]]; then
    return 0
  fi
  read -r -p "${prompt} [y/N]: " answer
  [[ "${answer}" =~ ^[Yy]([Ee][Ss])?$ ]]
}

bool_to_json() {
  if [[ "${1:-0}" == "1" ]]; then
    echo true
  else
    echo false
  fi
}

ensure_command() {
  command -v "$1" >/dev/null 2>&1 || die "缺少必要命令：$1"
}

safe_plugin_install() {
  local package_spec="$1"
  local label="${2:-插件}"
  [[ -n "${package_spec}" ]] || return
  log info "正在安装${label}：${package_spec}"
  if ! openclaw plugins install "${package_spec}"; then
    die "${label}安装失败：${package_spec}"
  fi
}

check_path_command() {
  local cmd="$1"
  if command -v "${cmd}" >/dev/null 2>&1; then
    echo "ok"
  else
    echo "missing"
  fi
}

print_report_line() {
  local key="$1"
  local value="$2"
  printf '  %-24s %s\n' "${key}" "${value}"
}

sensitive_presence_display_value() {
  local value="${1:-}"
  local empty_label="${2:-缺失}"
  local configured_label="${3:-已配置（已脱敏）}"

  if [[ -n "${value}" ]]; then
    printf '%s' "${configured_label}"
  else
    printf '%s' "${empty_label}"
  fi
}

supports_color() {
  [[ -z "${NO_COLOR:-}" ]] || return 1
  if [[ -n "${FORCE_COLOR:-}" && "${FORCE_COLOR}" != "0" ]]; then
    return 0
  fi
  [[ -t 1 ]] || return 1
  [[ "${TERM:-}" != "dumb" ]] || return 1
}

help_init_colors() {
  if supports_color; then
    HELP_RESET=$'\033[0m'
    HELP_BOLD=$'\033[1m'
    HELP_DIM=$'\033[2m'
    HELP_WHITE=$'\033[97m'
    HELP_BLUE=$'\033[38;2;5;80;174m'
  else
    HELP_RESET=''
    HELP_BOLD=''
    HELP_DIM=''
    HELP_WHITE=''
    HELP_BLUE=''
  fi
}

help_repeat_char() {
  local char="${1:--}"
  local count="${2:-62}"
  local fill=""

  (( count > 0 )) || return 0
  printf -v fill '%*s' "${count}" ''
  printf '%s' "${fill// /${char}}"
}

help_print_title() {
  local title="$1"
  local subtitle="${2:-}"
  printf '%s%s%s\n' "${HELP_BOLD}${HELP_WHITE}" "${title}" "${HELP_RESET}"
  if [[ -n "${subtitle}" ]]; then
    printf '%s%s%s\n' "${HELP_DIM}" "${subtitle}" "${HELP_RESET}"
  fi
}

help_print_section() {
  local title="$1"
  printf '\n%s%s%s\n' "${HELP_BOLD}${HELP_WHITE}" "${title}" "${HELP_RESET}"
}

help_print_rule() {
  printf '%s%s%s\n' "${HELP_DIM}" "$(help_repeat_char "-" 62)" "${HELP_RESET}"
}

help_print_strong_rule() {
  printf '%s%s%s\n' "${HELP_DIM}" "$(help_repeat_char "=" 62)" "${HELP_RESET}"
}

help_print_context() {
  local label="$1"
  local value="$2"
  printf '  %s%s:%s %s\n' "${HELP_BOLD}${HELP_WHITE}" "${label}" "${HELP_RESET}" "${value}"
}

help_print_entry() {
  local left="$1"
  local right="$2"
  if printf '%s' "${left}" | LC_ALL=C grep -Eq '^[A-Za-z0-9._/<>=|: -]+$'; then
    printf '  %s%-24s%s %s\n' "${HELP_BLUE}" "${left}" "${HELP_RESET}" "${right}"
  else
    printf '  %s%s:%s %s\n' "${HELP_BLUE}" "${left}" "${HELP_RESET}" "${right}"
  fi
}

help_print_command() {
  local command_text="$1"
  local note="${2:-}"
  printf '  %s%s%s\n' "${HELP_BLUE}" "${command_text}" "${HELP_RESET}"
  if [[ -n "${note}" ]]; then
    printf '    %s%s%s\n' "${HELP_DIM}" "${note}" "${HELP_RESET}"
  fi
}

help_print_note() {
  local text="$1"
  printf '  %s%s%s\n' "${HELP_DIM}" "${text}" "${HELP_RESET}"
}

help_print_step() {
  local index="$1"
  local command_text="$2"
  local note="${3:-}"
  printf '  %s[%s]%s %s%s%s\n' "${HELP_DIM}" "${index}" "${HELP_RESET}" "${HELP_BLUE}" "${command_text}" "${HELP_RESET}"
  if [[ -n "${note}" ]]; then
    printf '      %s%s%s\n' "${HELP_DIM}" "${note}" "${HELP_RESET}"
  fi
}

help_print_case() {
  local title="$1"
  local command_text="$2"
  local note="${3:-}"
  printf '  %s%s%s\n' "${HELP_BOLD}${HELP_WHITE}" "${title}" "${HELP_RESET}"
  printf '    %s%s%s\n' "${HELP_BLUE}" "${command_text}" "${HELP_RESET}"
  if [[ -n "${note}" ]]; then
    printf '      %s%s%s\n' "${HELP_DIM}" "${note}" "${HELP_RESET}"
  fi
}

trim_config_value() {
  local value="${1:-}"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "${value}"
}

load_key_value_config() {
  local config_file="$1"
  local line=""
  local key=""
  local value=""
  local line_no=0

  while IFS= read -r line || [[ -n "${line}" ]]; do
    line_no=$((line_no + 1))
    line="${line%$'\r'}"
    [[ "${line}" =~ ^[[:space:]]*$ ]] && continue
    [[ "${line}" =~ ^[[:space:]]*# ]] && continue

    if [[ "${line}" =~ ^[[:space:]]*(export[[:space:]]+)?([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*=(.*)$ ]]; then
      key="${BASH_REMATCH[2]}"
      value="$(trim_config_value "${BASH_REMATCH[3]}")"
      if [[ "${value}" =~ ^\".*\"$ || "${value}" =~ ^\'.*\'$ ]]; then
        value="${value:1:${#value}-2}"
      fi
      printf -v "${key}" '%s' "${value}"
      continue
    fi

    log err "配置文件格式错误：${config_file}:${line_no}"
    log err "无效内容：${line}"
    return 1
  done < "${config_file}"
}

require_root() {
  [[ "$(id -u)" -eq 0 ]] || die "请使用 root 运行。"
}

require_config() {
  [[ -n "${CONFIG_FILE}" ]] || die "必须提供 --config"
  [[ -f "${CONFIG_FILE}" ]] || die "配置文件不存在：${CONFIG_FILE}"
  load_key_value_config "${CONFIG_FILE}" || die "配置文件解析失败：${CONFIG_FILE}"
  normalize_access_model
}

normalize_access_model() {
  ACCESS_MODE="${ACCESS_MODE:-standard}"
  PUBLIC_MODE="${PUBLIC_MODE:-public-domain}"
  TAILSCALE_HOSTNAME="${TAILSCALE_HOSTNAME:-openclaw-node}"
  TAILSCALE_SERVE_TARGET="${TAILSCALE_SERVE_TARGET:-http://127.0.0.1:${GATEWAY_PORT:-18789}}"

  case "${ACCESS_MODE}" in
    standard)
      case "${PUBLIC_MODE}" in
        public-ip)
          ENABLE_NGINX=1
          ENABLE_CERTBOT=0
          ;;
        public-domain)
          ENABLE_NGINX=1
          ENABLE_CERTBOT=1
          ;;
        *)
          die "未知 PUBLIC_MODE：${PUBLIC_MODE}，仅支持 public-ip / public-domain"
          ;;
      esac
      ;;
    tailscale-private|tailscale-public)
      ENABLE_NGINX=0
      ENABLE_CERTBOT=0
      ;;
    *)
      die "未知 ACCESS_MODE：${ACCESS_MODE}，仅支持 standard / tailscale-private / tailscale-public"
      ;;
  esac
}

summarize_config() {
  if declare -F init_tool_layout_vars >/dev/null 2>&1; then
    init_tool_layout_vars
  fi
  log info "当前部署摘要"
  echo "  配置文件: ${CONFIG_FILE}"
  echo "  服务名: ${SYSTEMD_SERVICE_NAME}"
  echo "  工具目录: ${OPENCLAW_TOOL_ROOT:-${PWD}}"
  echo "  OpenClaw 目录: ${OPENCLAW_HOME}"
  echo "  数据目录: ${OPENCLAW_STATE_DIR}"
  echo "  备份目录: ${BACKUP_ROOT:-<未初始化>}"
  echo "  访问模式: ${ACCESS_MODE:-standard}"
  echo "  公网模式: ${PUBLIC_MODE:-public-domain}"
  echo "  域名: ${DOMAIN:-<无>}"
  echo "  Tailscale 主机名: ${TAILSCALE_HOSTNAME:-<无>}"
  echo "  Nginx: ${ENABLE_NGINX:-0}"
  echo "  Certbot: ${ENABLE_CERTBOT:-0}"
  echo "  UFW: ${ENABLE_UFW:-0}"
  echo "  飞书: ${ENABLE_FEISHU:-0}"
  echo "  飞书流式输出: ${FEISHU_STREAMING:-1}"
  echo "  长期记忆插件: ${ENABLE_MEMORY_PLUGIN:-0}/${MEMORY_PLUGIN:-none}"
  echo "  上下文引擎: ${ENABLE_CONTEXT_ENGINE:-0}/${CONTEXT_ENGINE:-none}"
}

openclaw_render_governance_files_if_missing() {
  local governance_path="${OPENCLAW_STATE_DIR}/GOVERNANCE.md"
  local engineering_path="${OPENCLAW_STATE_DIR}/ENGINEERING.md"
  local delivery_path="${OPENCLAW_STATE_DIR}/DELIVERY.md"
  local memory_rules_path="${OPENCLAW_STATE_DIR}/MEMORY-RULES.md"

  mkdir -p "${OPENCLAW_STATE_DIR}"

  if [[ ! -f "${governance_path}" ]]; then
    cat > "${governance_path}" <<'EOF'
# OpenClaw 全局治理约定

## 目标
- 保证 OpenClaw 服务长期稳定、可维护、可审计
- 安全、性能、稳定性优先于临时方便
- 官方目录只放长期有效的运行约束和维护规范

## 默认原则
- 变更前先看现有配置、systemd、Nginx、接入方式和回滚路径
- 优先最小变更，避免影响正在运行的服务
- 涉及公网暴露、消息接入、权限放行、长期记忆时必须明确说明
- 工具脚本负责管理；长期规则回写到 `~/.openclaw`

## 运维边界
- 不随意扩大公网暴露面
- 不默认放宽高权限执行策略
- 配置、文档、脚本和运行状态保持一致
- 关键异常、已知坑点和恢复方式要可沉淀、可复用
EOF
  fi

  if [[ ! -f "${engineering_path}" ]]; then
    cat > "${engineering_path}" <<'EOF'
# 工程与运维规范

## 服务变更
- 先验证配置，再重载或重启
- 先保活现网，再做增强
- 涉及 systemd、Nginx、证书、防火墙时同步检查

## 安全要求
- 默认最小公网暴露
- 敏感配置只记录状态，不在报告里回显明文
- 限流、路径拦截、恶意来源防护优先保持开启
- 执行权限档位保持最小满足原则

## 稳定性要求
- 网关、健康检查、消息接入都要可观测
- 新增插件、skill、记忆组件时保留失败降级路径
- 变更后至少执行最小健康检查和日志确认
EOF
  fi

  if [[ ! -f "${delivery_path}" ]]; then
    cat > "${delivery_path}" <<'EOF'
# 交付与验收检查单

## 变更前
- 配置是否补齐
- 接入方式是否明确
- 回滚方式是否明确
- 是否会影响现网服务

## 变更后
- `openclaw config validate` 是否通过
- 网关和健康检查是否正常
- 飞书 / 记忆 / Tailscale / Nginx 是否按启用项核对
- 是否记录了未执行项与风险

## 发布后观察
- 服务日志
- 网关探测
- 健康检查
- 外部入口可达性
- 插件或 skill 初始化结果
EOF
  fi

  if [[ ! -f "${memory_rules_path}" ]]; then
    cat > "${memory_rules_path}" <<'EOF'
# 记忆回写规则

## 应回写
- 长期有效的部署规范
- 已确认的接入限制与绕行方案
- 常见故障和恢复步骤
- 默认能力包、权限档位、消息接入的稳定做法

## 不回写
- 一次性调试输出
- 临时密钥或敏感凭据
- 仅对单次排障有效的临时结论

## 回写要求
- 写结论，不写流水账
- 写适用范围和触发条件
- 新结论确认后及时更新，避免重复踩坑
EOF
  fi
}

openclaw_governance_state() {
  local present="0"
  local file_path=""

  for file_path in \
    "${OPENCLAW_STATE_DIR}/GOVERNANCE.md" \
    "${OPENCLAW_STATE_DIR}/ENGINEERING.md" \
    "${OPENCLAW_STATE_DIR}/DELIVERY.md" \
    "${OPENCLAW_STATE_DIR}/MEMORY-RULES.md"; do
    [[ -f "${file_path}" ]] && present=$((present + 1))
  done

  printf '%s/4' "${present}"
}

openclaw_governance_ready() {
  [[ "$(openclaw_governance_state)" == "4/4" ]]
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --config)
        CONFIG_FILE="${2:-}"
        shift 2
        ;;
      --yes)
        ASSUME_YES=1
        shift
        ;;
      --name)
        TARGET_NAMES="${2:-}"
        shift 2
        ;;
      --path)
        TARGET_PATH="${2:-}"
        shift 2
        ;;
      --level)
        TARGET_LEVEL="${2:-}"
        shift 2
        ;;
      --workspace)
        TARGET_WORKSPACE="${2:-}"
        shift 2
        ;;
      --scope)
        TARGET_SCOPE="${2:-}"
        shift 2
        ;;
      --section)
        TARGET_SECTION="${2:-}"
        shift 2
        ;;
      --purge-data)
        KEEP_DATA=0
        shift
        ;;
      --guide-only)
        SHOW_GUIDE_ONLY=1
        shift
        ;;
      --help|-h)
        usage
        exit 0
        ;;
      *)
        die "未知参数：$1"
        ;;
    esac
  done
}
