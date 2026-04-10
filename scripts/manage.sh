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
ROOT_CONFIG_FILE=""
ROOT_CONFIG_SET_ITEMS=()
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
SCENE_COMPLETION_PROGRESS=0
SCENE_NAV_BACK="__SCENE_NAV_BACK__"
SCENE_NAV_EXIT="__SCENE_NAV_EXIT__"
SCENE_RC_BACK=130
SCENE_RC_EXIT=131

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
  help_print_entry "config set" "批量写配置"
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
  help_print_note "默认会按步骤引导：工具 -> 场景 -> 配置文件 -> 关键配置 -> 能力定制（按需） -> 项目模板（按需） -> 执行确认。"
  help_print_note "常见场景默认沿用配置里的推荐模型和模式，只在你明确要改时展开进阶项。"
  help_print_note "Coding tools 的 install / enhance / migrate 会在关键配置后，先展示当前会自动安装的主能力，再决定是否做高阶定制。"
  help_print_note "install / enhance / migrate 会先补齐关键配置，再展示执行计划。"
  help_print_note "status / project 只做必要输入，不额外追问认证和密钥。"
  help_print_note "OpenClaw 安装 / 增强 / 接管会先引导选择部署形态：公网域名 / 公网 IP / Tailscale 私网 / Tailscale 公网。"
  help_print_note "URL / 地址类字段支持当场核对；如果配置里已有旧值，向导默认不直接回显，避免泄露。"
  help_print_note "菜单通常可输入 0 或 back 返回；如果当前菜单已占用 0，可输入 b 或 back 返回。"
  help_print_note "关键配置阶段里，后续问题输入 back 会回到本阶段开头；首个问题输入 back 会回到上一步。"
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
      read -r -p "${message} [${default_value}]（输入 back 返回，q 退出）: " answer
      case "${answer}" in
        back|BACK|Back)
          printf '%s' "${SCENE_NAV_BACK}"
          return 0
          ;;
        q|Q|quit|QUIT|Quit|exit|EXIT|Exit)
          printf '%s' "${SCENE_NAV_EXIT}"
          return 0
          ;;
      esac
      printf '%s' "${answer:-${default_value}}"
      return 0
    fi

    read -r -p "${message}（输入 back 返回，q 退出）: " answer
    case "${answer}" in
      back|BACK|Back)
        printf '%s' "${SCENE_NAV_BACK}"
        return 0
        ;;
      q|Q|quit|QUIT|Quit|exit|EXIT|Exit)
        printf '%s' "${SCENE_NAV_EXIT}"
        return 0
        ;;
    esac
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
  local nav_back_key="0"
  local default_label=""
  local default_label_short=""
  local default_prompt=""

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

  for value in "${values[@]}"; do
    if [[ "${value}" == "0" ]]; then
      nav_back_key="b"
      break
    fi
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

  default_label="${labels[$((default_index - 1))]:-}"
  if [[ -n "${default_label}" ]]; then
    default_label_short="$(printf '%s' "${default_label}" | sed -E 's/[[:space:]]{2,}.*$//; s/[[:space:]]+$//')"
    default_prompt="默认 ${default_index}: ${default_label_short}"
  else
    default_prompt="${default_index}"
  fi

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
  printf '  %s%-2s%s %s\n' "${HELP_BLUE}" "${nav_back_key}" "${HELP_RESET}" "返回上一层" >&2
  printf '  %s%-2s%s %s\n' "${HELP_BLUE}" "q" "${HELP_RESET}" "退出向导" >&2

  while true; do
    read -r -p "${message} [${default_prompt}]: " answer
    answer="${answer:-${default_index}}"

    case "${answer}" in
      back|BACK|Back)
        printf '%s' "${SCENE_NAV_BACK}"
        return 0
        ;;
      0)
        if [[ "${nav_back_key}" == "0" ]]; then
          printf '%s' "${SCENE_NAV_BACK}"
          return 0
        fi
        ;;
      b|B)
        if [[ "${nav_back_key}" == "b" ]]; then
          printf '%s' "${SCENE_NAV_BACK}"
          return 0
        fi
        ;;
      q|Q|quit|QUIT|Quit|exit|EXIT|Exit)
        printf '%s' "${SCENE_NAV_EXIT}"
        return 0
        ;;
    esac

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
    read -r -p "${message} [${default_value}]（输入 back 返回，q 退出）: " answer
    case "${answer}" in
      back|BACK|Back)
        printf '%s' "${SCENE_NAV_BACK}"
        return 0
        ;;
      q|Q|quit|QUIT|Quit|exit|EXIT|Exit)
        printf '%s' "${SCENE_NAV_EXIT}"
        return 0
        ;;
    esac
    printf '%s' "${answer:-${default_value}}"
  else
    read -r -p "${message}（输入 back 返回，q 退出）: " answer
    case "${answer}" in
      back|BACK|Back)
        printf '%s' "${SCENE_NAV_BACK}"
        return 0
        ;;
      q|Q|quit|QUIT|Quit|exit|EXIT|Exit)
        printf '%s' "${SCENE_NAV_EXIT}"
        return 0
        ;;
    esac
    printf '%s' "${answer}"
  fi
}

prompt_sensitive_text_with_default() {
  local message="$1"
  local default_value="${2:-}"
  local required="${3:-1}"
  local display_default="${4:-1}"
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
      if [[ "${display_default}" == "1" ]]; then
        read -r -p "${message} [${default_value}]（仅当前交互明文显示；回车保留，back 返回，q 退出）: " answer
      else
        read -r -p "${message} [已配置，回车保留现有值；back 返回，q 退出]: " answer
      fi
    elif [[ "${required}" == "0" ]]; then
      read -r -p "${message}（可留空；back 返回，q 退出）: " answer
    else
      read -r -p "${message}（输入 back 返回，q 退出）: " answer
    fi

    case "${answer}" in
      back|BACK|Back)
        printf '%s' "${SCENE_NAV_BACK}"
        return 0
        ;;
      q|Q|quit|QUIT|Quit|exit|EXIT|Exit)
        printf '%s' "${SCENE_NAV_EXIT}"
        return 0
        ;;
    esac

    if [[ -n "${default_value}" && -z "${answer}" ]]; then
      answer="${default_value}"
    fi

    if [[ "${required}" == "0" || -n "${answer}" ]]; then
      printf '%s' "${answer}"
      return 0
    fi
    log_warn "${message} 不能为空。"
  done
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
      read -r -s -p "${message} [回车保留现有值，back 返回，q 退出]: " answer
      printf '\n' >&2
      case "${answer}" in
        back|BACK|Back)
          printf '%s' "${SCENE_NAV_BACK}"
          return 0
          ;;
        q|Q|quit|QUIT|Quit|exit|EXIT|Exit)
          printf '%s' "${SCENE_NAV_EXIT}"
          return 0
          ;;
      esac
      answer="${answer:-${default_value}}"
    else
      read -r -s -p "${message} [back 返回，q 退出]: " answer
      printf '\n' >&2
      case "${answer}" in
        back|BACK|Back)
          printf '%s' "${SCENE_NAV_BACK}"
          return 0
          ;;
        q|Q|quit|QUIT|Quit|exit|EXIT|Exit)
          printf '%s' "${SCENE_NAV_EXIT}"
          return 0
          ;;
      esac
    fi

    if [[ "${required}" == "0" || -n "${answer}" ]]; then
      printf '%s' "${answer}"
      return 0
    fi
    log_warn "${message} 不能为空。"
  done
}

