#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
# 顶层入口只做路由，公共日志与交互函数统一从 scripts/shared 加载。
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/shared/lib/common.sh"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/shared/lib/review.sh"
PROGRAM_NAME="$(basename "$0")"
COMMAND_GROUP="${1:-help}"
COMMAND_ACTION="${2:-}"
TARGET_TOOL=""
FORWARD_ARGS=()
GUIDE_SCENE="all"
GUIDE_CONFIG=""
GUIDE_PATH="/workspace/project"
SCENE_NAME=""
SCENE_TOOL=""
SCENE_CONFIG=""
SCENE_PATH=""
SCENE_ASSUME_YES=0
SCENE_INCLUDE_PROJECT=0
SCENE_STEP_INDEX=1
SCENE_WIZARD_STEP=1
SCENE_UPDATE_LINES=()
SCENE_NOTE_LINES=()
SCENE_OPENCLAW_PROFILE=""

usage() {
  help_init_colors
  help_print_title "AI Agent Tools 统一管理工具"
  help_print_strong_rule
  help_print_context "已接入" "openclaw | claude-code | codex | gemini-cli | opencode"
  help_print_context "主入口" "${PROGRAM_NAME}"

  help_print_section "主命令"
  help_print_rule
  help_print_entry "scenario" "交互补齐 + 执行"
  help_print_entry "guide start" "最短路径"
  help_print_entry "service install" "首次安装"
  help_print_entry "service configure" "增强 / 接管"
  help_print_entry "config init" "初始化模板"
  help_print_entry "service report" "状态概览"
  help_print_entry "service check" "详细检查"
  help_print_entry "tool list" "工具列表"
  help_print_entry "tool review" "仓库自检"

  help_print_section "全局参数"
  help_print_rule
  help_print_entry "--tool-name <tool>" "工具名"
  help_print_entry "--config <config>" "配置文件"
  help_print_entry "--scene <scene>" "install|enhance|migrate|project|status|all"
  help_print_entry "--path <path>" "项目路径"
  help_print_entry "--yes" "跳过交互 / 确认"

  help_print_section "快速上手"
  help_print_rule
  help_print_step "1" "${PROGRAM_NAME} scenario"
  help_print_step "2" "${PROGRAM_NAME} scenario --tool-name codex --scene install"
  help_print_step "3" "${PROGRAM_NAME} guide start --tool-name codex"
  help_print_step "4" "${PROGRAM_NAME} tool review"

  help_print_section "常见场景"
  help_print_rule
  help_print_case "交互安装" "${PROGRAM_NAME} scenario --tool-name codex --scene install"
  help_print_case "首次安装" "${PROGRAM_NAME} service install --tool-name codex --config ./coding-agents/codex/local.conf --yes"
  help_print_case "已装增强 / 接管" "${PROGRAM_NAME} service configure --tool-name codex --config ./coding-agents/codex/local.conf --yes"
  help_print_case "项目模板" "${PROGRAM_NAME} config init --tool-name codex --config ./coding-agents/codex/local.conf --scope project --path /workspace/project --yes"
  help_print_case "查看状态" "${PROGRAM_NAME} service report --tool-name codex --config ./coding-agents/codex/local.conf"

  help_print_section "按需能力"
  help_print_rule
  help_print_entry "scenario" "交互补齐 + 执行"
  help_print_entry "guide start --scene" "切换场景"
  help_print_entry "tool list" "查看工具"
  help_print_entry "tool review" "回归检查"
  help_print_entry "OpenClaw 扩展" "skill / plugin / feishu"
  help_print_entry "详细帮助" "${PROGRAM_NAME} service check --tool-name codex --help"
}

scene_usage() {
  help_init_colors
  help_print_title "Scenario"
  help_print_strong_rule
  help_print_context "用途" "步骤式全交互：补齐关键配置并执行场景"
  help_print_section "用法"
  help_print_rule
  help_print_command "${PROGRAM_NAME} scenario"
  help_print_command "${PROGRAM_NAME} scenario --tool-name codex --scene install"
  help_print_command "${PROGRAM_NAME} scenario --tool-name codex --scene project --path /workspace/project"
  help_print_section "参数"
  help_print_rule
  help_print_entry "--tool-name <tool>" "工具名"
  help_print_entry "--scene <scene>" "install|enhance|migrate|project|status"
  help_print_entry "--config <config>" "配置文件"
  help_print_entry "--path <path>" "项目路径"
  help_print_entry "--yes" "跳过交互，直接执行"
  help_print_section "说明"
  help_print_rule
  help_print_note "默认会按步骤引导：工具 -> 场景 -> 配置文件 -> 关键配置 -> 执行确认。"
  help_print_note "常见场景默认沿用配置里的推荐模型和模式，只在你明确要改时展开进阶项。"
  help_print_note "install / enhance / migrate 会先补齐关键配置，再展示执行计划。"
  help_print_note "status / project 只做必要输入，不额外追问认证和密钥。"
  help_print_note "OpenClaw 安装 / 增强 / 接管会先引导选择部署形态：公网域名 / 公网 IP / Tailscale 私网 / Tailscale 公网。"
}

prompt_with_default() {
  local message="$1"
  local default_value="${2:-}"
  local answer=""

  if [[ "${SCENE_ASSUME_YES}" == "1" ]]; then
    printf '%s' "${default_value}"
    return 0
  fi

  while true; do
    if [[ -n "${default_value}" ]]; then
      read -r -p "${message} [${default_value}]: " answer
      printf '%s' "${answer:-${default_value}}"
      return 0
    fi

    read -r -p "${message}: " answer
    if [[ -n "${answer}" ]]; then
      printf '%s' "${answer}"
      return 0
    fi
    log_warn "${message} 不能为空。"
  done
}

scene_start_step() {
  local title="$1"
  local note="${2:-}"

  [[ "${SCENE_ASSUME_YES}" == "1" ]] && return 0

  help_print_section "步骤 ${SCENE_WIZARD_STEP} · ${title}"
  help_print_rule
  if [[ -n "${note}" ]]; then
    help_print_note "${note}"
  fi
  SCENE_WIZARD_STEP=$((SCENE_WIZARD_STEP + 1))
}

