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