scene_prompt_status_from_value() {
  local value="${1:-}"

  case "${value}" in
    "${SCENE_NAV_BACK}")
      return "${SCENE_RC_BACK}"
      ;;
    "${SCENE_NAV_EXIT}")
      return "${SCENE_RC_EXIT}"
      ;;
  esac
  return 0
}

scene_prompt_with_default() {
  local value=""
  value="$(prompt_with_default "$@")" || return $?
  scene_prompt_status_from_value "${value}" || return $?
  printf '%s' "${value}"
}

scene_prompt_optional_with_default() {
  local value=""
  value="$(prompt_optional_with_default "$@")" || return $?
  scene_prompt_status_from_value "${value}" || return $?
  printf '%s' "${value}"
}

scene_prompt_sensitive_with_default() {
  local value=""
  value="$(prompt_sensitive_text_with_default "$@")" || return $?
  scene_prompt_status_from_value "${value}" || return $?
  printf '%s' "${value}"
}

scene_prompt_secret_with_default() {
  local value=""
  value="$(prompt_secret_with_default "$@")" || return $?
  scene_prompt_status_from_value "${value}" || return $?
  printf '%s' "${value}"
}

scene_prompt_menu_choice() {
  local value=""
  value="$(prompt_menu_choice "$@")" || return $?
  scene_prompt_status_from_value "${value}" || return $?
  printf '%s' "${value}"
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

  answer="$(scene_prompt_menu_choice "${message}" "${default_yes}" "1|是" "0|否")" || return $?
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

config_apply_set_items() {
  local config_file="$1"
  shift
  local item=""
  local key=""
  local value=""

  [[ -n "${config_file}" ]] || {
    log_error "缺少 --config"
    return 1
  }
  [[ -f "${config_file}" ]] || {
    log_error "配置文件不存在：${config_file}"
    return 1
  }

  for item in "$@"; do
    [[ "${item}" == *"="* ]] || {
      log_error "配置项格式错误：${item}，应为 KEY=VALUE"
      return 1
    }
    key="${item%%=*}"
    value="${item#*=}"
    [[ "${key}" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || {
      log_error "配置键不合法：${key}"
      return 1
    }
    config_set_value "${config_file}" "${key}" "${value}"
  done
}

scene_record_update() {
  local key="$1"
  local display_value="$2"
  SCENE_UPDATE_LINES+=("${key}"$'\t'"${display_value}")
}

scene_record_note() {
  SCENE_NOTE_LINES+=("$1")
}

scene_reset_completion_progress() {
  SCENE_COMPLETION_PROGRESS=0
}

scene_mark_completion_progress() {
  SCENE_COMPLETION_PROGRESS=1
}

scene_display_value() {
  local value="${1:-}"
  local display_mode="${2:-0}"

  case "${display_mode}" in
    1|secret)
      if [[ -n "${value}" ]]; then
        printf '<已写入>'
      else
        printf '<空>'
      fi
      ;;
    2|endpoint)
      if [[ -n "${value}" ]]; then
        printf '%s' "${value}"
      else
        printf '<空>'
      fi
      ;;
    *)
      printf '%s' "${value}"
      ;;
  esac
}

scene_set_config_value() {
  local key="$1"
  local value="${2:-}"
  local display_mode="${3:-0}"
  local current_value=""

  current_value="$(config_read_value "${SCENE_CONFIG}" "${key}" || true)"
  if [[ "${current_value}" == "${value}" ]]; then
    return 0
  fi

  config_apply_set_items "${SCENE_CONFIG}" "${key}=${value}"
  scene_record_update "${key}" "$(scene_display_value "${value}" "${display_mode}")"
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
  scene_prompt_menu_choice "${label}" "${default_value}" "1|开启" "0|关闭"
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

scene_tool_primary_capability_type() {
  case "${1:-}" in
    codex)
      printf 'skill'
      ;;
    claude-code|gemini-cli|opencode)
      printf 'plugin'
      ;;
    *)
      return 1
      ;;
  esac
}

scene_tool_primary_capability_label() {
  case "${1:-}" in
    codex)
      printf 'skill'
      ;;
    claude-code)
      printf 'plugin'
      ;;
    gemini-cli)
      printf 'extension'
      ;;
    opencode)
      printf 'plugin'
      ;;
    *)
      return 1
      ;;
  esac
}

scene_tool_primary_enabled_key() {
  case "${1:-}" in
    codex)
      printf 'ENABLE_DEFAULT_SKILLS'
      ;;
    claude-code|gemini-cli|opencode)
      printf 'ENABLE_DEFAULT_PLUGINS'
      ;;
    *)
      return 1
      ;;
  esac
}

scene_tool_primary_spec_key() {
  case "${1:-}" in
    codex)
      printf 'SKILL_SPECS'
      ;;
    claude-code|gemini-cli|opencode)
      printf 'PLUGIN_SPECS'
      ;;
    *)
      return 1
      ;;
  esac
}

scene_tool_primary_exclude_key() {
  case "${1:-}" in
    codex)
      printf 'SKILL_EXCLUDES'
      ;;
    claude-code|gemini-cli|opencode)
      printf 'PLUGIN_EXCLUDES'
      ;;
    *)
      return 1
      ;;
  esac
}

scene_tool_primary_install_mode() {
  case "${1:-}" in
    codex)
      printf 'skill-installer'
      ;;
    claude-code)
      printf 'repl-plugin'
      ;;
    gemini-cli)
      printf 'extensions-install'
      ;;
    opencode)
      printf 'config-plugin'
      ;;
    *)
      return 1
      ;;
  esac
}

scene_tool_default_common_packs() {
  printf 'common-core,common-docs-architecture,common-quality,common-backend,common-frontend'
}

scene_tool_default_packs() {
  case "${1:-}" in
    codex)
      printf 'codex-core,codex-review'
      ;;
    claude-code)
      printf 'claude-workflow,claude-review'
      ;;
    gemini-cli)
      printf 'gemini-core,gemini-collaboration'
      ;;
    opencode)
      printf 'opencode-core,opencode-workspace'
      ;;
    *)
      return 1
      ;;
  esac
}

