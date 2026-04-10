#!/usr/bin/env bash

# 顶层共享日志和交互函数，供 scripts/ 下各类工具复用。

timestamp() {
  date '+%Y-%m-%d %H:%M:%S'
}

common_ensure_colors() {
  [[ -n "${HELP_RESET+x}" ]] || help_init_colors
}

common_translate_report_value() {
  local value="${1:-}"

  case "${value}" in
    present)
      value="已存在"
      ;;
    missing)
      value="缺失"
      ;;
  esac

  value="${value//(present)/(已存在)}"
  value="${value//(missing)/(缺失)}"
  printf '%s' "${value}"
}

common_style_report_value() {
  local value=""
  value="$(common_translate_report_value "${1:-}")"

  case "${value}" in
    bash\ manage.sh*|manage.sh*)
      printf '%s%s%s' "${HELP_BLUE}" "${value}" "${HELP_RESET}"
      ;;
    已安装|已启用|已存在|一致|通过|当前状态正常|推荐基线已就绪|增强基线已启用)
      printf '%s%s%s' "${HELP_GREEN}" "${value}" "${HELP_RESET}"
      ;;
    缺失|未安装|未配置|未启用|失败|需人工登录或授权|需人工处理)
      printf '%s%s%s' "${HELP_RED}" "${value}" "${HELP_RESET}"
      ;;
    不一致|未生效|待授权|推荐基线待补齐|工具清单缺失)
      printf '%s%s%s' "${HELP_YELLOW}" "${value}" "${HELP_RESET}"
      ;;
    *)
      printf '%s' "${value}"
      ;;
  esac
}

log_info() {
  common_ensure_colors
  printf '%s[%s]%s %s[INFO]%s %s\n' "${HELP_DIM}" "$(timestamp)" "${HELP_RESET}" "${HELP_BLUE}" "${HELP_RESET}" "$*"
}

log_warn() {
  common_ensure_colors
  printf '%s[%s]%s %s[WARN]%s %s\n' "${HELP_DIM}" "$(timestamp)" "${HELP_RESET}" "${HELP_YELLOW}" "${HELP_RESET}" "$*" >&2
}

log_error() {
  common_ensure_colors
  printf '%s[%s]%s %s[ERROR]%s %s\n' "${HELP_DIM}" "$(timestamp)" "${HELP_RESET}" "${HELP_RED}" "${HELP_RESET}" "$*" >&2
}

print_section() {
  common_ensure_colors
  printf '\n%s%s%s\n' "${HELP_BOLD}${HELP_WHITE}" "$*" "${HELP_RESET}"
  printf '%s%s%s\n' "${HELP_DIM}" "$(help_repeat_char "-" 62)" "${HELP_RESET}"
}

print_report_line() {
  local key="$1"
  local value="$2"
  local styled_value=""

  common_ensure_colors
  styled_value="$(common_style_report_value "${value}")"
  printf '  %s%-24s%s %s\n' "${HELP_BLUE}" "${key}" "${HELP_RESET}" "${styled_value}"
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
    HELP_GREEN=$'\033[38;2;32;140;72m'
    HELP_YELLOW=$'\033[38;2;176;123;0m'
    HELP_RED=$'\033[38;2;180;62;62m'
  else
    HELP_RESET=''
    HELP_BOLD=''
    HELP_DIM=''
    HELP_WHITE=''
    HELP_BLUE=''
    HELP_GREEN=''
    HELP_YELLOW=''
    HELP_RED=''
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

recommended_service_action() {
  local tool_name="$1"
  local runtime_state="$2"
  local config_file="${3:-}"

  if [[ -z "${config_file}" ]]; then
    case "${runtime_state}" in
      未安装)
        printf '补充 --config 后执行 service install'
        ;;
      未生效)
        printf '补充 --config 后执行 service configure'
        ;;
      需人工登录或授权|需人工处理)
        printf '先按未就绪原因完成人工处理，再执行 service configure'
        ;;
      *)
        printf '当前状态正常'
        ;;
    esac
    return 0
  fi

  case "${runtime_state}" in
    未安装)
      printf 'bash manage.sh service install --tool-name %s --config %s' "${tool_name}" "${config_file}"
      ;;
    未生效)
      printf 'bash manage.sh service configure --tool-name %s --config %s' "${tool_name}" "${config_file}"
      ;;
    需人工登录或授权|需人工处理)
      printf '先按未就绪原因完成人工处理，再执行 bash manage.sh service configure --tool-name %s --config %s' "${tool_name}" "${config_file}"
      ;;
    *)
      printf '当前状态正常'
      ;;
  esac
}

append_reason_text() {
  local current="${1:-}"
  local message="${2:-}"

  if [[ -z "${message}" ]]; then
    printf '%s' "${current}"
  elif [[ -z "${current}" ]]; then
    printf '%s' "${message}"
  else
    printf '%s；%s' "${current}" "${message}"
  fi
}

sensitive_endpoint_display_value() {
  local value="${1:-}"
  local empty_label="${2:-未配置}"
  local configured_label="${3:-已配置（已脱敏）}"

  case "${value}" in
    ""|未配置|未声明|未检测到)
      printf '%s' "${empty_label}"
      ;;
    *)
      printf '%s' "${configured_label}"
      ;;
  esac
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