prompt_menu_choice() {
  local message="$1"
  local default_value="${2:-}"
  shift 2
  local entries=( "$@" )
  local -a values=()
  local -a labels=()
  local entry=""
  local value=""
  local label=""
  local answer=""
  local i=0
  local default_index="1"

  for entry in "${entries[@]}"; do
    if [[ "${entry}" == *"|"* ]]; then
      value="${entry%%|*}"
      label="${entry#*|}"
    else
      value="${entry}"
      label="${entry}"
    fi
    values+=("${value}")
    labels+=("${label}")
  done

  if [[ -z "${default_value}" && "${#values[@]}" -gt 0 ]]; then
    default_value="${values[0]}"
  fi

  for i in "${!values[@]}"; do
    if [[ "${values[$i]}" == "${default_value}" ]]; then
      default_index="$((i + 1))"
      break
    fi
  done

  if [[ "${SCENE_ASSUME_YES}" == "1" ]]; then
    if [[ -n "${default_value}" ]]; then
      printf '%s' "${default_value}"
      return 0
    fi
    log_error "${message} 缺少默认值；请先写入配置文件或去掉 --yes。"
    return 1
  fi

  for i in "${!labels[@]}"; do
    printf '  %s%-2s%s %s\n' "${HELP_BLUE}" "$((i + 1))" "${HELP_RESET}" "${labels[$i]}" >&2
  done

  while true; do
    read -r -p "${message} [${default_index}]: " answer
    answer="${answer:-${default_index}}"

    if [[ "${answer}" =~ ^[0-9]+$ ]] && (( answer >= 1 && answer <= ${#values[@]} )); then
      printf '%s' "${values[$((answer - 1))]}"
      return 0
    fi

    for i in "${!values[@]}"; do
      if [[ "${answer}" == "${values[$i]}" ]]; then
        printf '%s' "${values[$i]}"
        return 0
      fi
    done

    log_warn "请输入有效编号。"
  done
}

prompt_optional_with_default() {
  local message="$1"
  local default_value="${2:-}"
  local answer=""

  if [[ "${SCENE_ASSUME_YES}" == "1" ]]; then
    printf '%s' "${default_value}"
    return 0
  fi

  if [[ -n "${default_value}" ]]; then
    read -r -p "${message} [${default_value}]: " answer
    printf '%s' "${answer:-${default_value}}"
  else
    read -r -p "${message}: " answer
    printf '%s' "${answer}"
  fi
}

prompt_secret_with_default() {
  local message="$1"
  local default_value="${2:-}"
  local required="${3:-1}"
  local answer=""

  if [[ "${SCENE_ASSUME_YES}" == "1" ]]; then
    if [[ "${required}" == "1" && -z "${default_value}" ]]; then
      log_error "${message} 不能为空；请先写入配置文件或去掉 --yes。"
      return 1
    fi
    printf '%s' "${default_value}"
    return 0
  fi

  while true; do
    if [[ -n "${default_value}" ]]; then
      read -r -s -p "${message} [回车保留现有值]: " answer
      printf '\n' >&2
      answer="${answer:-${default_value}}"
    else
      read -r -s -p "${message}: " answer
      printf '\n' >&2
    fi

    if [[ "${required}" == "0" || -n "${answer}" ]]; then
      printf '%s' "${answer}"
      return 0
    fi
    log_warn "${message} 不能为空。"
  done
}

prompt_choice_with_default() {
  local message="$1"
  local default_value="${2:-}"
  shift 2
  local options=( "$@" )
  local answer=""
  local option=""

  if [[ -z "${default_value}" && "${#options[@]}" -gt 0 ]]; then
    default_value="${options[0]}"
  fi

  if [[ "${SCENE_ASSUME_YES}" == "1" ]]; then
    if [[ -n "${default_value}" ]]; then
      printf '%s' "${default_value}"
      return 0
    fi
    log_error "${message} 缺少默认值；请先写入配置文件或去掉 --yes。"
    return 1
  fi

  while true; do
    read -r -p "${message} [${default_value}]: " answer
    answer="${answer:-${default_value}}"
    for option in "${options[@]}"; do
      if [[ "${answer}" == "${option}" ]]; then
        printf '%s' "${answer}"
        return 0
      fi
    done
    log_warn "仅支持：$(IFS='/'; printf '%s' "${options[*]}")"
  done
}

scene_confirm_default() {
  local message="$1"
  local default_yes="${2:-0}"
  local answer=""

  answer="$(prompt_menu_choice "${message}" "${default_yes}" "1|是" "0|否")" || return 1
  [[ "${answer}" == "1" ]]
}

config_read_value() {
  local config_file="$1"
  local target_key="$2"
  local line=""
  local key=""
  local value=""

  [[ -f "${config_file}" ]] || return 1

  while IFS= read -r line || [[ -n "${line}" ]]; do
    line="${line%$'\r'}"
    [[ "${line}" =~ ^[[:space:]]*$ ]] && continue
    [[ "${line}" =~ ^[[:space:]]*# ]] && continue

    if [[ "${line}" =~ ^[[:space:]]*(export[[:space:]]+)?([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*=(.*)$ ]]; then
      key="${BASH_REMATCH[2]}"
      value="$(trim_config_value "${BASH_REMATCH[3]}")"
      if [[ "${value}" =~ ^\".*\"$ || "${value}" =~ ^\'.*\'$ ]]; then
        value="${value:1:${#value}-2}"
      fi
      if [[ "${key}" == "${target_key}" ]]; then
        printf '%s' "${value}"
        return 0
      fi
    fi
  done < "${config_file}"

  return 1
}

config_format_value() {
  local value="${1:-}"
  local escaped="${value//\\/\\\\}"
  escaped="${escaped//\"/\\\"}"

  if [[ -z "${value}" ]]; then
    printf '""'
  elif [[ "${value}" =~ ^[A-Za-z0-9._:/@%+=,-]+$ ]]; then
    printf '%s' "${value}"
  else
    printf '"%s"' "${escaped}"
  fi
}

config_set_value() {
  local config_file="$1"
  local target_key="$2"
  local target_value="${3:-}"
  local temp_file=""
  local line=""
  local key=""
  local replaced="0"

  temp_file="$(mktemp)"

  while IFS= read -r line || [[ -n "${line}" ]]; do
    if [[ "${line}" =~ ^[[:space:]]*(export[[:space:]]+)?([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*=.*$ ]]; then
      key="${BASH_REMATCH[2]}"
      if [[ "${key}" == "${target_key}" ]]; then
        printf '%s=%s\n' "${target_key}" "$(config_format_value "${target_value}")" >> "${temp_file}"
        replaced="1"
        continue
      fi
    fi
    printf '%s\n' "${line}" >> "${temp_file}"
  done < "${config_file}"

  if [[ "${replaced}" != "1" ]]; then
    printf '%s=%s\n' "${target_key}" "$(config_format_value "${target_value}")" >> "${temp_file}"
  fi

  mv "${temp_file}" "${config_file}"
}

scene_record_update() {
  local key="$1"
  local display_value="$2"
  SCENE_UPDATE_LINES+=("${key}"$'\t'"${display_value}")
}

scene_record_note() {
  SCENE_NOTE_LINES+=("$1")
}

scene_display_value() {
  local value="${1:-}"
  local secret="${2:-0}"

  if [[ "${secret}" == "1" ]]; then
    if [[ -n "${value}" ]]; then
      printf '<已写入>'
    else
      printf '<空>'
    fi
  else
    printf '%s' "${value}"
  fi
}

scene_set_config_value() {
  local key="$1"
  local value="${2:-}"
  local secret="${3:-0}"
  local current_value=""

  current_value="$(config_read_value "${SCENE_CONFIG}" "${key}" || true)"
  if [[ "${current_value}" == "${value}" ]]; then
    return 0
  fi

  config_set_value "${SCENE_CONFIG}" "${key}" "${value}"
  scene_record_update "${key}" "$(scene_display_value "${value}" "${secret}")"
}

scene_current_or_default() {
  local key="$1"
  local default_value="${2:-}"
  local current_value=""

  current_value="$(config_read_value "${SCENE_CONFIG}" "${key}" || true)"
  printf '%s' "${current_value:-${default_value}}"
}

scene_enabled_flag_prompt() {
  local label="$1"
  local default_value="${2:-0}"
  prompt_menu_choice "${label}" "${default_value}" "1|开启" "0|关闭"
}

scene_default_provider_env_key() {
  local provider_name="${1:-openai}"
  local normalized="${provider_name^^}"
  normalized="${normalized//-/_}"
  normalized="${normalized// /_}"

  case "${provider_name}" in
    openai)
      printf 'OPENAI_API_KEY'
      ;;
    anthropic)
      printf 'ANTHROPIC_API_KEY'
      ;;
    google)
      printf 'GOOGLE_API_KEY'
      ;;
    *)
      printf '%s_API_KEY' "${normalized}"
      ;;
  esac
}

scene_default_opencode_model() {
  case "${1:-anthropic}" in
    anthropic)
      printf 'anthropic/claude-sonnet-4-6'
      ;;
    openai)
      printf 'openai/gpt-5.4'
      ;;
    google)
      printf 'google/gemini-2.5-pro'
      ;;
    ollama)
      printf 'ollama/qwen2.5-coder:latest'
      ;;
    *)
      printf 'anthropic/claude-sonnet-4-6'
      ;;
  esac
}

scene_generate_secret() {
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -hex 24
  else
    (
      set +o pipefail
      tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 48
    )
  fi
}

scene_needs_config_completion() {
  case "${SCENE_NAME}" in
    install|enhance|migrate)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

scene_render_guidance() {
  case "${SCENE_TOOL}:${SCENE_NAME}" in
    openclaw:install)
      help_print_note "如果你有公网 IP 和域名，选“公网域名”；脚本会按域名模式落 Nginx 和证书。"
      help_print_note "如果只有公网 IP，没有域名，选“公网 IP”；脚本会保留反代，但不会申请证书。"
      help_print_note "如果想通过 Tailscale 从外网访问，选 Tailscale 私网或公网入口。"
      ;;
    openclaw:enhance)
      help_print_note "这个场景会重放当前目标配置，适合切访问模式、补飞书、补长期记忆。"
      help_print_note "如果你准备从公网模式切到 Tailscale，这里会引导你补齐关键项。"
      ;;
    openclaw:migrate)
      help_print_note "这个场景适合接管已有 OpenClaw 环境，先看状态，再按你的目标配置对齐。"
      help_print_note "如果你不想影响现网，先确认访问模式、飞书和长期记忆目标项。"
      ;;
    codex:install|codex:enhance|codex:migrate)
      help_print_note "Codex 推荐两种接法：官方账号登录选 chatgpt，兼容网关或第三方 API 选 apikey。"
      help_print_note "如果你只是想把现有环境拉回最佳实践，选好模式和 provider 即可。"
      ;;
    claude-code:install|claude-code:enhance|claude-code:migrate)
      help_print_note "Claude Code 一般是两种接法：API Key 选 api-key，长令牌或代理 token 选 auth-token。"
      help_print_note "如果你走第三方代理，可把 Anthropic Base URL 一起补齐。"
      ;;
    gemini-cli:install|gemini-cli:enhance|gemini-cli:migrate)
      help_print_note "Gemini CLI 普通接入选 api-key，企业 GCP / Vertex AI 选 vertex-ai。"
      help_print_note "Vertex AI 场景需要补 Google Cloud Project 和 Location。"
      ;;
    opencode:install|opencode:enhance|opencode:migrate)
      help_print_note "OpenCode 会按默认 provider 生成配置；建议先明确你主要用 anthropic、openai、google 还是 ollama。"
      help_print_note "如果是本地模型，直接选 ollama 并填写本地地址。"
      ;;
  esac
}