scene_tool_default_enhanced_packs() {
  case "${1:-}" in
    codex)
      printf 'codex-ecosystem,codex-frontend,codex-research,enhanced-browser-deep,enhanced-long-memory,enhanced-observability'
      ;;
    claude-code)
      printf 'claude-ui,claude-memory,claude-ecosystem,enhanced-browser-deep,enhanced-long-memory,enhanced-observability'
      ;;
    gemini-cli)
      printf 'gemini-ui,gemini-data,enhanced-browser-deep,enhanced-background-agents,enhanced-observability'
      ;;
    opencode)
      printf 'opencode-memory,opencode-safety,enhanced-browser-deep,enhanced-long-memory,enhanced-background-agents'
      ;;
    *)
      return 1
      ;;
  esac
}

scene_tool_default_experimental_packs() {
  printf 'experimental-bleeding-edge'
}

scene_mode_flag_value() {
  local mode_value="${1:-standard}"
  local flag_name="${2:-enhanced}"

  case "${mode_value}" in
    exploration)
      printf '1'
      ;;
    advanced)
      if [[ "${flag_name}" == "enhanced" ]]; then
        printf '1'
      else
        printf '0'
      fi
      ;;
    *)
      printf '0'
      ;;
  esac
}

scene_current_primary_capabilities_csv() {
  local tool_name="${1:-${SCENE_TOOL}}"
  local capability_type=""
  local install_mode=""
  local enabled_key=""
  local spec_key=""
  local exclude_key=""
  local mode_value=""
  local default_enabled="1"
  local enabled_value="1"
  local common_packs=""
  local tool_packs=""
  local enhanced_packs=""
  local experimental_packs=""
  local explicit_specs=""
  local exclude_specs=""

  capability_type="$(scene_tool_primary_capability_type "${tool_name}")" || return 0
  install_mode="$(scene_tool_primary_install_mode "${tool_name}")" || return 0
  enabled_key="$(scene_tool_primary_enabled_key "${tool_name}")" || return 0
  spec_key="$(scene_tool_primary_spec_key "${tool_name}")" || return 0
  exclude_key="$(scene_tool_primary_exclude_key "${tool_name}")" || return 0

  mode_value="$(scene_current_or_default "MODE" "standard")"
  enabled_value="$(scene_current_or_default "${enabled_key}" "${default_enabled}")"
  common_packs="$(scene_current_or_default "COMMON_DEFAULT_PACKS" "$(scene_tool_default_common_packs)")"
  tool_packs="$(scene_current_or_default "TOOL_DEFAULT_PACKS" "$(scene_tool_default_packs "${tool_name}")")"
  enhanced_packs="$(scene_current_or_default "ENHANCED_PACKS" "$(scene_tool_default_enhanced_packs "${tool_name}")")"
  experimental_packs="$(scene_current_or_default "EXPERIMENTAL_PACKS" "$(scene_tool_default_experimental_packs)")"
  explicit_specs="$(scene_current_or_default "${spec_key}" "")"
  exclude_specs="$(scene_current_or_default "${exclude_key}" "")"

  if [[ "${enabled_value}" == "1" ]]; then
    resolve_installable_capability_items_csv \
      "${tool_name}" \
      "${capability_type}" \
      "${install_mode}" \
      "${common_packs}" \
      "${tool_packs}" \
      "${enhanced_packs}" \
      "$(scene_mode_flag_value "${mode_value}" "enhanced")" \
      "${experimental_packs}" \
      "$(scene_mode_flag_value "${mode_value}" "experimental")" \
      "${explicit_specs}" \
      "${exclude_specs}"
  else
    csv_subtract "${explicit_specs}" "${exclude_specs}"
  fi
}

scene_primary_capability_candidates_csv() {
  local tool_name="${1:-${SCENE_TOOL}}"
  local capability_type=""
  local install_mode=""

  capability_type="$(scene_tool_primary_capability_type "${tool_name}")" || return 0
  install_mode="$(scene_tool_primary_install_mode "${tool_name}")" || return 0
  capability_known_items_csv_by_install_mode "${tool_name}" "${capability_type}" "${install_mode}"
}

scene_update_csv_config_value() {
  local key="$1"
  local mode="${2:-merge}"
  local items_csv="${3:-}"
  local current_value=""
  local updated_value=""

  current_value="$(scene_current_or_default "${key}" "")"
  case "${mode}" in
    merge)
      updated_value="$(csv_merge_unique "${current_value}" "${items_csv}")"
      ;;
    subtract)
      updated_value="$(csv_subtract "${current_value}" "${items_csv}")"
      ;;
    replace)
      updated_value="${items_csv}"
      ;;
    *)
      updated_value="${current_value}"
      ;;
  esac
  scene_set_config_value "${key}" "${updated_value}" 0
}

scene_print_capability_items() {
  local label="$1"
  local items_csv="${2:-}"
  local empty_text="${3:-<空>}"
  local -a items=()
  local item=""

  mapfile -t items < <(csv_clean_lines "${items_csv}")
  if [[ "${#items[@]}" -eq 0 ]]; then
    help_print_entry "${label}" "${empty_text}"
    return 0
  fi

  help_print_entry "${label}" "${#items[@]} 项"
  for item in "${items[@]}"; do
    help_print_note "- ${item}"
  done
}

scene_customize_primary_capabilities() {
  local tool_name="${1:-${SCENE_TOOL}}"
  local label=""
  local spec_key=""
  local exclude_key=""
  local current_plan=""
  local explicit_specs=""
  local exclude_specs=""
  local candidate_specs=""
  local action=""
  local items=""

  label="$(scene_tool_primary_capability_label "${tool_name}")" || return 0
  spec_key="$(scene_tool_primary_spec_key "${tool_name}")" || return 0
  exclude_key="$(scene_tool_primary_exclude_key "${tool_name}")" || return 0

  while true; do
    current_plan="$(scene_current_primary_capabilities_csv "${tool_name}")"
    explicit_specs="$(scene_current_or_default "${spec_key}" "")"
    exclude_specs="$(scene_current_or_default "${exclude_key}" "")"

    help_print_section "能力项定制"
    help_print_rule
    help_print_note "模式仍决定默认基线；这里是在当前模式基础上，对会自动安装的 ${label} 做精确定制。"
    scene_print_capability_items "当前安装计划" "${current_plan}" "<空>"
    scene_print_capability_items "额外增加" "${explicit_specs}" "<空>"
    scene_print_capability_items "自动排除" "${exclude_specs}" "<空>"

    action="$(scene_prompt_menu_choice "请选择定制动作" "4" \
      "1|增加 ${label}        额外追加到本次自动安装清单" \
      "2|删除 ${label}        从本次自动安装清单排除" \
      "3|查看候选            查看当前支持的候选项" \
      "4|完成                保留当前定制结果")" || return $?

    case "${action}" in
      1)
        candidate_specs="$(scene_primary_capability_candidates_csv "${tool_name}")"
        help_print_section "可增加的候选项"
        help_print_rule
        scene_print_capability_items "候选 ${label}" "${candidate_specs}" "<空>"
        help_print_note "支持直接填写这些短名；也支持该工具原生 spec、GitHub 路径或本地路径。"
        items="$(scene_prompt_with_default "输入要增加的 ${label}（多个用逗号分隔）" "")" || return $?
        scene_update_csv_config_value "${spec_key}" merge "${items}"
        scene_update_csv_config_value "${exclude_key}" subtract "${items}"
        ;;
      2)
        help_print_section "可删除的当前计划"
        help_print_rule
        scene_print_capability_items "当前 ${label}" "${current_plan}" "<空>"
        items="$(scene_prompt_with_default "输入要删除的 ${label}（多个用逗号分隔）" "")" || return $?
        scene_update_csv_config_value "${exclude_key}" merge "${items}"
        scene_update_csv_config_value "${spec_key}" subtract "${items}"
        ;;
      3)
        candidate_specs="$(scene_primary_capability_candidates_csv "${tool_name}")"
        help_print_section "候选能力项"
        help_print_rule
        scene_print_capability_items "已登记候选" "${candidate_specs}" "<空>"
        help_print_note "支持直接填写上面这些短名；如果工具本身支持，也可以填原生 spec、GitHub 路径或本地路径。"
        ;;
      4)
        return 0
        ;;
    esac
  done
}