pack_strategy_summary() {
  local common_packs="${1:-}"
  local tool_packs="${2:-}"
  local enhanced_packs="${3:-}"
  local enhanced_enabled="${4:-0}"
  local experimental_packs="${5:-}"
  local experimental_enabled="${6:-0}"
  local current_mode="${MODE:-standard}"
  local enhanced_state="关闭"
  local experimental_state="关闭"

  [[ "${enhanced_enabled}" == "1" ]] && enhanced_state="开启"
  [[ "${experimental_enabled}" == "1" ]] && experimental_state="开启"

  printf '模式=%s | 默认=%s + %s | 进阶=%s (%s) | 探索=%s (%s)' \
    "${current_mode}" \
    "${common_packs:-<空>}" \
    "${tool_packs:-<空>}" \
    "${enhanced_packs:-<空>}" \
    "${enhanced_state}" \
    "${experimental_packs:-<空>}" \
    "${experimental_state}"
}

normalize_mode_profile() {
  MODE="${MODE:-}"

  if [[ -z "${MODE}" ]]; then
    if [[ "${ENABLE_EXPERIMENTAL_PACKS:-0}" == "1" ]]; then
      MODE="exploration"
    elif [[ "${ENABLE_ENHANCED_PACKS:-0}" == "1" ]]; then
      MODE="advanced"
    else
      MODE="standard"
    fi
  fi

  case "${MODE}" in
    standard)
      ENABLE_ENHANCED_PACKS="0"
      ENABLE_EXPERIMENTAL_PACKS="0"
      ;;
    advanced)
      ENABLE_ENHANCED_PACKS="1"
      ENABLE_EXPERIMENTAL_PACKS="0"
      ;;
    exploration)
      ENABLE_ENHANCED_PACKS="1"
      ENABLE_EXPERIMENTAL_PACKS="1"
      ;;
    *)
      log_error "MODE 仅支持 standard|advanced|exploration，收到：${MODE}"
      return 1
      ;;
  esac
}

csv_clean_lines() {
  local input="${1:-}"
  [[ -n "${input}" ]] || return 0
  printf '%s' "${input}" | tr ',' '\n' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' | sed '/^$/d'
}

csv_item_count() {
  local input="${1:-}"
  local count="0"
  count="$(csv_clean_lines "${input}" | awk 'NF { count++ } END { print count + 0 }')"
  [[ -n "${count}" ]] || count="0"
  printf '%s' "${count}"
}

csv_merge_unique() {
  local merged=""
  local chunk=""

  for chunk in "$@"; do
    [[ -n "${chunk:-}" ]] || continue
    if [[ -n "${merged}" ]]; then
      merged="${merged},${chunk}"
    else
      merged="${chunk}"
    fi
  done

  [[ -n "${merged}" ]] || return 0
  csv_clean_lines "${merged}" | awk '!seen[$0]++' | paste -sd, -
}

csv_subtract() {
  local source_csv="${1:-}"
  local remove_csv="${2:-}"

  [[ -n "${source_csv}" ]] || return 0
  if [[ -z "${remove_csv}" ]]; then
    csv_merge_unique "${source_csv}"
    return 0
  fi

  awk '
    NR == FNR {
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", $0)
      if ($0 != "") {
        remove[$0] = 1
      }
      next
    }
    {
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", $0)
      if ($0 != "" && !remove[$0] && !seen[$0]++) {
        print $0
      }
    }
  ' <(csv_clean_lines "${remove_csv}") <(csv_clean_lines "${source_csv}") | paste -sd, -
}

path_state() {
  local target="$1"
  if [[ -e "${target}" ]]; then
    printf 'present'
  else
    printf 'missing'
  fi
}

manifest_field_value() {
  local file_path="$1"
  local field_name="$2"

  [[ -f "${file_path}" ]] || return 0
  awk -F'=' -v field="${field_name}" '$1 == field { print $2; exit }' "${file_path}" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' || true
}

manifest_item_count() {
  local file_path="$1"
  local count=""

  count="$(manifest_field_value "${file_path}" "item_count")"
  [[ -n "${count}" ]] || count="0"
  printf '%s' "${count}"
}

readonly_manifest_scope_default_name() {
  local var_name="${1:-}"

  case "${var_name}" in
    TOOL_PACKS_MANIFEST_PATH)
      printf 'packs.manifest'
      ;;
    TOOL_SKILLS_MANIFEST_PATH)
      printf 'skills.manifest'
      ;;
    TOOL_PLUGINS_MANIFEST_PATH)
      printf 'plugins.manifest'
      ;;
    TOOL_HOOKS_MANIFEST_PATH)
      printf 'hooks.manifest'
      ;;
    TOOL_MCP_MANIFEST_PATH)
      printf 'mcp.manifest'
      ;;
    TOOL_AGENTS_MANIFEST_PATH)
      printf 'agents.manifest'
      ;;
    TOOL_SKILL_STATUS_PATH)
      printf 'skills.status'
      ;;
    TOOL_PLUGIN_STATUS_PATH)
      printf 'plugins.status'
      ;;
    TOOL_AVAILABLE_PLUGINS_JSON_PATH)
      printf 'plugins.available.json'
      ;;
    TOOL_INSTALLED_PLUGINS_JSON_PATH)
      printf 'plugins.installed.json'
      ;;
    TOOL_TRUSTED_PROJECTS_PATH)
      printf 'trusted-projects.list'
      ;;
    *)
      printf '%s.tmp' "$(printf '%s' "${var_name}" | tr '[:upper:]' '[:lower:]')"
      ;;
  esac
}