scene_complete_common_mode() {
  local mode_value=""
  mode_value="$(prompt_menu_choice "最佳实践模式" "$(scene_current_or_default "MODE" "standard")" \
    "standard|standard     稳态基线，默认推荐" \
    "advanced|advanced     增强能力，适合主力使用" \
    "exploration|exploration  探索模式，能力更多")" || return 1
  scene_set_config_value "MODE" "${mode_value}" 0
}

scene_should_customize_advanced() {
  scene_confirm_default "是否调整模型 / 模式等进阶项" "0"
}

scene_current_openclaw_profile() {
  local access_mode=""
  local public_mode=""

  access_mode="$(scene_current_or_default "ACCESS_MODE" "standard")"
  public_mode="$(scene_current_or_default "PUBLIC_MODE" "public-domain")"

  case "${access_mode}:${public_mode}" in
    standard:public-domain)
      printf 'public-domain'
      ;;
    standard:public-ip)
      printf 'public-ip'
      ;;
    tailscale-private:*)
      printf 'tailscale-private'
      ;;
    tailscale-public:*)
      printf 'tailscale-public'
      ;;
    *)
      printf 'public-domain'
      ;;
  esac
}

scene_default_openclaw_profile_index() {
  case "${1:-public-domain}" in
    public-domain) printf '1' ;;
    public-ip) printf '2' ;;
    tailscale-private) printf '3' ;;
    tailscale-public) printf '4' ;;
    *) printf '1' ;;
  esac
}

scene_select_openclaw_profile() {
  local current_profile=""
  local answer=""

  current_profile="$(scene_current_openclaw_profile)"
  if [[ "${SCENE_ASSUME_YES}" == "1" ]]; then
    SCENE_OPENCLAW_PROFILE="${current_profile}"
    return 0
  fi

  answer="$(prompt_menu_choice "请选择部署形态" "$(scene_default_openclaw_profile_index "${current_profile}")" \
    "1|公网域名       有公网 IP + 域名，自动 Nginx + 证书" \
    "2|公网 IP         有公网 IP，无域名" \
    "3|Tailscale 私网  访问端需安装 Tailscale 客户端" \
    "4|Tailscale 公网  通过 Tailscale 公网入口访问")" || return 1

  case "${answer}" in
    1) SCENE_OPENCLAW_PROFILE="public-domain" ;;
    2) SCENE_OPENCLAW_PROFILE="public-ip" ;;
    3) SCENE_OPENCLAW_PROFILE="tailscale-private" ;;
    4) SCENE_OPENCLAW_PROFILE="tailscale-public" ;;
  esac
}

scene_complete_codex_config() {
  local auth_method=""
  local default_model=""
  local provider_mode=""
  local model_provider=""
  local provider_name=""
  local api_base_url=""
  local provider_env_key=""
  local provider_api_value=""
  local customize_advanced="0"

  auth_method="$(prompt_menu_choice "认证方式" "$(scene_current_or_default "AUTH_METHOD" "chatgpt")" \
    "chatgpt|chatgpt  使用官方账号登录" \
    "apikey|apikey   使用 API Key / 兼容网关")" || return 1
  scene_set_config_value "AUTH_METHOD" "${auth_method}" 0

  if scene_should_customize_advanced; then
    customize_advanced="1"
    default_model="$(prompt_with_default "默认模型" "$(scene_current_or_default "DEFAULT_MODEL" "gpt-5.4")")" || return 1
    scene_set_config_value "DEFAULT_MODEL" "${default_model}" 0
    scene_complete_common_mode || return 1
  fi

  if [[ "${auth_method}" == "chatgpt" ]]; then
    scene_set_config_value "MODEL_PROVIDER" "openai" 0
    scene_set_config_value "PROVIDER_NAME" "openai" 0
    scene_set_config_value "PROVIDER_ENV_KEY" "OPENAI_API_KEY" 0
    scene_set_config_value "PROVIDER_API_VALUE" "" 1
    scene_set_config_value "API_BASE_URL" "" 0
    scene_record_note "Codex 选择 chatgpt 模式后，后续仍需在终端完成登录。"
    return 0
  fi

  if [[ "${customize_advanced}" == "1" ]]; then
    provider_mode="$(prompt_menu_choice "Provider 类型" "openai" \
      "openai|openai  官方或 OpenAI 兼容网关" \
      "custom|custom  自定义 provider 名称")" || return 1

    if [[ "${provider_mode}" == "openai" ]]; then
      model_provider="openai"
      provider_name="openai"
      api_base_url="$(prompt_optional_with_default "API Base URL（官方默认可留空）" "$(scene_current_or_default "API_BASE_URL" "")")" || return 1
      provider_env_key="OPENAI_API_KEY"
    else
      model_provider="$(prompt_with_default "自定义 provider 标识" "$(scene_current_or_default "MODEL_PROVIDER" "custom-provider")")" || return 1
      provider_name="$(prompt_with_default "Provider 名称" "$(scene_current_or_default "PROVIDER_NAME" "${model_provider}")")" || return 1
      api_base_url="$(prompt_with_default "API Base URL" "$(scene_current_or_default "API_BASE_URL" "")")" || return 1
      provider_env_key="$(prompt_with_default "Provider 环境变量名" "$(scene_current_or_default "PROVIDER_ENV_KEY" "$(scene_default_provider_env_key "${model_provider}")")")" || return 1
    fi

    scene_set_config_value "MODEL_PROVIDER" "${model_provider}" 0
    scene_set_config_value "PROVIDER_NAME" "${provider_name}" 0
    scene_set_config_value "API_BASE_URL" "${api_base_url}" 0
    scene_set_config_value "PROVIDER_ENV_KEY" "${provider_env_key}" 0
  else
    model_provider="$(scene_current_or_default "MODEL_PROVIDER" "openai")"
    provider_name="$(scene_current_or_default "PROVIDER_NAME" "${model_provider}")"
    provider_env_key="$(scene_current_or_default "PROVIDER_ENV_KEY" "$(scene_default_provider_env_key "${model_provider}")")"
  fi
  provider_api_value="$(prompt_secret_with_default "Provider API Key" "$(scene_current_or_default "PROVIDER_API_VALUE" "")" 1)" || return 1
  scene_set_config_value "PROVIDER_API_VALUE" "${provider_api_value}" 1
}