scene_offer_primary_capability_customization() {
  local label=""
  local answer=""
  local current_plan=""

  case "${SCENE_TOOL}" in
    codex|claude-code|gemini-cli|opencode)
      ;;
    *)
      return 0
      ;;
  esac

  label="$(scene_tool_primary_capability_label "${SCENE_TOOL}")" || return 0
  current_plan="$(scene_current_primary_capabilities_csv "${SCENE_TOOL}")"
  help_print_section "默认安装能力"
  help_print_rule
  help_print_note "下面这些是按当前模式和当前配置，本次会自动安装或同步的主能力。"
  scene_print_capability_items "当前 ${label} 计划" "${current_plan}" "<空>"
  answer="$(scene_prompt_menu_choice "是否定制本次默认安装的 ${label}" "0" \
    "1|是，查看并增删 ${label}" \
    "0|否，保持当前模式默认方案")" || return $?
  if [[ "${answer}" == "1" ]]; then
    scene_customize_primary_capabilities "${SCENE_TOOL}" || return $?
  fi
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
      help_print_note "只要走 apikey，这里就会主动确认 provider 和 Base URL；这本身就是关键接入项，不再归到进阶项里。"
      help_print_note "API Base URL 支持当场核对；若配置里已有旧值，向导默认不直接回显。"
      ;;
    claude-code:install|claude-code:enhance|claude-code:migrate)
      help_print_note "Claude Code 一般是两种接法：API Key 选 api-key，长令牌或代理 token 选 auth-token。"
      help_print_note "如果你走第三方代理，可把 Anthropic Base URL 一起补齐。"
      help_print_note "Anthropic Base URL 支持当场核对；若配置里已有旧值，向导默认不直接回显。"
      ;;
    gemini-cli:install|gemini-cli:enhance|gemini-cli:migrate)
      help_print_note "Gemini CLI 普通接入选 api-key，浏览器登录选 google-login，企业 GCP / Vertex AI 选 vertex-ai。"
      help_print_note "Vertex AI 场景需要补 Google Cloud Project 和 Location。"
      ;;
    opencode:install|opencode:enhance|opencode:migrate)
      help_print_note "OpenCode 会按默认 provider 生成配置；建议先明确你主要用 anthropic、openai、google 还是 ollama。"
      help_print_note "如果你走 OpenAI 兼容网关，可直接选 openai，并把 Base URL 一起补齐。"
      help_print_note "如果是本地模型，直接选 ollama 并填写本地地址。"
      help_print_note "Base URL 支持当场核对；若配置里已有旧值，向导默认不直接回显。"
      ;;
  esac

  case "${SCENE_TOOL}" in
    codex|claude-code|gemini-cli|opencode)
      help_print_note "关键配置完成后，会先展示当前模式下准备安装的主能力，你可以继续保持默认，也可以增删个别项。"
      ;;
  esac
}

scene_complete_common_mode() {
  local mode_value=""
  mode_value="$(scene_prompt_menu_choice "最佳实践模式" "$(scene_current_or_default "MODE" "standard")" \
    "standard|standard     稳态基线，默认推荐" \
    "advanced|advanced     增强能力，适合主力使用" \
    "exploration|exploration  探索模式，能力更多")" || return $?
  scene_set_config_value "MODE" "${mode_value}" 0
}