readonly_manifest_scope_retarget() {
  local var_name="$1"
  local fallback_name="${2:-}"
  local original_path="${!var_name:-}"
  local target_name="${fallback_name:-}"

  if [[ -n "${original_path}" ]]; then
    target_name="$(basename "${original_path}")"
  elif [[ -z "${target_name}" ]]; then
    target_name="$(readonly_manifest_scope_default_name "${var_name}")"
  fi

  printf -v "${var_name}" '%s/%s' "${TOOL_MANIFESTS_DIR}" "${target_name}"
}

readonly_manifest_scope_begin() {
  local extra_var=""

  READONLY_MANIFEST_SCOPE_TMP_DIR="$(mktemp -d)"
  READONLY_MANIFEST_SCOPE_VARS=(
    TOOL_MANIFESTS_DIR
    TOOL_PACKS_MANIFEST_PATH
    TOOL_SKILLS_MANIFEST_PATH
    TOOL_PLUGINS_MANIFEST_PATH
    TOOL_HOOKS_MANIFEST_PATH
    TOOL_MCP_MANIFEST_PATH
    TOOL_AGENTS_MANIFEST_PATH
  )

  for extra_var in "$@"; do
    [[ -n "${extra_var}" ]] || continue
    READONLY_MANIFEST_SCOPE_VARS+=("${extra_var}")
  done

  READONLY_MANIFEST_SCOPE_VALUES=()
  for extra_var in "${READONLY_MANIFEST_SCOPE_VARS[@]}"; do
    READONLY_MANIFEST_SCOPE_VALUES+=("${!extra_var-}")
  done

  TOOL_MANIFESTS_DIR="${READONLY_MANIFEST_SCOPE_TMP_DIR}/manifests"
  mkdir -p "${TOOL_MANIFESTS_DIR}"

  readonly_manifest_scope_retarget TOOL_PACKS_MANIFEST_PATH "packs.manifest"
  readonly_manifest_scope_retarget TOOL_SKILLS_MANIFEST_PATH "skills.manifest"
  readonly_manifest_scope_retarget TOOL_PLUGINS_MANIFEST_PATH "plugins.manifest"
  readonly_manifest_scope_retarget TOOL_HOOKS_MANIFEST_PATH "hooks.manifest"
  readonly_manifest_scope_retarget TOOL_MCP_MANIFEST_PATH "mcp.manifest"
  readonly_manifest_scope_retarget TOOL_AGENTS_MANIFEST_PATH "agents.manifest"

  for extra_var in "$@"; do
    [[ -n "${extra_var}" ]] || continue
    readonly_manifest_scope_retarget "${extra_var}" "$(readonly_manifest_scope_default_name "${extra_var}")"
  done
}

readonly_manifest_scope_end() {
  local idx="0"
  local var_name=""

  [[ -n "${READONLY_MANIFEST_SCOPE_TMP_DIR:-}" ]] || return 0

  for idx in "${!READONLY_MANIFEST_SCOPE_VARS[@]}"; do
    var_name="${READONLY_MANIFEST_SCOPE_VARS[${idx}]}"
    printf -v "${var_name}" '%s' "${READONLY_MANIFEST_SCOPE_VALUES[${idx}]}"
  done

  rm -rf "${READONLY_MANIFEST_SCOPE_TMP_DIR}"
  unset READONLY_MANIFEST_SCOPE_TMP_DIR
  unset READONLY_MANIFEST_SCOPE_VARS
  unset READONLY_MANIFEST_SCOPE_VALUES
}

manifest_list_items() {
  local file_path="$1"
  [[ -f "${file_path}" ]] || return 0

  awk '
    /^items:$/ { in_items=1; next }
    in_items && /^- / {
      line=$0
      sub(/^- /, "", line)
      sub(/ \[source=.*$/, "", line)
      if (line != "" && line != "未声明" && line != "<空>") {
        print line
      }
    }
  ' "${file_path}"
}

manifest_matching_item_count() {
  local file_path="$1"
  local allowed_csv="${2:-}"
  local count="0"

  [[ -n "${allowed_csv}" ]] || {
    printf '0'
    return 0
  }

  count="$(
    manifest_list_items "${file_path}" | while IFS= read -r item; do
      csv_clean_lines "${allowed_csv}" | while IFS= read -r allowed; do
        [[ -n "${allowed}" ]] || continue
        [[ "${item}" == "${allowed}" ]] && printf '%s\n' "${item}"
      done
    done | awk '!seen[$0]++' | awk 'END { print NR + 0 }'
  )"
  [[ -n "${count}" ]] || count="0"
  printf '%s' "${count}"
}

capability_total_item_count() {
  local skills_manifest="${1:-}"
  local plugins_manifest="${2:-}"
  local hooks_manifest="${3:-}"
  local mcp_manifest="${4:-}"
  local agents_manifest="${5:-}"

  printf '%s' "$(
    expr \
      "$(manifest_item_count "${skills_manifest}")" + \
      "$(manifest_item_count "${plugins_manifest}")" + \
      "$(manifest_item_count "${hooks_manifest}")" + \
      "$(manifest_item_count "${mcp_manifest}")" + \
      "$(manifest_item_count "${agents_manifest}")"
  )"
}