scene_complete_claude_code_config() {
  local auth_mode=""
  local default_model=""
  local api_key=""
  local auth_token=""
  local base_url=""
  local customize_advanced="0"

  auth_mode="$(prompt_menu_choice "认证方式" "$(scene_current_or_default "AUTH_MODE" "api-key")" \
    "api-key|api-key      官方或兼容网关 API Key" \
    "auth-token|auth-token   长令牌 / Bearer Token")" || return 1

  scene_set_config_value "AUTH_MODE" "${auth_mode}" 0
  if scene_should_customize_advanced; then
    customize_advanced="1"
    default_model="$(prompt_with_default "默认模型" "$(scene_current_or_default "DEFAULT_MODEL" "claude-sonnet-4-6")")" || return 1
    scene_set_config_value "DEFAULT_MODEL" "${default_model}" 0
    scene_complete_common_mode || return 1
    base_url="$(prompt_optional_with_default "Anthropic Base URL（代理可填，可留空）" "$(scene_current_or_default "ANTHROPIC_BASE_URL" "")")" || return 1
    scene_set_config_value "ANTHROPIC_BASE_URL" "${base_url}" 0
  fi

  case "${auth_mode}" in
    api-key)
      api_key="$(prompt_secret_with_default "ANTHROPIC_API_KEY" "$(scene_current_or_default "ANTHROPIC_API_KEY" "")" 1)" || return 1
      scene_set_config_value "ANTHROPIC_API_KEY" "${api_key}" 1
      scene_set_config_value "ANTHROPIC_AUTH_TOKEN" "" 1
      ;;
    auth-token)
      auth_token="$(prompt_secret_with_default "ANTHROPIC_AUTH_TOKEN" "$(scene_current_or_default "ANTHROPIC_AUTH_TOKEN" "")" 1)" || return 1
      scene_set_config_value "ANTHROPIC_AUTH_TOKEN" "${auth_token}" 1
      scene_set_config_value "ANTHROPIC_API_KEY" "" 1
      ;;
  esac
}

scene_complete_gemini_config() {
  local auth_mode=""
  local default_model=""
  local api_key_default=""
  local api_key=""
  local cloud_project=""
  local cloud_location=""
  local customize_advanced="0"

  auth_mode="$(prompt_menu_choice "认证方式" "$(scene_current_or_default "AUTH_MODE" "api-key")" \
    "api-key|api-key      普通 API Key 接入" \
    "vertex-ai|vertex-ai    Google Vertex AI")" || return 1

  scene_set_config_value "AUTH_MODE" "${auth_mode}" 0
  if scene_should_customize_advanced; then
    customize_advanced="1"
    default_model="$(prompt_with_default "默认模型" "$(scene_current_or_default "DEFAULT_MODEL" "gemini-2.5-pro")")" || return 1
    scene_set_config_value "DEFAULT_MODEL" "${default_model}" 0
    scene_complete_common_mode || return 1
  fi

  case "${auth_mode}" in
    api-key)
      api_key_default="$(scene_current_or_default "GEMINI_API_KEY" "")"
      if [[ -z "${api_key_default}" ]]; then
        api_key_default="$(scene_current_or_default "GOOGLE_API_KEY" "")"
      fi
      api_key="$(prompt_secret_with_default "Gemini API Key" "${api_key_default}" 1)" || return 1
      scene_set_config_value "GEMINI_API_KEY" "${api_key}" 1
      scene_set_config_value "GOOGLE_API_KEY" "" 1
      scene_set_config_value "GOOGLE_GENAI_USE_VERTEXAI" "false" 0
      ;;
    vertex-ai)
      cloud_project="$(prompt_with_default "Google Cloud Project" "$(scene_current_or_default "GOOGLE_CLOUD_PROJECT" "")")" || return 1
      if [[ "${customize_advanced}" == "1" ]]; then
        cloud_location="$(prompt_with_default "Google Cloud Location" "$(scene_current_or_default "GOOGLE_CLOUD_LOCATION" "us-central1")")" || return 1
      else
        cloud_location="$(scene_current_or_default "GOOGLE_CLOUD_LOCATION" "us-central1")"
      fi
      scene_set_config_value "GOOGLE_CLOUD_PROJECT" "${cloud_project}" 0
      scene_set_config_value "GOOGLE_CLOUD_LOCATION" "${cloud_location}" 0
      scene_set_config_value "GOOGLE_GENAI_USE_VERTEXAI" "true" 0
      scene_set_config_value "GEMINI_API_KEY" "" 1
      scene_set_config_value "GOOGLE_API_KEY" "" 1
      ;;
  esac
}