scene_should_customize_advanced() {
  local answer=""

  answer="$(scene_prompt_menu_choice "是否调整模型和最佳实践模式" "0" \
    "1|是，调整模型 / 模式" \
    "0|保持当前推荐配置")" || return $?
  [[ "${answer}" == "1" ]]
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

  answer="$(scene_prompt_menu_choice "请选择部署形态" "$(scene_default_openclaw_profile_index "${current_profile}")" \
    "1|公网域名       有公网 IP + 域名，自动 Nginx + 证书" \
    "2|公网 IP         有公网 IP，无域名" \
    "3|Tailscale 私网  访问端需安装 Tailscale 客户端" \
    "4|Tailscale 公网  通过 Tailscale 公网入口访问")" || return $?

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
  local current_provider=""
  local current_provider_name=""
  local current_provider_env_key=""
  local current_api_base_url=""
  local provider_mode_default=""
  local provider_api_label=""
  local model_provider=""
  local provider_name=""
  local api_base_url=""
  local provider_env_key=""
  local provider_api_value=""
  local customize_advanced="0"
  local customize_status="0"

  auth_method="$(scene_prompt_menu_choice "认证方式" "$(scene_current_or_default "AUTH_METHOD" "chatgpt")" \
    "chatgpt|chatgpt  使用官方账号登录" \
    "apikey|apikey   使用 API Key / 兼容网关")" || return $?
  scene_mark_completion_progress
  scene_set_config_value "AUTH_METHOD" "${auth_method}" 0

  if scene_should_customize_advanced; then
    customize_advanced="1"
    default_model="$(scene_prompt_with_default "默认模型" "$(scene_current_or_default "DEFAULT_MODEL" "gpt-5.4")")" || return $?
    scene_set_config_value "DEFAULT_MODEL" "${default_model}" 0
    scene_complete_common_mode || return $?
  else
    customize_status="$?"
    [[ "${customize_status}" == "1" ]] || return "${customize_status}"
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

  current_provider="$(scene_current_or_default "MODEL_PROVIDER" "openai")"
  current_provider_name="$(scene_current_or_default "PROVIDER_NAME" "${current_provider}")"
  current_provider_env_key="$(scene_current_or_default "PROVIDER_ENV_KEY" "$(scene_default_provider_env_key "${current_provider}")")"
  current_api_base_url="$(scene_current_or_default "API_BASE_URL" "")"

  if [[ "${current_provider}" == "openai" ]]; then
    provider_mode_default="openai"
  else
    provider_mode_default="custom"
  fi

  provider_mode="$(scene_prompt_menu_choice "Provider 类型" "${provider_mode_default}" \
    "openai|openai  官方或 OpenAI 兼容网关" \
    "custom|custom  自定义 provider 名称")" || return $?

  if [[ "${provider_mode}" == "openai" ]]; then
    model_provider="openai"
    provider_name="openai"
    if [[ "${current_provider}" == "openai" ]]; then
      api_base_url="$(scene_prompt_sensitive_with_default "API Base URL（官方默认可留空）" "${current_api_base_url}" 0 0)" || return $?
    else
      api_base_url="$(scene_prompt_sensitive_with_default "API Base URL（官方默认可留空）" "" 0 0)" || return $?
    fi
    provider_env_key="OPENAI_API_KEY"
    provider_api_label="OPENAI_API_KEY"
  else
    if [[ "${current_provider}" == "openai" ]]; then
      model_provider="$(scene_prompt_with_default "自定义 provider 标识" "custom-provider")" || return $?
      provider_name="$(scene_prompt_with_default "Provider 名称" "${model_provider}")" || return $?
      api_base_url="$(scene_prompt_sensitive_with_default "API Base URL" "" 1 0)" || return $?
      provider_env_key="$(scene_prompt_with_default "Provider 环境变量名" "$(scene_default_provider_env_key "${model_provider}")")" || return $?
    else
      model_provider="$(scene_prompt_with_default "自定义 provider 标识" "${current_provider}")" || return $?
      provider_name="$(scene_prompt_with_default "Provider 名称" "${current_provider_name:-${model_provider}}")" || return $?
      api_base_url="$(scene_prompt_sensitive_with_default "API Base URL" "${current_api_base_url}" 1 0)" || return $?
      provider_env_key="$(scene_prompt_with_default "Provider 环境变量名" "${current_provider_env_key:-$(scene_default_provider_env_key "${model_provider}")}")" || return $?
    fi
    provider_api_label="${provider_env_key}"
  fi

  scene_set_config_value "MODEL_PROVIDER" "${model_provider}" 0
  scene_set_config_value "PROVIDER_NAME" "${provider_name}" 0
  scene_set_config_value "API_BASE_URL" "${api_base_url}" endpoint
  scene_set_config_value "PROVIDER_ENV_KEY" "${provider_env_key}" 0

  provider_api_value="$(scene_prompt_secret_with_default "${provider_api_label}" "$(scene_current_or_default "PROVIDER_API_VALUE" "")" 1)" || return $?
  scene_set_config_value "PROVIDER_API_VALUE" "${provider_api_value}" 1
}