capability_core_item_count() {
  local skills_manifest="${1:-}"
  local plugins_manifest="${2:-}"
  local mcp_manifest="${3:-}"
  local core_mcp_csv="${4:-github,context7,filesystem,fetch,playwright}"

  printf '%s' "$(
    expr \
      "$(manifest_item_count "${skills_manifest}")" + \
      "$(manifest_item_count "${plugins_manifest}")" + \
      "$(manifest_matching_item_count "${mcp_manifest}" "${core_mcp_csv}")"
  )"
}

capability_stats_summary() {
  local skills_manifest="${1:-}"
  local plugins_manifest="${2:-}"
  local hooks_manifest="${3:-}"
  local mcp_manifest="${4:-}"
  local agents_manifest="${5:-}"
  local plugin_label="${6:-plugin}"
  local core_mcp_csv="${7:-github,context7,filesystem,fetch,playwright}"
  local total_count="0"
  local core_count="0"

  total_count="$(capability_total_item_count "${skills_manifest}" "${plugins_manifest}" "${hooks_manifest}" "${mcp_manifest}" "${agents_manifest}")"
  core_count="$(capability_core_item_count "${skills_manifest}" "${plugins_manifest}" "${mcp_manifest}" "${core_mcp_csv}")"

  printf '核心 %s 项（skill %s / %s %s / 核心 MCP %s） | 总量 %s 项（skill %s / %s %s / hook %s / mcp %s / agent %s）' \
    "${core_count}" \
    "$(manifest_item_count "${skills_manifest}")" \
    "${plugin_label}" \
    "$(manifest_item_count "${plugins_manifest}")" \
    "$(manifest_matching_item_count "${mcp_manifest}" "${core_mcp_csv}")" \
    "${total_count}" \
    "$(manifest_item_count "${skills_manifest}")" \
    "${plugin_label}" \
    "$(manifest_item_count "${plugins_manifest}")" \
    "$(manifest_item_count "${hooks_manifest}")" \
    "$(manifest_item_count "${mcp_manifest}")" \
    "$(manifest_item_count "${agents_manifest}")"
}

extract_json_string_value() {
  local key="$1"
  local file_path="$2"
  grep -o "\"${key}\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" "${file_path}" 2>/dev/null | head -n 1 | sed 's/.*:[[:space:]]*"//; s/"$//' || true
}

setting_compare_state() {
  local current_value=""
  local target_value=""

  current_value="$(trim_config_value "${1:-}")"
  target_value="$(trim_config_value "${2:-}")"

  if [[ -z "${target_value}" || "${target_value}" == "未声明" ]]; then
    printf '未声明'
    return 0
  fi

  if [[ -z "${current_value}" || "${current_value}" == "未检测到" || "${current_value}" == "未配置" ]]; then
    printf '缺失'
    return 0
  fi

  if [[ "${current_value}" == "${target_value}" ]]; then
    printf '一致'
  else
    printf '不一致'
  fi
}

write_spec_manifest() {
  local path="$1"
  local title="$2"
  local enabled="${3:-0}"
  local explicit_specs="${4:-}"
  local empty_hint="${5:-未声明}"
  local mode="disabled"
  local item_count="0"

  mkdir -p "$(dirname "${path}")"

  if [[ -n "${explicit_specs}" ]]; then
    mode="explicit"
    item_count="$(csv_item_count "${explicit_specs}")"
  elif [[ "${enabled}" == "1" ]]; then
    mode="bootstrap"
  fi

  {
    printf '# %s\n\n' "${title}"
    printf 'enabled=%s\n' "${enabled}"
    printf 'mode=%s\n' "${mode}"
    printf 'item_count=%s\n' "${item_count}"
    printf 'items:\n'
    if [[ -n "${explicit_specs}" ]]; then
      csv_clean_lines "${explicit_specs}" | sed 's/^/- /'
    else
      printf -- '- %s\n' "${empty_hint}"
    fi
  } > "${path}"
}

write_pack_manifest_group() {
  local path="$1"
  local tool_name="$2"
  local heading="$3"
  local packs_csv="${4:-}"
  local group_enabled="${5:-1}"
  local pack_name=""
  local entry_type=""
  local entry_item=""
  local packed_entry=""
  local -a pack_names=()
  local -a pack_entries=()

  printf '## %s\n' "${heading}" >> "${path}"
  printf 'enabled=%s\n' "${group_enabled}" >> "${path}"

  if [[ -z "${packs_csv}" ]]; then
    printf -- '- <空>\n\n' >> "${path}"
    return 0
  fi

  mapfile -t pack_names < <(csv_clean_lines "${packs_csv}")
  for pack_name in "${pack_names[@]}"; do
    [[ -n "${pack_name}" ]] || continue
    if capability_pack_known "${tool_name}" "${pack_name}"; then
      printf -- '- %s (%s 项)\n' "${pack_name}" "$(capability_pack_item_count "${tool_name}" "${pack_name}")" >> "${path}"
      mapfile -t pack_entries < <(capability_pack_entries "${tool_name}" "${pack_name}")
      for packed_entry in "${pack_entries[@]}"; do
        IFS='|' read -r entry_type entry_item <<< "${packed_entry}"
        printf '  - %s:%s\n' "${entry_type}" "${entry_item}" >> "${path}"
      done
    else
      printf -- '- %s (未注册)\n' "${pack_name}" >> "${path}"
    fi
  done

  printf '\n' >> "${path}"
}