scene_complete_opencode_config() {
  local provider_default=""
  local default_model=""
  local current_provider_default=""
  local openai_api_key=""
  local anthropic_api_key=""
  local google_api_key=""
  local ollama_base_url=""
  local customize_advanced="0"

  current_provider_default="$(scene_current_or_default "PROVIDER_DEFAULT" "anthropic")"
  provider_default="$(prompt_menu_choice "默认 provider" "$(scene_current_or_default "PROVIDER_DEFAULT" "anthropic")" \
    "anthropic|anthropic  Claude 系列" \
    "openai|openai      OpenAI / 兼容网关" \
    "google|google      Gemini" \
    "ollama|ollama      本地模型")" || return 1

  scene_set_config_value "PROVIDER_DEFAULT" "${provider_default}" 0
  if scene_should_customize_advanced; then
    customize_advanced="1"
    default_model="$(prompt_with_default "默认模型" "$(scene_current_or_default "DEFAULT_MODEL" "$(scene_default_opencode_model "${provider_default}")")")" || return 1
    scene_set_config_value "DEFAULT_MODEL" "${default_model}" 0
    scene_complete_common_mode || return 1
  elif [[ "${current_provider_default}" != "${provider_default}" ]]; then
    scene_set_config_value "DEFAULT_MODEL" "$(scene_default_opencode_model "${provider_default}")" 0
  fi

  case "${provider_default}" in
    anthropic)
      anthropic_api_key="$(prompt_secret_with_default "ANTHROPIC_API_KEY" "$(scene_current_or_default "ANTHROPIC_API_KEY" "")" 1)" || return 1
      scene_set_config_value "ANTHROPIC_API_KEY" "${anthropic_api_key}" 1
      scene_set_config_value "OPENAI_API_KEY" "" 1
      scene_set_config_value "GOOGLE_GENERATIVEAI_API_KEY" "" 1
      ;;
    openai)
      openai_api_key="$(prompt_secret_with_default "OPENAI_API_KEY" "$(scene_current_or_default "OPENAI_API_KEY" "")" 1)" || return 1
      scene_set_config_value "OPENAI_API_KEY" "${openai_api_key}" 1
      scene_set_config_value "ANTHROPIC_API_KEY" "" 1
      scene_set_config_value "GOOGLE_GENERATIVEAI_API_KEY" "" 1
      ;;
    google)
      google_api_key="$(prompt_secret_with_default "GOOGLE_GENERATIVEAI_API_KEY" "$(scene_current_or_default "GOOGLE_GENERATIVEAI_API_KEY" "")" 1)" || return 1
      scene_set_config_value "GOOGLE_GENERATIVEAI_API_KEY" "${google_api_key}" 1
      scene_set_config_value "OPENAI_API_KEY" "" 1
      scene_set_config_value "ANTHROPIC_API_KEY" "" 1
      ;;
    ollama)
      if [[ "${customize_advanced}" == "1" ]]; then
        ollama_base_url="$(prompt_with_default "Ollama Base URL" "$(scene_current_or_default "OLLAMA_BASE_URL" "http://localhost:11434")")" || return 1
      else
        ollama_base_url="$(scene_current_or_default "OLLAMA_BASE_URL" "http://localhost:11434")"
      fi
      scene_set_config_value "OLLAMA_BASE_URL" "${ollama_base_url}" 0
      scene_set_config_value "OPENAI_API_KEY" "" 1
      scene_set_config_value "ANTHROPIC_API_KEY" "" 1
      scene_set_config_value "GOOGLE_GENERATIVEAI_API_KEY" "" 1
      ;;
  esac
}

scene_complete_openclaw_config() {
  local access_profile=""
  local access_mode=""
  local public_mode=""
  local domain=""
  local letsencrypt_email=""
  local gateway_token=""
  local enable_feishu=""
  local feishu_app_id=""
  local feishu_app_secret=""
  local feishu_verification_token=""
  local feishu_encrypt_key=""
  local tailscale_auth_key=""
  local tailscale_hostname=""
  local enable_memory_plugin=""
  local memory_embedding_api_key=""

  scene_select_openclaw_profile || return 1
  access_profile="${SCENE_OPENCLAW_PROFILE}"
  case "${access_profile}" in
    public-domain)
      access_mode="standard"
      public_mode="public-domain"
      scene_record_note "已选择：公网域名模式。会走 Nginx 反代，并按域名申请证书。"
      ;;
    public-ip)
      access_mode="standard"
      public_mode="public-ip"
      scene_record_note "已选择：公网 IP 模式。会走 Nginx 反代，但不会申请证书。"
      ;;
    tailscale-private)
      access_mode="tailscale-private"
      public_mode="$(scene_current_or_default "PUBLIC_MODE" "public-domain")"
      scene_record_note "已选择：Tailscale 私网模式。访问端需要安装并登录 Tailscale 客户端。"
      ;;
    tailscale-public)
      access_mode="tailscale-public"
      public_mode="$(scene_current_or_default "PUBLIC_MODE" "public-domain")"
      scene_record_note "已选择：Tailscale 公网入口模式。访问端通常不需要额外客户端。"
      ;;
  esac

  scene_set_config_value "ACCESS_MODE" "${access_mode}" 0

  case "${access_mode}" in
    standard)
      scene_set_config_value "PUBLIC_MODE" "${public_mode}" 0
      if [[ "${public_mode}" == "public-domain" ]]; then
        domain="$(prompt_with_default "域名" "$(scene_current_or_default "DOMAIN" "")")" || return 1
        letsencrypt_email="$(prompt_with_default "Let's Encrypt 邮箱" "$(scene_current_or_default "LETSENCRYPT_EMAIL" "")")" || return 1
        scene_set_config_value "DOMAIN" "${domain}" 0
        scene_set_config_value "LETSENCRYPT_EMAIL" "${letsencrypt_email}" 0
      else
        scene_set_config_value "DOMAIN" "" 0
        scene_set_config_value "LETSENCRYPT_EMAIL" "" 0
      fi
      scene_set_config_value "TAILSCALE_AUTH_KEY" "" 1
      ;;
    tailscale-private|tailscale-public)
      tailscale_auth_key="$(prompt_secret_with_default "Tailscale Auth Key" "$(scene_current_or_default "TAILSCALE_AUTH_KEY" "")" 1)" || return 1
      tailscale_hostname="$(prompt_with_default "Tailscale 主机名" "$(scene_current_or_default "TAILSCALE_HOSTNAME" "openclaw-node")")" || return 1
      scene_set_config_value "TAILSCALE_AUTH_KEY" "${tailscale_auth_key}" 1
      scene_set_config_value "TAILSCALE_HOSTNAME" "${tailscale_hostname}" 0
      ;;
  esac

  gateway_token="$(scene_current_or_default "GATEWAY_TOKEN" "")"
  if [[ -z "${gateway_token}" || "${gateway_token}" == "replace-with-strong-token" ]]; then
    gateway_token="$(scene_generate_secret)"
    scene_record_note "已自动生成新的 GATEWAY_TOKEN。"
  fi
  scene_set_config_value "GATEWAY_TOKEN" "${gateway_token}" 1

  enable_feishu="$(scene_enabled_flag_prompt "是否开启飞书接入" "$(scene_current_or_default "ENABLE_FEISHU" "0")")" || return 1
  scene_set_config_value "ENABLE_FEISHU" "${enable_feishu}" 0
  if [[ "${enable_feishu}" == "1" ]]; then
    feishu_app_id="$(prompt_with_default "FEISHU_APP_ID" "$(scene_current_or_default "FEISHU_APP_ID" "")")" || return 1
    feishu_app_secret="$(prompt_secret_with_default "FEISHU_APP_SECRET" "$(scene_current_or_default "FEISHU_APP_SECRET" "")" 1)" || return 1
    feishu_verification_token="$(prompt_secret_with_default "FEISHU_VERIFICATION_TOKEN" "$(scene_current_or_default "FEISHU_VERIFICATION_TOKEN" "")" 1)" || return 1
    feishu_encrypt_key="$(prompt_secret_with_default "FEISHU_ENCRYPT_KEY" "$(scene_current_or_default "FEISHU_ENCRYPT_KEY" "")" 1)" || return 1
    scene_set_config_value "FEISHU_APP_ID" "${feishu_app_id}" 0
    scene_set_config_value "FEISHU_APP_SECRET" "${feishu_app_secret}" 1
    scene_set_config_value "FEISHU_VERIFICATION_TOKEN" "${feishu_verification_token}" 1
    scene_set_config_value "FEISHU_ENCRYPT_KEY" "${feishu_encrypt_key}" 1
  fi

  enable_memory_plugin="$(scene_enabled_flag_prompt "是否开启长期记忆插件" "$(scene_current_or_default "ENABLE_MEMORY_PLUGIN" "1")")" || return 1
  scene_set_config_value "ENABLE_MEMORY_PLUGIN" "${enable_memory_plugin}" 0
  if [[ "${enable_memory_plugin}" == "1" ]]; then
    scene_set_config_value "MEMORY_PLUGIN" "$(scene_current_or_default "MEMORY_PLUGIN" "memory-lancedb-pro")" 0
    memory_embedding_api_key="$(prompt_secret_with_default "MEMORY_EMBEDDING_API_KEY" "$(scene_current_or_default "MEMORY_EMBEDDING_API_KEY" "")" 1)" || return 1
    scene_set_config_value "MEMORY_EMBEDDING_API_KEY" "${memory_embedding_api_key}" 1
  else
    scene_set_config_value "MEMORY_EMBEDDING_API_KEY" "" 1
  fi
}