scene_complete_claude_code_config() {
  local auth_mode=""
  local default_model=""
  local api_key=""
  local auth_token=""
  local base_url=""
  local customize_advanced="0"
  local customize_status="0"

  auth_mode="$(scene_prompt_menu_choice "认证方式" "$(scene_current_or_default "AUTH_MODE" "api-key")" \
    "api-key|api-key      官方或兼容网关 API Key" \
    "auth-token|auth-token   长令牌 / Bearer Token")" || return $?
  scene_mark_completion_progress
  scene_set_config_value "AUTH_MODE" "${auth_mode}" 0
  if scene_should_customize_advanced; then
    customize_advanced="1"
    default_model="$(scene_prompt_with_default "默认模型" "$(scene_current_or_default "DEFAULT_MODEL" "claude-sonnet-4-6")")" || return $?
    scene_set_config_value "DEFAULT_MODEL" "${default_model}" 0
    scene_complete_common_mode || return $?
  else
    customize_status="$?"
    [[ "${customize_status}" == "1" ]] || return "${customize_status}"
  fi

  base_url="$(scene_prompt_sensitive_with_default "Anthropic Base URL（官方直连可留空，第三方网关需填写）" "$(scene_current_or_default "ANTHROPIC_BASE_URL" "")" 0 0)" || return $?
  scene_set_config_value "ANTHROPIC_BASE_URL" "${base_url}" endpoint
  scene_record_note "Claude Code 会自动同步 ~/.claude.json，并写入 hasCompletedOnboarding=true，用于跳过首次登录引导。"

  case "${auth_mode}" in
    api-key)
      api_key="$(scene_prompt_secret_with_default "ANTHROPIC_API_KEY" "$(scene_current_or_default "ANTHROPIC_API_KEY" "")" 1)" || return $?
      scene_set_config_value "ANTHROPIC_API_KEY" "${api_key}" 1
      scene_set_config_value "ANTHROPIC_AUTH_TOKEN" "" 1
      ;;
    auth-token)
      auth_token="$(scene_prompt_secret_with_default "ANTHROPIC_AUTH_TOKEN" "$(scene_current_or_default "ANTHROPIC_AUTH_TOKEN" "")" 1)" || return $?
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
  local customize_status="0"

  auth_mode="$(scene_prompt_menu_choice "认证方式" "$(scene_current_or_default "AUTH_MODE" "api-key")" \
    "api-key|api-key      普通 API Key 接入" \
    "google-login|google-login 浏览器登录" \
    "vertex-ai|vertex-ai    Google Vertex AI")" || return $?
  scene_mark_completion_progress
  scene_set_config_value "AUTH_MODE" "${auth_mode}" 0
  if scene_should_customize_advanced; then
    customize_advanced="1"
    default_model="$(scene_prompt_with_default "默认模型" "$(scene_current_or_default "DEFAULT_MODEL" "gemini-2.5-pro")")" || return $?
    scene_set_config_value "DEFAULT_MODEL" "${default_model}" 0
    scene_complete_common_mode || return $?
  else
    customize_status="$?"
    [[ "${customize_status}" == "1" ]] || return "${customize_status}"
  fi

  case "${auth_mode}" in
    api-key)
      api_key_default="$(scene_current_or_default "GEMINI_API_KEY" "")"
      if [[ -z "${api_key_default}" ]]; then
        api_key_default="$(scene_current_or_default "GOOGLE_API_KEY" "")"
      fi
      api_key="$(scene_prompt_secret_with_default "Gemini API Key" "${api_key_default}" 1)" || return $?
      scene_set_config_value "GEMINI_API_KEY" "${api_key}" 1
      scene_set_config_value "GOOGLE_API_KEY" "" 1
      scene_set_config_value "GOOGLE_CLOUD_PROJECT" "" 0
      scene_set_config_value "GOOGLE_GENAI_USE_VERTEXAI" "false" 0
      ;;
    google-login)
      scene_set_config_value "GEMINI_API_KEY" "" 1
      scene_set_config_value "GOOGLE_API_KEY" "" 1
      scene_set_config_value "GOOGLE_CLOUD_PROJECT" "" 0
      scene_set_config_value "GOOGLE_GENAI_USE_VERTEXAI" "false" 0
      scene_record_note "Google 登录模式依赖 gemini 自己的登录态；如未登录，可后续执行 gemini login。"
      ;;
    vertex-ai)
      cloud_project="$(scene_prompt_with_default "Google Cloud Project" "$(scene_current_or_default "GOOGLE_CLOUD_PROJECT" "")")" || return $?
      if [[ "${customize_advanced}" == "1" ]]; then
        cloud_location="$(scene_prompt_with_default "Google Cloud Location" "$(scene_current_or_default "GOOGLE_CLOUD_LOCATION" "us-central1")")" || return $?
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
  local openai_base_url=""
  local anthropic_api_key=""
  local google_api_key=""
  local ollama_base_url=""
  local customize_advanced="0"
  local customize_status="0"

  current_provider_default="$(scene_current_or_default "PROVIDER_DEFAULT" "anthropic")"
  provider_default="$(scene_prompt_menu_choice "默认 provider" "$(scene_current_or_default "PROVIDER_DEFAULT" "anthropic")" \
    "anthropic|anthropic  Claude 系列" \
    "openai|openai      OpenAI / 兼容网关" \
    "google|google      Gemini" \
    "ollama|ollama      本地模型")" || return $?
  scene_mark_completion_progress
  scene_set_config_value "PROVIDER_DEFAULT" "${provider_default}" 0
  if scene_should_customize_advanced; then
    customize_advanced="1"
    default_model="$(scene_prompt_with_default "默认模型" "$(scene_current_or_default "DEFAULT_MODEL" "$(scene_default_opencode_model "${provider_default}")")")" || return $?
    scene_set_config_value "DEFAULT_MODEL" "${default_model}" 0
    scene_complete_common_mode || return $?
  else
    customize_status="$?"
    [[ "${customize_status}" == "1" ]] || return "${customize_status}"
  fi

  if [[ "${customize_advanced}" != "1" && "${current_provider_default}" != "${provider_default}" ]]; then
    scene_set_config_value "DEFAULT_MODEL" "$(scene_default_opencode_model "${provider_default}")" 0
  fi

  case "${provider_default}" in
    anthropic)
      anthropic_api_key="$(scene_prompt_secret_with_default "ANTHROPIC_API_KEY" "$(scene_current_or_default "ANTHROPIC_API_KEY" "")" 1)" || return $?
      scene_set_config_value "ANTHROPIC_API_KEY" "${anthropic_api_key}" 1
      scene_set_config_value "OPENAI_API_KEY" "" 1
      scene_set_config_value "GOOGLE_GENERATIVEAI_API_KEY" "" 1
      ;;
    openai)
      openai_api_key="$(scene_prompt_secret_with_default "OPENAI_API_KEY" "$(scene_current_or_default "OPENAI_API_KEY" "")" 1)" || return $?
      openai_base_url="$(scene_prompt_sensitive_with_default "OpenAI Base URL（官方直连可留空，兼容网关需填写）" "$(scene_current_or_default "API_BASE_URL" "")" 0 0)" || return $?
      scene_set_config_value "OPENAI_API_KEY" "${openai_api_key}" 1
      scene_set_config_value "API_BASE_URL" "${openai_base_url}" endpoint
      scene_set_config_value "PROVIDER_ENV_KEY" "$(scene_current_or_default "PROVIDER_ENV_KEY" "OPENAI_API_KEY")" 0
      scene_set_config_value "PROVIDER_API_VALUE" "" 1
      scene_set_config_value "ANTHROPIC_API_KEY" "" 1
      scene_set_config_value "GOOGLE_GENERATIVEAI_API_KEY" "" 1
      ;;
    google)
      google_api_key="$(scene_prompt_secret_with_default "GOOGLE_GENERATIVEAI_API_KEY" "$(scene_current_or_default "GOOGLE_GENERATIVEAI_API_KEY" "")" 1)" || return $?
      scene_set_config_value "GOOGLE_GENERATIVEAI_API_KEY" "${google_api_key}" 1
      scene_set_config_value "OPENAI_API_KEY" "" 1
      scene_set_config_value "ANTHROPIC_API_KEY" "" 1
      ;;
    ollama)
      if [[ "${customize_advanced}" == "1" ]]; then
        ollama_base_url="$(scene_prompt_sensitive_with_default "Ollama Base URL" "$(scene_current_or_default "OLLAMA_BASE_URL" "http://localhost:11434")" 1 0)" || return $?
      else
        ollama_base_url="$(scene_current_or_default "OLLAMA_BASE_URL" "http://localhost:11434")"
      fi
      scene_set_config_value "OLLAMA_BASE_URL" "${ollama_base_url}" endpoint
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

  scene_select_openclaw_profile || return $?
  scene_mark_completion_progress
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
        domain="$(scene_prompt_with_default "域名" "$(scene_current_or_default "DOMAIN" "")")" || return $?
        letsencrypt_email="$(scene_prompt_with_default "Let's Encrypt 邮箱" "$(scene_current_or_default "LETSENCRYPT_EMAIL" "")")" || return $?
        scene_set_config_value "DOMAIN" "${domain}" 0
        scene_set_config_value "LETSENCRYPT_EMAIL" "${letsencrypt_email}" 0
      else
        scene_set_config_value "DOMAIN" "" 0
        scene_set_config_value "LETSENCRYPT_EMAIL" "" 0
      fi
      scene_set_config_value "TAILSCALE_AUTH_KEY" "" 1
      ;;
    tailscale-private|tailscale-public)
      tailscale_auth_key="$(scene_prompt_secret_with_default "Tailscale Auth Key" "$(scene_current_or_default "TAILSCALE_AUTH_KEY" "")" 1)" || return $?
      tailscale_hostname="$(scene_prompt_with_default "Tailscale 主机名" "$(scene_current_or_default "TAILSCALE_HOSTNAME" "openclaw-node")")" || return $?
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

  enable_feishu="$(scene_enabled_flag_prompt "是否开启飞书接入" "$(scene_current_or_default "ENABLE_FEISHU" "0")")" || return $?
  scene_set_config_value "ENABLE_FEISHU" "${enable_feishu}" 0
  if [[ "${enable_feishu}" == "1" ]]; then
    feishu_app_id="$(scene_prompt_with_default "FEISHU_APP_ID" "$(scene_current_or_default "FEISHU_APP_ID" "")")" || return $?
    feishu_app_secret="$(scene_prompt_secret_with_default "FEISHU_APP_SECRET" "$(scene_current_or_default "FEISHU_APP_SECRET" "")" 1)" || return $?
    feishu_verification_token="$(scene_prompt_secret_with_default "FEISHU_VERIFICATION_TOKEN" "$(scene_current_or_default "FEISHU_VERIFICATION_TOKEN" "")" 1)" || return $?
    feishu_encrypt_key="$(scene_prompt_secret_with_default "FEISHU_ENCRYPT_KEY" "$(scene_current_or_default "FEISHU_ENCRYPT_KEY" "")" 1)" || return $?
    scene_set_config_value "FEISHU_APP_ID" "${feishu_app_id}" 0
    scene_set_config_value "FEISHU_APP_SECRET" "${feishu_app_secret}" 1
    scene_set_config_value "FEISHU_VERIFICATION_TOKEN" "${feishu_verification_token}" 1
    scene_set_config_value "FEISHU_ENCRYPT_KEY" "${feishu_encrypt_key}" 1
  fi

  enable_memory_plugin="$(scene_enabled_flag_prompt "是否开启长期记忆插件" "$(scene_current_or_default "ENABLE_MEMORY_PLUGIN" "1")")" || return $?
  scene_set_config_value "ENABLE_MEMORY_PLUGIN" "${enable_memory_plugin}" 0
  if [[ "${enable_memory_plugin}" == "1" ]]; then
    scene_set_config_value "MEMORY_PLUGIN" "$(scene_current_or_default "MEMORY_PLUGIN" "memory-lancedb-pro")" 0
    memory_embedding_api_key="$(scene_prompt_secret_with_default "MEMORY_EMBEDDING_API_KEY" "$(scene_current_or_default "MEMORY_EMBEDDING_API_KEY" "")" 1)" || return $?
    scene_set_config_value "MEMORY_EMBEDDING_API_KEY" "${memory_embedding_api_key}" 1
  else
    scene_set_config_value "MEMORY_EMBEDDING_API_KEY" "" 1
  fi
}