write_pack_manifest() {
  local path="$1"
  local tool_name="$2"
  local common_packs="${3:-}"
  local tool_packs="${4:-}"
  local enhanced_packs="${5:-}"
  local enhanced_enabled="${6:-0}"
  local experimental_packs="${7:-}"
  local experimental_enabled="${8:-0}"

  mkdir -p "$(dirname "${path}")"

  {
    printf '# %s 能力包清单\n\n' "${tool_name}"
    printf 'tool=%s\n' "${tool_name}"
    printf 'common_default_packs=%s\n' "${common_packs:-<空>}"
    printf 'tool_default_packs=%s\n' "${tool_packs:-<空>}"
    printf 'enhanced_packs=%s\n' "${enhanced_packs:-<空>}"
    printf 'enhanced_enabled=%s\n' "${enhanced_enabled}"
    printf 'experimental_packs=%s\n' "${experimental_packs:-<空>}"
    printf 'experimental_enabled=%s\n\n' "${experimental_enabled}"
  } > "${path}"

  write_pack_manifest_group "${path}" "${tool_name}" "通用默认包" "${common_packs}" "1"
  write_pack_manifest_group "${path}" "${tool_name}" "工具默认包" "${tool_packs}" "1"
  write_pack_manifest_group "${path}" "${tool_name}" "增强包" "${enhanced_packs}" "${enhanced_enabled}"
  write_pack_manifest_group "${path}" "${tool_name}" "实验包" "${experimental_packs}" "${experimental_enabled}"
}

write_capability_manifest() {
  local path="$1"
  local title="$2"
  local enabled="${3:-0}"
  local explicit_specs="${4:-}"
  local empty_hint="${5:-未声明}"
  local tool_name="${6:-}"
  local capability_type="${7:-}"
  local common_packs="${8:-}"
  local tool_packs="${9:-}"
  local enhanced_packs="${10:-}"
  local enhanced_enabled="${11:-0}"
  local experimental_packs="${12:-}"
  local experimental_enabled="${13:-0}"
  local exclude_specs="${14:-}"
  local resolved_specs=""
  local mode="disabled"
  local item_count="0"
  local item=""
  local -a resolved_items=()

  mkdir -p "$(dirname "${path}")"

  if [[ "${enabled}" == "1" ]]; then
    resolved_specs="$(resolve_capability_items_csv "${tool_name}" "${capability_type}" "${common_packs}" "${tool_packs}" "${enhanced_packs}" "${enhanced_enabled}" "${experimental_packs}" "${experimental_enabled}" "${explicit_specs}" "${exclude_specs}")"
    if [[ -n "${explicit_specs}" ]]; then
      mode="resolved+explicit"
    else
      mode="resolved"
    fi
  else
    resolved_specs="${explicit_specs}"
    if [[ -n "${explicit_specs}" ]]; then
      mode="explicit"
    fi
  fi

  item_count="$(csv_item_count "${resolved_specs}")"

  {
    printf '# %s\n\n' "${title}"
    printf 'enabled=%s\n' "${enabled}"
    printf 'mode=%s\n' "${mode}"
    printf 'type=%s\n' "${capability_type}"
    printf 'common_default_packs=%s\n' "${common_packs:-<空>}"
    printf 'tool_default_packs=%s\n' "${tool_packs:-<空>}"
    printf 'enhanced_packs=%s\n' "${enhanced_packs:-<空>}"
    printf 'enhanced_enabled=%s\n' "${enhanced_enabled}"
    printf 'experimental_packs=%s\n' "${experimental_packs:-<空>}"
    printf 'experimental_enabled=%s\n' "${experimental_enabled}"
    printf 'explicit_specs=%s\n' "${explicit_specs:-<空>}"
    printf 'exclude_specs=%s\n' "${exclude_specs:-<空>}"
    printf 'item_count=%s\n' "${item_count}"
    printf 'items:\n'
    if [[ -n "${resolved_specs}" ]]; then
      mapfile -t resolved_items < <(csv_clean_lines "${resolved_specs}")
      for item in "${resolved_items[@]}"; do
        [[ -n "${item}" ]] || continue
        if declare -F capability_item_manifest_line >/dev/null 2>&1; then
          capability_item_manifest_line "${tool_name}" "${capability_type}" "${item}"
        else
          printf -- '- %s\n' "${item}"
        fi
      done
    else
      printf -- '- %s\n' "${empty_hint}"
    fi
  } > "${path}"
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

    log_error "配置文件格式错误：${config_file}:${line_no}"
    log_error "无效内容：${line}"
    return 1
  done < "${config_file}"
}

require_value() {
  local flag_name="$1"
  local flag_value="${2:-}"
  if [[ -z "${flag_value}" ]]; then
    log_error "缺少参数：${flag_name}"
    return 1
  fi
}

confirm_action() {
  local message="$1"
  local assume_yes="${2:-0}"
  local answer=""

  if [[ "${assume_yes}" == "1" ]]; then
    return 0
  fi

  read -r -p "${message} [y/N]: " answer
  [[ "${answer}" =~ ^([yY][eE][sS]|[yY])$ ]]
}