scenario_complete_config() {
  SCENE_UPDATE_LINES=()
  SCENE_NOTE_LINES=()

  scene_needs_config_completion || return 0

  case "${SCENE_TOOL}" in
    codex)
      scene_complete_codex_config
      ;;
    claude-code)
      scene_complete_claude_code_config
      ;;
    gemini-cli)
      scene_complete_gemini_config
      ;;
    opencode)
      scene_complete_opencode_config
      ;;
    openclaw)
      scene_complete_openclaw_config
      ;;
  esac
}

scene_render_config_completion() {
  local entry=""
  local key=""
  local value=""

  help_print_section "配置补齐"
  help_print_rule

  if [[ "${#SCENE_UPDATE_LINES[@]}" == "0" ]]; then
    help_print_note "当前配置已满足该场景的关键项。"
  else
    for entry in "${SCENE_UPDATE_LINES[@]}"; do
      key="${entry%%$'\t'*}"
      value="${entry#*$'\t'}"
      help_print_entry "${key}" "${value}"
    done
  fi

  for entry in "${SCENE_NOTE_LINES[@]}"; do
    help_print_note "${entry}"
  done
}

select_tool_interactive() {
  local answer=""

  if [[ -n "${SCENE_TOOL}" ]]; then
    return 0
  fi
  if [[ "${SCENE_ASSUME_YES}" == "1" ]]; then
    log_error "scenario 使用 --yes 时必须提供 --tool-name"
    return 1
  fi

  help_init_colors
  help_print_title "Scenario"
  help_print_strong_rule
  scene_start_step "选择工具" "先确定这次要安装、增强或接管的是哪个工具。"
  answer="$(prompt_menu_choice "请选择工具" "3" \
    "1|openclaw       通用 AI 助手服务" \
    "2|claude-code    Claude Code" \
    "3|codex          OpenAI Codex" \
    "4|gemini-cli     Gemini CLI" \
    "5|opencode       OpenCode")" || return 1
  case "${answer}" in
    1) SCENE_TOOL="openclaw" ;;
    2) SCENE_TOOL="claude-code" ;;
    3) SCENE_TOOL="codex" ;;
    4) SCENE_TOOL="gemini-cli" ;;
    5) SCENE_TOOL="opencode" ;;
  esac
  return 0
}

validate_scene_name() {
  case "${1:-}" in
    install|enhance|migrate|project|status)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

select_scene_interactive() {
  local answer=""

  if [[ -n "${SCENE_NAME}" ]]; then
    return 0
  fi
  if [[ "${SCENE_ASSUME_YES}" == "1" ]]; then
    log_error "scenario 使用 --yes 时必须提供 --scene"
    return 1
  fi

  scene_start_step "选择场景" "按你当前的目标选择最贴近的场景。"
  if [[ "${SCENE_TOOL}" == "openclaw" ]]; then
    answer="$(prompt_menu_choice "请选择场景" "1" \
      "1|install  首次安装并应用配置" \
      "2|enhance  已安装后增强或切换配置" \
      "3|migrate  接管已有环境并对齐" \
      "4|status   先看当前状态")" || return 1
    case "${answer}" in
      1) SCENE_NAME="install" ;;
      2) SCENE_NAME="enhance" ;;
      3) SCENE_NAME="migrate" ;;
      4) SCENE_NAME="status" ;;
    esac
  else
    answer="$(prompt_menu_choice "请选择场景" "1" \
      "1|install  首次安装并应用最佳实践" \
      "2|enhance  已安装后增强或改模式" \
      "3|migrate  接管已有环境并对齐" \
      "4|project  只初始化项目模板" \
      "5|status   先看当前状态")" || return 1
    case "${answer}" in
      1) SCENE_NAME="install" ;;
      2) SCENE_NAME="enhance" ;;
      3) SCENE_NAME="migrate" ;;
      4) SCENE_NAME="project" ;;
      5) SCENE_NAME="status" ;;
    esac
  fi
  return 0
}

scene_prepare_inputs() {
  local default_config=""

  help_init_colors
  SCENE_WIZARD_STEP=1
  select_tool_interactive || return 1
  select_scene_interactive || return 1

  validate_scene_name "${SCENE_NAME}" || {
    log_error "不支持的场景：${SCENE_NAME}"
    scene_usage
    return 1
  }

  if [[ "${SCENE_TOOL}" == "openclaw" && "${SCENE_NAME}" == "project" ]]; then
    log_error "openclaw 不支持 project 场景"
    return 1
  fi

  default_config="$(resolve_script_relative_path "$(default_config_hint "${SCENE_TOOL}")")"
  if [[ -z "${SCENE_CONFIG}" ]]; then
    scene_start_step "配置文件" "默认会使用工具目录下的 local.conf；你也可以改成自己的路径。"
    SCENE_CONFIG="$(prompt_with_default "配置文件" "${default_config}")"
  fi
  ensure_scene_config_exists || return 1
  if scene_needs_config_completion; then
    scene_start_step "关键配置" "按当前场景补齐关键项，脚本会自动写回配置文件。"
    scene_render_guidance
  fi
  scenario_complete_config || return 1

  if [[ "${SCENE_NAME}" == "project" ]]; then
    scene_start_step "项目路径" "项目模板会写到你指定的项目目录。"
    SCENE_PATH="$(prompt_with_default "项目路径" "${SCENE_PATH:-/workspace/project}")"
  fi

  if [[ "${SCENE_NAME}" == "install" && "${SCENE_TOOL}" != "openclaw" ]]; then
    if [[ -n "${SCENE_PATH}" ]]; then
      SCENE_INCLUDE_PROJECT="1"
    else
      scene_start_step "项目模板" "安装完成后，可以顺手把项目目录初始化成推荐结构。"
      if scene_confirm_default "是否同时初始化项目模板" "0"; then
        SCENE_INCLUDE_PROJECT="1"
        SCENE_PATH="$(prompt_with_default "项目路径" "/workspace/project")"
      fi
    fi
  fi

  if [[ "${SCENE_NAME}" == "project" && -z "${SCENE_PATH}" ]]; then
    log_error "project 场景必须提供 --path"
    return 1
  fi
}

scene_run_step() {
  local mode="$1"
  local label="$2"
  shift 2
  local -a cmd=( "$@" )
  local display="${PROGRAM_NAME}"
  local part=""

  for part in "${cmd[@]}"; do
    printf -v display '%s %q' "${display}" "${part}"
  done

  if [[ "${mode}" == "plan" ]]; then
    help_print_step "${SCENE_STEP_INDEX}" "${display}" "${label}"
    SCENE_STEP_INDEX=$((SCENE_STEP_INDEX + 1))
    return 0
  fi

  log_info "${label}: ${display}"
  bash "${SCRIPT_DIR}/manage.sh" "${cmd[@]}"
}