scenario_complete_config() {
  SCENE_UPDATE_LINES=()
  SCENE_NOTE_LINES=()
  scene_reset_completion_progress

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
  esac || return $?

  scene_offer_primary_capability_customization || return $?
}

scene_render_config_completion() {
  local entry=""
  local key=""
  local value=""
  local config_path_display=""

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

  if [[ "${#SCENE_UPDATE_LINES[@]}" -gt 0 ]]; then
    config_path_display="${SCENE_CONFIG}"
    help_print_note "上述变更复用底层配置写入能力：manage.sh config set --config ${config_path_display} --set KEY=VALUE"
    help_print_note "scenario 只负责交互采集、场景编排和执行正式命令。"
  fi
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
  help_print_note "菜单支持 0 / back 返回；若 0 已被当前菜单占用，可输入 b / back 返回；q 退出向导。"
  scene_start_step "选择工具" "先确定这次要安装、增强或接管的是哪个工具。"
  answer="$(scene_prompt_menu_choice "请选择工具" "3" \
    "1|openclaw       通用 AI 助手服务" \
    "2|claude-code    Claude Code" \
    "3|codex          OpenAI Codex" \
    "4|gemini-cli     Gemini CLI" \
    "5|opencode       OpenCode")" || return $?
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
    answer="$(scene_prompt_menu_choice "请选择场景" "1" \
      "1|install  首次安装并应用配置" \
      "2|enhance  已安装后增强或切换配置" \
      "3|migrate  接管已有环境并对齐" \
      "4|status   先看当前状态")" || return $?
    case "${answer}" in
      1) SCENE_NAME="install" ;;
      2) SCENE_NAME="enhance" ;;
      3) SCENE_NAME="migrate" ;;
      4) SCENE_NAME="status" ;;
    esac
  else
    answer="$(scene_prompt_menu_choice "请选择场景" "1" \
      "1|install  首次安装并应用最佳实践" \
      "2|enhance  已安装后增强或改模式" \
      "3|migrate  接管已有环境并对齐" \
      "4|project  只初始化项目模板" \
      "5|status   先看当前状态")" || return $?
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
  local status="0"
  local stage="tool"

  help_init_colors
  while true; do
    case "${stage}" in
      tool)
        SCENE_WIZARD_STEP=1
        select_tool_interactive
        status="$?"
        if [[ "${status}" == "0" ]]; then
          stage="scene"
          continue
        fi
        case "${status}" in
          "${SCENE_RC_BACK}"|"${SCENE_RC_EXIT}")
            log_warn "已取消场景向导。"
            return 1
            ;;
          *)
            return "${status}"
            ;;
        esac
        ;;
      scene)
        SCENE_WIZARD_STEP=2
        select_scene_interactive
        status="$?"
        if [[ "${status}" == "0" ]]; then
          validate_scene_name "${SCENE_NAME}" || {
            log_error "不支持的场景：${SCENE_NAME}"
            scene_usage
            return 1
          }
          if [[ "${SCENE_TOOL}" == "openclaw" && "${SCENE_NAME}" == "project" ]]; then
            log_error "openclaw 不支持 project 场景"
            return 1
          fi
          stage="config"
          continue
        fi
        case "${status}" in
          "${SCENE_RC_BACK}")
            SCENE_TOOL=""
            SCENE_NAME=""
            SCENE_CONFIG=""
            SCENE_PATH=""
            SCENE_INCLUDE_PROJECT=0
            SCENE_OPENCLAW_PROFILE=""
            stage="tool"
            continue
            ;;
          "${SCENE_RC_EXIT}")
            log_warn "已取消场景向导。"
            return 1
            ;;
          *)
            return "${status}"
            ;;
        esac
        ;;
      config)
        SCENE_WIZARD_STEP=3
        default_config="$(resolve_script_relative_path "$(default_config_hint "${SCENE_TOOL}")")"
        if [[ -z "${SCENE_CONFIG}" ]]; then
          scene_start_step "配置文件" "默认会使用工具目录下的 local.conf；你也可以改成自己的路径。"
          SCENE_CONFIG="$(scene_prompt_with_default "配置文件" "${default_config}")"
          status="$?"
          if [[ "${status}" != "0" ]]; then
            case "${status}" in
              "${SCENE_RC_BACK}")
                SCENE_NAME=""
                SCENE_CONFIG=""
                SCENE_PATH=""
                SCENE_INCLUDE_PROJECT=0
                stage="scene"
                continue
                ;;
              "${SCENE_RC_EXIT}")
                log_warn "已取消场景向导。"
                return 1
                ;;
              *)
                return "${status}"
                ;;
            esac
          fi
        fi

        ensure_scene_config_exists
        status="$?"
        if [[ "${status}" != "0" ]]; then
          case "${status}" in
            "${SCENE_RC_BACK}")
              SCENE_CONFIG=""
              stage="config"
              continue
              ;;
            "${SCENE_RC_EXIT}")
              log_warn "已取消场景向导。"
              return 1
              ;;
            *)
              return "${status}"
              ;;
          esac
        fi

        stage="completion"
        continue
        ;;
      completion)
        SCENE_WIZARD_STEP=4
        if scene_needs_config_completion; then
          scene_start_step "关键配置" "按当前场景补齐关键项，脚本会自动写回配置文件。"
          scene_render_guidance
          scenario_complete_config
          status="$?"
          if [[ "${status}" != "0" ]]; then
            case "${status}" in
              "${SCENE_RC_BACK}")
                if [[ "${SCENE_COMPLETION_PROGRESS}" == "1" ]]; then
                  stage="completion"
                else
                  SCENE_CONFIG=""
                  stage="config"
                fi
                continue
                ;;
              "${SCENE_RC_EXIT}")
                log_warn "已取消场景向导。"
                return 1
                ;;
              *)
                return "${status}"
                ;;
            esac
          fi
        fi

        stage="project"
        continue
        ;;
      project)
        SCENE_WIZARD_STEP=5
        if [[ "${SCENE_NAME}" == "project" ]]; then
          scene_start_step "项目路径" "项目模板会写到你指定的项目目录。"
          SCENE_PATH="$(scene_prompt_with_default "项目路径" "${SCENE_PATH:-/workspace/project}")"
          status="$?"
          if [[ "${status}" != "0" ]]; then
            case "${status}" in
              "${SCENE_RC_BACK}")
                SCENE_PATH=""
                stage="completion"
                continue
                ;;
              "${SCENE_RC_EXIT}")
                log_warn "已取消场景向导。"
                return 1
                ;;
              *)
                return "${status}"
                ;;
            esac
          fi
        fi

        if [[ "${SCENE_NAME}" == "install" && "${SCENE_TOOL}" != "openclaw" ]]; then
          if [[ -n "${SCENE_PATH}" ]]; then
            SCENE_INCLUDE_PROJECT="1"
          else
            scene_start_step "项目模板" "安装完成后，可以顺手把项目目录初始化成推荐结构。"
            if scene_confirm_default "是否同时初始化项目模板" "0"; then
              SCENE_INCLUDE_PROJECT="1"
              SCENE_PATH="$(scene_prompt_with_default "项目路径" "/workspace/project")"
              status="$?"
              if [[ "${status}" != "0" ]]; then
                case "${status}" in
                  "${SCENE_RC_BACK}")
                    SCENE_PATH=""
                    SCENE_INCLUDE_PROJECT=0
                    stage="completion"
                    continue
                    ;;
                  "${SCENE_RC_EXIT}")
                    log_warn "已取消场景向导。"
                    return 1
                    ;;
                  *)
                    return "${status}"
                    ;;
                esac
              fi
            else
              status="$?"
              case "${status}" in
                1)
                  SCENE_INCLUDE_PROJECT=0
                  ;;
                "${SCENE_RC_BACK}")
                  SCENE_INCLUDE_PROJECT=0
                  stage="completion"
                  continue
                  ;;
                "${SCENE_RC_EXIT}")
                  log_warn "已取消场景向导。"
                  return 1
                  ;;
                *)
                  return "${status}"
                  ;;
              esac
            fi
          fi
        fi

        if [[ "${SCENE_NAME}" == "project" && -z "${SCENE_PATH}" ]]; then
          log_error "project 场景必须提供 --path"
          return 1
        fi
        break
        ;;
    esac
  done
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
  local status="0"

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
  scene_confirm_default "执行以上步骤" "1"
  status="$?"
  if [[ "${status}" != "0" ]]; then
    case "${status}" in
      1|"${SCENE_RC_BACK}"|"${SCENE_RC_EXIT}")
        log_warn "已取消执行。"
        return 1
        ;;
      *)
        return "${status}"
        ;;
    esac
  fi

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
  local status="0"

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
    scene_confirm_default "是否从样例创建配置文件" "1"
    status="$?"
    if [[ "${status}" != "0" ]]; then
      case "${status}" in
        1)
          log_error "未创建配置文件，无法继续执行场景。"
          return 1
          ;;
        "${SCENE_RC_BACK}"|"${SCENE_RC_EXIT}")
          return "${status}"
          ;;
        *)
          return "${status}"
          ;;
      esac
    fi
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