render_shared_project_bundle_if_missing() {
  local project_root="$1"
  local agents_root="${project_root}/.agents"
  local project_context="${agents_root}/project-context.md"
  local architecture_notes="${agents_root}/architecture.md"
  local workflow_notes="${agents_root}/workflow.md"
  local checklist_notes="${agents_root}/checklist.md"

  mkdir -p "${agents_root}"

  if [[ ! -f "${project_context}" ]]; then
    cat > "${project_context}" <<'EOF'
# 项目上下文

## 目标
- 补充业务目标
- 补充本次阶段成功标准
- 明确验收口径和交付时间点

## 范围
- 当前阶段要做什么
- 当前阶段明确不做什么
- 哪些问题留到下一阶段

## 角色分工
- 规划者：拆分任务、确认边界、列风险和回滚点
- 实现者：按最小变更原则落代码和配置
- 评审者：重点看正确性、安全、性能、稳定性、兼容性
- 测试者：补验证用例、执行关键路径回归、记录结果
- 发布者：确认配置变更、发布顺序、回滚路径和观察指标

## 技术栈
- 语言：
- 框架：
- 基础设施：

## 关键路径
- 入口模块：
- 核心服务：
- 数据存储：
- 对外接口：

## 常用命令
- 安装：
- 开发：
- 测试：
- 构建：
- 发布：

## 测试基线
- 单元测试入口：
- 集成测试入口：
- 端到端测试入口：
- 静态检查入口：
- 冒烟验证步骤：

## 默认约束
- 不改无关代码
- 先最小变更，再做扩展
- 涉及配置、迁移、权限的变更必须补充说明

## 持续记忆
- 关键业务假设：
- 已确认的架构决策：
- 当前已知坑点：
- 待跟进事项：
- 最近一次失败原因与修复方式：

## 建议协作方式
- 先读 `.agents/architecture.md` 再动核心模块
- 先写最小可验证实现，再补测试和文档
- 每次交付都写清验证结果、剩余风险、回滚方式
- 关键结论确认后，及时回写本文件，避免重复踩坑
EOF
  fi

  if [[ ! -f "${architecture_notes}" ]]; then
    cat > "${architecture_notes}" <<'EOF'
# 架构记录

## 模块边界
- 列出核心模块
- 标注每个模块职责
- 标出最容易受影响的模块

## 关键数据流
- 请求从哪里进入
- 在哪里处理
- 最终输出到哪里
- 哪些步骤存在缓存、队列、异步任务

## 外部依赖
- API：
- 数据库：
- 缓存 / 队列：
- 文件 / 对象存储：
- 第三方平台：

## 可观测性与测试点
- 关键日志：
- 核心指标：
- 告警条件：
- 单元测试重点：
- 集成测试重点：
- 冒烟路径：

## 安全与稳定性关注点
- 权限边界：
- 敏感配置：
- 高风险路径：
- 限流 / 重试 / 超时：

## 架构决策记录
- 日期：
  变更背景：
  决策内容：
  影响范围：
  回滚方式：

## 变更注意
- 变更前先确认影响范围
- 结构调整后及时更新本文件
- 涉及接口或数据结构变更时同步更新调用方
- 影响测试或发布路径时同步更新 `.agents/checklist.md`
EOF
  fi

  if [[ ! -f "${workflow_notes}" ]]; then
    cat > "${workflow_notes}" <<'EOF'
# 开发工作流

1. 先读 `project-context.md` 和 `architecture.md`
2. 变更前确认影响面、风险和回滚路径
3. 优先做最小可验证实现
4. 再补测试、文档和配置同步
5. 交付前按 `checklist.md` 自检

## 建议执行顺序
- 先确认目标和边界
- 再确认受影响模块和外部依赖
- 再动手实现
- 再做验证、文档、配置同步

## 角色协作顺序
- 规划：先拆成可验证的小步骤，再开始实现
- 实现：每次只改一组相关文件，避免无关扩散
- 评审：优先看高风险路径、边界条件、失败场景
- 测试：先跑最小必需验证，再补关键路径回归
- 发布：确认依赖、配置、数据迁移、回滚和观察指标

## 记忆维护规则
- 新增约束、已知坑点、关键命令后，回写 `project-context.md`
- 架构边界、依赖、数据流变化后，回写 `architecture.md`
- 工作流、发布步骤变化后，回写本文件
- 交付标准变化后，回写 `checklist.md`

## 测试执行建议
- 先做静态检查和格式检查
- 再做单元测试
- 涉及接口、数据库、任务编排时补集成测试
- 涉及用户主路径时补冒烟或端到端验证
- 未执行的测试要明确说明原因和风险

## 评审重点
- 正确性
- 安全
- 性能
- 稳定性
- 配置一致性
- 兼容性
- 可回滚性

## 输出约定
- 先给结论，再给原因
- 明确说明验证方式
- 明确说明剩余风险
- 涉及配置、数据、权限时明确写出变更点

## 发布建议
- 发布前确认配置同步、数据兼容、回滚命令和观察指标
- 发布后优先看错误日志、核心指标、告警和关键业务路径
- 如需灰度，先写清灰度范围、扩大条件和回退条件
EOF
  fi

  if [[ ! -f "${checklist_notes}" ]]; then
    cat > "${checklist_notes}" <<'EOF'
# 交付检查单

## 需求与范围
- 需求是否已覆盖
- 当前阶段明确要做和不做的内容是否一致
- 是否影响无关模块
- 影响范围是否已说明

## 代码与配置
- 配置是否同步
- 文档是否同步
- 权限、密钥、迁移、定时任务等变更是否已说明
- 默认值、兼容逻辑、失败分支是否检查

## 测试与验证
- 静态检查是否完成
- 单元测试是否完成
- 集成测试或冒烟验证是否完成
- 未执行的测试是否说明原因
- 失败场景和回归路径是否考虑

## 安全与稳定性
- 安全与权限边界是否确认
- 限流、超时、重试、幂等是否确认
- 日志、监控、告警观察点是否明确

## 发布与回滚
- 发布顺序是否清楚
- 数据或配置变更是否可回滚
- 回滚命令和回滚条件是否清楚
- 发布后验证步骤是否清楚
EOF
  fi
}