scene_dispatch_steps() {
  local mode="$1"

  case "${SCENE_NAME}" in
    install)
      scene_run_step "${mode}" "安装并应用配置" service install --tool-name "${SCENE_TOOL}" --config "${SCENE_CONFIG}" --yes || return 1
      scene_run_step "${mode}" "安装后验收" service check --tool-name "${SCENE_TOOL}" --config "${SCENE_CONFIG}" || return 1
      if [[ "${SCENE_INCLUDE_PROJECT}" == "1" ]]; then
        scene_run_step "${mode}" "初始化项目模板" config init --tool-name "${SCENE_TOOL}" --config "${SCENE_CONFIG}" --scope project --path "${SCENE_PATH}" --yes || return 1
      fi
      ;;
    enhance)
      scene_run_step "${mode}" "重放配置" service configure --tool-name "${SCENE_TOOL}" --config "${SCENE_CONFIG}" --yes || return 1
      scene_run_step "${mode}" "增强后检查" service check --tool-name "${SCENE_TOOL}" --config "${SCENE_CONFIG}" || return 1
      ;;
    migrate)
      scene_run_step "${mode}" "先看当前状态" service report --tool-name "${SCENE_TOOL}" --config "${SCENE_CONFIG}" || return 1
      scene_run_step "${mode}" "接管并对齐" service configure --tool-name "${SCENE_TOOL}" --config "${SCENE_CONFIG}" --yes || return 1
      scene_run_step "${mode}" "接管后检查" service check --tool-name "${SCENE_TOOL}" --config "${SCENE_CONFIG}" || return 1
      ;;
    project)
      scene_run_step "${mode}" "初始化项目模板" config init --tool-name "${SCENE_TOOL}" --config "${SCENE_CONFIG}" --scope project --path "${SCENE_PATH}" --yes || return 1
      ;;
    status)
      scene_run_step "${mode}" "状态概览" service report --tool-name "${SCENE_TOOL}" --config "${SCENE_CONFIG}" || return 1
      scene_run_step "${mode}" "详细检查" service check --tool-name "${SCENE_TOOL}" --config "${SCENE_CONFIG}" || return 1
      ;;
  esac
}

run_scene_command() {
  scene_prepare_inputs || return 1

  help_init_colors
  help_print_title "Scenario: ${SCENE_NAME}"
  help_print_strong_rule
  help_print_context "工具" "${SCENE_TOOL}"
  help_print_context "配置文件" "${SCENE_CONFIG}"
  if [[ -n "${SCENE_PATH}" ]]; then
    help_print_context "项目路径" "${SCENE_PATH}"
  fi
  if scene_needs_config_completion; then
    scene_render_config_completion
  fi
  help_print_section "执行计划"
  help_print_rule
  SCENE_STEP_INDEX=1
  scene_dispatch_steps "plan" || return 1

  scene_start_step "执行确认" "确认后会按上面的计划顺序执行。"
  scene_confirm_default "执行以上步骤" "1" || {
    log_warn "已取消执行。"
    return 1
  }

  scene_dispatch_steps "run"
}

default_config_hint() {
  case "${1:-}" in
    openclaw)
      printf './general-agents/openclaw/local.conf'
      ;;
    claude-code|codex|gemini-cli|opencode)
      printf './coding-agents/%s/local.conf' "${1}"
      ;;
    *)
      printf './<tool>/local.conf'
      ;;
  esac
}

default_config_example_hint() {
  case "${1:-}" in
    openclaw)
      printf './general-agents/openclaw/conf.example'
      ;;
    claude-code|codex|gemini-cli|opencode)
      printf './coding-agents/%s/conf.example' "${1}"
      ;;
    *)
      printf './<tool>/conf.example'
      ;;
  esac
}