root_config_set_usage() {
  help_init_colors
  help_print_title "Config Set"
  help_print_strong_rule
  help_print_section "用法"
  help_print_rule
  help_print_command "${PROGRAM_NAME} config set --config ./coding-agents/codex/local.conf --set MODE=advanced --set ENABLE_DEFAULT_SKILLS=1"
  help_print_section "参数"
  help_print_rule
  help_print_entry "--config <config>" "目标配置文件"
  help_print_entry "--set KEY=VALUE" "可重复，批量写入配置"
  help_print_note "这是底层配置写入能力，scenario 也复用这条能力。"
}

run_root_config_set() {
  if [[ $# -ge 2 ]]; then
    shift 2
  fi

  while [[ $# -gt 0 ]]; do
    case "${1}" in
      --config)
        [[ $# -ge 2 ]] || {
          log_error "缺少 --config 的值"
          exit 1
        }
        ROOT_CONFIG_FILE="${2}"
        shift 2
        ;;
      --set)
        [[ $# -ge 2 ]] || {
          log_error "缺少 --set 的值"
          exit 1
        }
        ROOT_CONFIG_SET_ITEMS+=("${2}")
        shift 2
        ;;
      --help|-h|help)
        root_config_set_usage
        exit 0
        ;;
      *)
        log_error "不支持的参数：${1}"
        root_config_set_usage
        exit 1
        ;;
    esac
  done

  [[ -n "${ROOT_CONFIG_FILE}" ]] || {
    log_error "必须提供 --config"
    root_config_set_usage
    exit 1
  }
  [[ "${#ROOT_CONFIG_SET_ITEMS[@]}" -gt 0 ]] || {
    log_error "至少提供一个 --set KEY=VALUE"
    root_config_set_usage
    exit 1
  }

  config_apply_set_items "${ROOT_CONFIG_FILE}" "${ROOT_CONFIG_SET_ITEMS[@]}"
  log_info "已写入配置文件：${ROOT_CONFIG_FILE}"
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
  help_init_colors
  help_print_title "已接入工具"
  help_print_strong_rule
  help_print_entry "general-agents" "openclaw"
  help_print_entry "coding-agents" "claude-code | codex | gemini-cli | opencode"
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

if [[ "${COMMAND_GROUP}" == "config" && "${COMMAND_ACTION}" == "set" ]]; then
  run_root_config_set "$@"
  exit $?
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
  list_tools
  exit 1
}

if should_announce_forward; then
  log_info "转发到工具：${TARGET_TOOL}"
fi
exec bash "${TARGET_ENTRY}" "${COMMAND_GROUP}" "${COMMAND_ACTION}" "${FORWARD_ARGS[@]}"