render_shared_role_templates_if_missing() {
  local agents_dir="$1"
  local planner_path="${agents_dir}/planner.md"
  local implementer_path="${agents_dir}/implementer.md"
  local reviewer_path="${agents_dir}/reviewer.md"
  local tester_path="${agents_dir}/tester.md"

  mkdir -p "${agents_dir}"

  if [[ ! -f "${planner_path}" ]]; then
    cat > "${planner_path}" <<'EOF'
# Planner

## 目标
- 先明确本次任务目标、边界、验收标准
- 把任务拆成可验证的小步骤
- 先列风险、依赖、回滚点，再进入实现

## 必读
- `.agents/project-context.md`
- `.agents/architecture.md`
- `.agents/workflow.md`

## 输出要求
- 结论优先
- 明确范围内 / 范围外事项
- 明确风险、依赖、验证方式、回滚方式
- 每个步骤都尽量做到可独立验收
EOF
  fi

  if [[ ! -f "${implementer_path}" ]]; then
    cat > "${implementer_path}" <<'EOF'
# Implementer

## 目标
- 按最小变更原则完成实现
- 不改无关代码
- 同步配置、文档、脚本和必要测试

## 必读
- `.agents/project-context.md`
- `.agents/architecture.md`
- `.agents/workflow.md`
- `.agents/checklist.md`

## 执行要求
- 先确认影响范围，再开始改动
- 一次只处理一组强相关变更
- 涉及配置、权限、迁移、发布时同步补说明
- 交付时明确变更点、验证结果、剩余风险
EOF
  fi

  if [[ ! -f "${reviewer_path}" ]]; then
    cat > "${reviewer_path}" <<'EOF'
# Reviewer

## 目标
- 优先发现正确性、安全、性能、稳定性、兼容性问题
- 检查配置、文档、测试是否和实现一致

## 必读
- `.agents/architecture.md`
- `.agents/workflow.md`
- `.agents/checklist.md`

## 评审重点
- 是否存在行为回归
- 是否破坏边界条件和失败路径
- 是否遗漏权限、限流、超时、重试、回滚考虑
- 是否缺少必要测试或发布说明

## 输出要求
- 发现按严重级别排序
- 先列问题，再给摘要
- 无问题时明确写“未发现问题”，并说明残余风险
EOF
  fi

  if [[ ! -f "${tester_path}" ]]; then
    cat > "${tester_path}" <<'EOF'
# Tester

## 目标
- 为本次变更设计并执行最小必需验证
- 记录已执行、未执行和建议补充的测试

## 必读
- `.agents/project-context.md`
- `.agents/workflow.md`
- `.agents/checklist.md`

## 测试顺序
- 先静态检查和格式检查
- 再单元测试
- 再集成测试或冒烟验证
- 涉及用户主路径时补端到端验证

## 输出要求
- 明确测试命令和结果
- 明确未执行项及原因
- 明确失败场景覆盖情况
- 明确上线后建议观察点
EOF
  fi
}

render_shared_global_governance_templates_if_missing() {
  local agents_dir="$1"
  local governance_path="${agents_dir}/global-governance.md"
  local standards_path="${agents_dir}/engineering-standards.md"
  local delivery_path="${agents_dir}/delivery-checklist.md"
  local memory_rules_path="${agents_dir}/memory-rules.md"

  mkdir -p "${agents_dir}"

  if [[ ! -f "${governance_path}" ]]; then
    cat > "${governance_path}" <<'EOF'
# 全局治理约定

## 目标
- 让全局默认行为长期稳定、可维护、可复用
- 先守住安全、正确性、稳定性，再追求速度
- 不把项目私有决策塞进全局治理文件

## 适用范围
- 适用于当前工具的所有全局会话
- 只放长期有效的工程规则、协作方式和交付门槛
- 项目特有目标、业务上下文、临时发布安排，回写到项目目录

## 默认工作方式
- 先确认目标、边界、影响范围和回滚方式
- 先做最小可验证变更，再补测试、文档和配置同步
- 先查已有实现和现有规范，不重复造轮子
- 涉及权限、密钥、迁移、发布的改动必须明确说明

## 全局边界
- 不改无关代码
- 不默认放宽高风险权限
- 不把临时排查命令当作长期基线
- 不覆盖用户已有的项目级约束

## 交付要求
- 结论优先
- 明确验证方式和结果
- 明确剩余风险和未执行项
- 涉及配置、发布、迁移时明确回滚路径
EOF
  fi

  if [[ ! -f "${standards_path}" ]]; then
    cat > "${standards_path}" <<'EOF'
# 工程规范

## 变更原则
- 优先最小变更
- 先兼容再替换
- 配置、代码、文档保持一致
- 高风险变更前先明确影响面

## 代码要求
- 先理解现有实现，再修改
- 公共能力优先复用现有模块
- 命名、目录、配置项保持见名知意
- 非必要不引入新依赖、新进程、新中间层

## 安全与稳定性
- 默认最小权限
- 敏感信息只做状态展示，不在报告中明文输出
- 涉及网络、文件、执行权限时，优先保持可审计
- 涉及超时、重试、限流、幂等时明确默认策略

## 性能与维护
- 优先保关键路径稳定
- 避免把一次性脚本写成长期复杂框架
- 能用工具官方能力解决，就不要再包一层抽象
- 新增能力要能被检查、回放和恢复
EOF
  fi

  if [[ ! -f "${delivery_path}" ]]; then
    cat > "${delivery_path}" <<'EOF'
# 交付检查单

## 变更前
- 目标和边界是否清楚
- 影响范围是否识别
- 依赖和前置条件是否确认
- 回滚方式是否明确

## 变更中
- 是否保持最小变更
- 是否同步更新配置、模板、文档
- 是否记录人工步骤和例外情况
- 是否避免影响无关能力

## 变更后
- 是否完成最小必需验证
- 是否说明未执行验证及原因
- 是否说明剩余风险和观察点
- 是否确认当前状态与目标状态一致
EOF
  fi

  if [[ ! -f "${memory_rules_path}" ]]; then
    cat > "${memory_rules_path}" <<'EOF'
# 记忆回写规则

## 该写什么
- 长期有效的工程约束
- 反复出现的已知坑点
- 稳定可复用的命令、流程和检查单
- 明确生效范围的架构决策

## 不写什么
- 临时调试输出
- 一次性业务数据
- 只对单个项目有效的上下文
- 未确认的猜测结论

## 回写时机
- 新约束确认后
- 关键失败原因定位后
- 发布或恢复流程调整后
- 默认能力包、权限边界、协作方式变化后

## 回写要求
- 写清楚结论、适用范围、触发条件
- 尽量短，避免堆流水账
- 与项目私有记忆分开维护
EOF
  fi
}