resolve_script_relative_path() {
  local raw_path="${1:-}"
  case "${raw_path}" in
    ./*)
      printf '%s/%s' "${SCRIPT_DIR}" "${raw_path#./}"
      ;;
    *)
      printf '%s' "${raw_path}"
      ;;
  esac
}

ensure_scene_config_exists() {
  local example_path=""

  if [[ -f "${SCENE_CONFIG}" ]]; then
    return 0
  fi

  example_path="$(resolve_script_relative_path "$(default_config_example_hint "${SCENE_TOOL}")")"
  if [[ ! -f "${example_path}" ]]; then
    log_error "配置文件不存在：${SCENE_CONFIG}"
    log_error "且找不到配置样例：${example_path}"
    return 1
  fi

  if [[ "${SCENE_ASSUME_YES}" != "1" ]]; then
    scene_start_step "创建配置文件" "当前配置文件不存在；可以从对应工具的 conf.example 自动生成。"
    scene_confirm_default "是否从样例创建配置文件" "1" || {
      log_error "未创建配置文件，无法继续执行场景。"
      return 1
    }
  fi

  mkdir -p "$(dirname "${SCENE_CONFIG}")"
  cp "${example_path}" "${SCENE_CONFIG}"
  log_info "已从样例创建配置文件：${SCENE_CONFIG}"
}

should_announce_forward() {
  local arg=""
  for arg in "${FORWARD_ARGS[@]:-}"; do
    case "${arg}" in
      --help|-h|help)
        return 1
        ;;
    esac
  done
  return 0
}

guide_start_usage() {
  help_init_colors
  help_print_title "Quickstart"
  help_print_strong_rule
  help_print_section "用法"
  help_print_rule
  help_print_command "${PROGRAM_NAME} guide start --tool-name codex"
  help_print_command "${PROGRAM_NAME} guide start --tool-name openclaw --scene install"
  help_print_command "${PROGRAM_NAME} guide start --tool-name codex --scene project --path /workspace/project"
  help_print_section "参数"
  help_print_rule
  help_print_entry "--tool-name <tool>" "目标工具名"
  help_print_entry "--scene <scene>" "install|enhance|migrate|project|all"
  help_print_entry "--config <config>" "可选，自定义配置文件路径"
  help_print_entry "--path <path>" "项目路径，默认 /workspace/project"
}

render_guide_scene_install() {
  local tool_name="$1"
  local config_hint="$2"
  local path_hint="$3"

  help_print_section "场景：从零安装"
  help_print_command "${PROGRAM_NAME} service install --tool-name ${tool_name} --config ${config_hint} --yes" "全局安装并应用推荐配置"
  case "${tool_name}" in
    openclaw)
      help_print_note "OpenClaw 一般先到这一步；需要再排查时执行 service report 或 service check"
      ;;
    *)
      help_print_command "${PROGRAM_NAME} config init --tool-name ${tool_name} --config ${config_hint} --scope project --path ${path_hint} --yes" "需要项目模板时再执行第 2 条"
      ;;
  esac
}

render_guide_scene_enhance() {
  local tool_name="$1"
  local config_hint="$2"

  help_print_section "场景：已装后增强"
  help_print_command "${PROGRAM_NAME} service configure --tool-name ${tool_name} --config ${config_hint} --yes" "修改配置后重放，适合切模式、补增强、改接入"
}

render_guide_scene_migrate() {
  local tool_name="$1"
  local config_hint="$2"

  help_print_section "场景：迁移接管"
  help_print_command "${PROGRAM_NAME} service configure --tool-name ${tool_name} --config ${config_hint} --yes" "把已有环境拉到当前推荐基线"
  help_print_command "${PROGRAM_NAME} service check --tool-name ${tool_name} --config ${config_hint}" "确认是否达到推荐基线"
}

render_guide_scene_project() {
  local tool_name="$1"
  local config_hint="$2"
  local path_hint="$3"

  help_print_section "场景：项目模板"
  case "${tool_name}" in
    openclaw)
      help_print_note "OpenClaw 主要是服务部署工具，通常不需要单独的项目模板场景。"
      ;;
    *)
      help_print_command "${PROGRAM_NAME} config init --tool-name ${tool_name} --config ${config_hint} --scope project --path ${path_hint} --yes" "初始化项目级最佳实践模板"
      ;;
  esac
}

render_guide_start() {
  local tool_name="${TARGET_TOOL:-}"
  local scene_name="${GUIDE_SCENE:-all}"
  local config_hint="${GUIDE_CONFIG:-}"
  local path_hint="${GUIDE_PATH:-/workspace/project}"

  if [[ -z "${tool_name}" ]]; then
    guide_start_usage
    help_print_section "已接入工具"
    help_print_entry "coding-agents" "claude-code, codex, gemini-cli, opencode"
    help_print_entry "general-agents" "openclaw"
    return 0
  fi

  config_hint="${config_hint:-$(default_config_hint "${tool_name}")}"
  help_init_colors
  help_print_title "Quickstart: ${tool_name}"
  help_print_strong_rule
  help_print_context "配置文件" "${config_hint}"

  case "${scene_name}" in
    install)
      render_guide_scene_install "${tool_name}" "${config_hint}" "${path_hint}"
      ;;
    enhance)
      render_guide_scene_enhance "${tool_name}" "${config_hint}"
      ;;
    migrate)
      render_guide_scene_migrate "${tool_name}" "${config_hint}"
      ;;
    project)
      render_guide_scene_project "${tool_name}" "${config_hint}" "${path_hint}"
      ;;
    all)
      render_guide_scene_install "${tool_name}" "${config_hint}" "${path_hint}"
      render_guide_scene_enhance "${tool_name}" "${config_hint}"
      render_guide_scene_migrate "${tool_name}" "${config_hint}"
      render_guide_scene_project "${tool_name}" "${config_hint}" "${path_hint}"
      ;;
    *)
      log_error "不支持的 --scene：${scene_name}"
      guide_start_usage
      return 1
      ;;
  esac
}

resolve_tool_entry() {
  case "${1}" in
    openclaw)
      printf '%s\n' "${SCRIPT_DIR}/general-agents/openclaw/manage.sh"
      ;;
    claude-code|codex|gemini-cli|opencode)
      printf '%s\n' "${SCRIPT_DIR}/coding-agents/${1}/manage.sh"
      ;;
    *)
      return 1
      ;;
  esac
}

list_tools() {
  cat <<EOF
openclaw
claude-code
codex
gemini-cli
opencode
EOF
}

if [[ $# -eq 0 ]]; then
  usage
  exit 0
fi

if [[ "${COMMAND_GROUP}" == "--help" || "${COMMAND_GROUP}" == "-h" || "${COMMAND_GROUP}" == "help" ]]; then
  usage
  exit 0
fi

if [[ "${COMMAND_GROUP}" == "scenario" ]]; then
  if [[ "${COMMAND_ACTION}" == "--help" || "${COMMAND_ACTION}" == "-h" || "${COMMAND_ACTION}" == "help" ]]; then
    scene_usage
    exit 0
  fi

  if [[ "${COMMAND_ACTION}" == "run" ]]; then
    if [[ $# -ge 2 ]]; then
      shift 2
    fi
  else
    if [[ $# -ge 1 ]]; then
      shift 1
    fi
  fi

  while [[ $# -gt 0 ]]; do
    case "${1}" in
      --tool-name)
        [[ $# -ge 2 ]] || {
          log_error "缺少 --tool-name 的值"
          exit 1
        }
        SCENE_TOOL="${2}"
        shift 2
        ;;
      --scene)
        [[ $# -ge 2 ]] || {
          log_error "缺少 --scene 的值"
          exit 1
        }
        SCENE_NAME="${2}"
        shift 2
        ;;
      --config)
        [[ $# -ge 2 ]] || {
          log_error "缺少 --config 的值"
          exit 1
        }
        SCENE_CONFIG="${2}"
        shift 2
        ;;
      --path)
        [[ $# -ge 2 ]] || {
          log_error "缺少 --path 的值"
          exit 1
        }
        SCENE_PATH="${2}"
        shift 2
        ;;
      --yes)
        SCENE_ASSUME_YES=1
        shift
        ;;
      --help|-h|help)
        scene_usage
        exit 0
        ;;
      *)
        log_error "不支持的参数：${1}"
        scene_usage
        exit 1
        ;;
    esac
  done

  run_scene_command
  exit $?
fi

if [[ "${COMMAND_GROUP}" == "guide" && "${COMMAND_ACTION}" == "start" ]]; then
  if [[ $# -ge 2 ]]; then
    shift 2
  fi

  while [[ $# -gt 0 ]]; do
    case "${1}" in
      --tool-name)
        [[ $# -ge 2 ]] || {
          log_error "缺少 --tool-name 的值"
          exit 1
        }
        TARGET_TOOL="${2}"
        shift 2
        ;;
      --scene)
        [[ $# -ge 2 ]] || {
          log_error "缺少 --scene 的值"
          exit 1
        }
        GUIDE_SCENE="${2}"
        shift 2
        ;;
      --config)
        [[ $# -ge 2 ]] || {
          log_error "缺少 --config 的值"
          exit 1
        }
        GUIDE_CONFIG="${2}"
        shift 2
        ;;
      --path)
        [[ $# -ge 2 ]] || {
          log_error "缺少 --path 的值"
          exit 1
        }
        GUIDE_PATH="${2}"
        shift 2
        ;;
      --help|-h|help)
        guide_start_usage
        exit 0
        ;;
      *)
        log_error "不支持的参数：${1}"
        guide_start_usage
        exit 1
        ;;
    esac
  done

  render_guide_start
  exit $?
fi

if [[ "${COMMAND_GROUP}" == "tool" && "${COMMAND_ACTION}" == "list" ]]; then
  list_tools
  exit 0
fi

if [[ "${COMMAND_GROUP}" == "tool" && "${COMMAND_ACTION}" == "review" ]]; then
  run_repo_review "${REPO_ROOT}"
  exit 0
fi

if [[ $# -ge 2 ]]; then
  shift 2
fi

while [[ $# -gt 0 ]]; do
  case "${1}" in
    --tool-name)
      [[ $# -ge 2 ]] || {
        log_error "缺少 --tool-name 的值"
        exit 1
      }
      TARGET_TOOL="${2}"
      shift 2
      ;;
    *)
      FORWARD_ARGS+=("${1}")
      shift
      ;;
  esac
done

if [[ -z "${COMMAND_GROUP}" || -z "${COMMAND_ACTION}" ]]; then
  usage
  exit 1
fi

[[ -n "${TARGET_TOOL}" ]] || {
  log_error "必须通过 --tool-name 指定工具"
  usage
  exit 1
}

TARGET_ENTRY="$(resolve_tool_entry "${TARGET_TOOL}")" || {
  log_error "不支持的工具：${TARGET_TOOL}"
  print_section "可用工具"
  list_tools
  exit 1
}

if should_announce_forward; then
  log_info "转发到工具：${TARGET_TOOL}"
fi
exec bash "${TARGET_ENTRY}" "${COMMAND_GROUP}" "${COMMAND_ACTION}" "${FORWARD_ARGS[@]}"