render_shared_global_role_templates_if_missing() {
  local agents_dir="$1"
  local planner_path="${agents_dir}/planner.md"
  local implementer_path="${agents_dir}/implementer.md"
  local reviewer_path="${agents_dir}/reviewer.md"
  local tester_path="${agents_dir}/tester.md"

  mkdir -p "${agents_dir}"

  if [[ ! -f "${planner_path}" ]]; then
    cat > "${planner_path}" <<'EOF'
# Planner

## 必读
- `global-governance.md`
- `engineering-standards.md`
- `delivery-checklist.md`

## 目标
- 先明确目标、边界、风险和回滚方式
- 把任务拆成可验证的小步骤
- 先确认全局约束，再进入实现
EOF
  fi

  if [[ ! -f "${implementer_path}" ]]; then
    cat > "${implementer_path}" <<'EOF'
# Implementer

## 必读
- `global-governance.md`
- `engineering-standards.md`
- `delivery-checklist.md`
- `memory-rules.md`

## 执行要求
- 优先最小变更
- 不改无关代码
- 配置、模板、文档、验证同步完成
- 新增长期规则时及时回写全局记忆
EOF
  fi

  if [[ ! -f "${reviewer_path}" ]]; then
    cat > "${reviewer_path}" <<'EOF'
# Reviewer

## 必读
- `global-governance.md`
- `engineering-standards.md`
- `delivery-checklist.md`

## 评审重点
- 正确性
- 安全
- 性能
- 稳定性
- 配置一致性
- 可回滚性
EOF
  fi

  if [[ ! -f "${tester_path}" ]]; then
    cat > "${tester_path}" <<'EOF'
# Tester

## 必读
- `engineering-standards.md`
- `delivery-checklist.md`
- `memory-rules.md`

## 验证要求
- 先最小必需验证，再补关键路径
- 明确已执行、未执行和建议补充项
- 关键失败原因和回归方式要可回写、可复用
EOF
  fi
}

managed_global_governance_state() {
  local agents_dir="$1"
  local total="4"
  local present="0"
  local file_path=""

  for file_path in \
    "${agents_dir}/global-governance.md" \
    "${agents_dir}/engineering-standards.md" \
    "${agents_dir}/delivery-checklist.md" \
    "${agents_dir}/memory-rules.md"; do
    [[ -f "${file_path}" ]] && present=$((present + 1))
  done

  printf '%s/%s' "${present}" "${total}"
}

managed_global_governance_ready() {
  [[ "$(managed_global_governance_state "${1}")" == "4/4" ]]
}

managed_global_role_state() {
  local agents_dir="$1"
  local total="4"
  local present="0"
  local file_path=""

  for file_path in \
    "${agents_dir}/planner.md" \
    "${agents_dir}/implementer.md" \
    "${agents_dir}/reviewer.md" \
    "${agents_dir}/tester.md"; do
    [[ -f "${file_path}" ]] && present=$((present + 1))
  done

  printf '%s/%s' "${present}" "${total}"
}

managed_global_role_ready() {
  [[ "$(managed_global_role_state "${1}")" == "4/4" ]]
}

show_placeholder_result() {
  local tool_name="$1"
  local command_group="$2"
  local command_action="$3"

  print_section "${tool_name}"
  log_info "已进入骨架命令：${command_group} ${command_action}"
  log_info "后续会在这里补齐真实实现。"
}

COMMON_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${COMMON_LIB_DIR}/capability_packs.sh" ]]; then
  # shellcheck disable=SC1091
  source "${COMMON_LIB_DIR}/capability_packs.sh"
fi
