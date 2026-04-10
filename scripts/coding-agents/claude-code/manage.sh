#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../../shared/lib/common.sh"

PROGRAM_NAME="$(basename "$0")"
COMMAND_GROUP="${1:-help}"
COMMAND_ACTION="${2:-}"
CONFIG_FILE=""
TARGET_PATH=""
TARGET_SCOPE=""
TARGET_SECTION=""
ASSUME_YES=0

usage() {
  help_init_colors
  help_print_title "Claude Code"
  help_print_strong_rule
  help_print_context "最短入口" "manage.sh guide start --tool-name claude-code"
  help_print_context "配置文件" "./local.conf"

  help_print_section "主命令"
  help_print_rule
  help_print_entry "service install" "首次安装"
  help_print_entry "service configure" "增强 / 接管"
  help_print_entry "config init" "初始化模板"
  help_print_entry "service report" "状态概览"
  help_print_entry "service check" "详细检查"

  help_print_section "快速上手"
  help_print_rule
  help_print_step "1" "manage.sh guide start --tool-name claude-code"
  help_print_step "2" "${PROGRAM_NAME} service install --config ./local.conf --yes"
  help_print_step "3" "${PROGRAM_NAME} service check --config ./local.conf"

  help_print_section "常见场景"
  help_print_rule
  help_print_case "首次安装" "${PROGRAM_NAME} service install --config ./local.conf --yes"
  help_print_case "已装增强 / 接管" "${PROGRAM_NAME} service configure --config ./local.conf --yes"
  help_print_case "项目模板" "${PROGRAM_NAME} config init --config ./local.conf --scope project --path /workspace/project --yes"
  help_print_case "查看状态" "${PROGRAM_NAME} service report --config ./local.conf"

  help_print_section "按需能力"
  help_print_rule
  help_print_entry "service update" "升级工具"
  help_print_entry "service uninstall" "卸载工具"
  help_print_entry "config backup / restore" "备份 / 恢复"
  help_print_entry "config show" "配置摘要"
}

die() {
  log_error "$*"
  exit 1
}

ensure_command() {
  command -v "$1" >/dev/null 2>&1 || die "缺少必要命令：$1"
}

require_root() {
  [[ "$(id -u)" -eq 0 ]] || die "请使用 root 运行该命令。"
}

parse_args() {
  if [[ $# -gt 0 ]]; then
    shift
  fi
  if [[ $# -gt 0 ]]; then
    shift
  fi

  while [[ $# -gt 0 ]]; do
    case "${1}" in
      --config)
        CONFIG_FILE="${2:-}"
        require_value "--config" "${CONFIG_FILE}" || exit 1
        shift 2
        ;;
      --path)
        TARGET_PATH="${2:-}"
        require_value "--path" "${TARGET_PATH}" || exit 1
        shift 2
        ;;
      --scope)
        TARGET_SCOPE="${2:-}"
        require_value "--scope" "${TARGET_SCOPE}" || exit 1
        shift 2
        ;;
      --section)
        TARGET_SECTION="${2:-}"
        require_value "--section" "${TARGET_SECTION}" || exit 1
        shift 2
        ;;
      --yes)
        ASSUME_YES=1
        shift
        ;;
      --help|-h|help)
        usage
        exit 0
        ;;
      *)
        die "不支持的参数：${1}"
        ;;
    esac
  done
}

json_escape() {
  printf '%s' "${1}" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

json_array_from_csv() {
  local input="${1:-}"
  local first=1
  local item=""

  printf '['
  IFS=',' read -r -a _items <<< "${input}"
  for item in "${_items[@]}"; do
    item="$(printf '%s' "${item}" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
    [[ -n "${item}" ]] || continue
    if [[ "${first}" -eq 0 ]]; then
      printf ', '
    fi
    printf '"%s"' "$(json_escape "${item}")"
    first=0
  done
  printf ']'
}

path_like_spec() {
  case "${1:-}" in
    /*|./*|../*)
      return 0
      ;;
  esac
  return 1
}

url_like_spec() {
  case "${1:-}" in
    http://*|https://*)
      return 0
      ;;
  esac
  return 1
}

github_repo_like_spec() {
  case "${1:-}" in
    */*)
      if [[ "${1}" == *" "* || "${1}" == *@* || "${1}" == *":"* ]]; then
        return 1
      fi
      return 0
      ;;
  esac
  return 1
}

normalize_config() {
  INSTALL_METHOD="${INSTALL_METHOD:-npm}"
  CLAUDE_PACKAGE="${CLAUDE_PACKAGE:-@anthropic-ai/claude-code@latest}"
  AUTH_MODE="${AUTH_MODE:-api-key}"
  DEFAULT_MODEL="${DEFAULT_MODEL:-claude-sonnet-4-6}"
  ANTHROPIC_API_KEY="${ANTHROPIC_API_KEY:-}"
  ANTHROPIC_AUTH_TOKEN="${ANTHROPIC_AUTH_TOKEN:-}"
  ANTHROPIC_BASE_URL="${ANTHROPIC_BASE_URL:-}"
  API_TIMEOUT_MS="${API_TIMEOUT_MS:-600000}"
  CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC="${CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC:-1}"
  CLAUDE_SKIP_ONBOARDING="${CLAUDE_SKIP_ONBOARDING:-1}"
  ENABLE_DEFAULT_SKILLS="${ENABLE_DEFAULT_SKILLS:-1}"
  ENABLE_DEFAULT_PLUGINS="${ENABLE_DEFAULT_PLUGINS:-1}"
  ENABLE_DEFAULT_HOOKS="${ENABLE_DEFAULT_HOOKS:-1}"
  ENABLE_DEFAULT_MCP="${ENABLE_DEFAULT_MCP:-1}"
  ENABLE_DEFAULT_AGENTS="${ENABLE_DEFAULT_AGENTS:-1}"
  MODE="${MODE:-}"
  COMMON_DEFAULT_PACKS="${COMMON_DEFAULT_PACKS:-common-core,common-docs-architecture,common-quality,common-backend,common-frontend}"
  TOOL_DEFAULT_PACKS="${TOOL_DEFAULT_PACKS:-claude-workflow,claude-review}"
  ENHANCED_PACKS="${ENHANCED_PACKS:-claude-ui,claude-memory,claude-ecosystem,enhanced-browser-deep,enhanced-long-memory,enhanced-observability}"
  ENABLE_ENHANCED_PACKS="${ENABLE_ENHANCED_PACKS:-0}"
  EXPERIMENTAL_PACKS="${EXPERIMENTAL_PACKS:-experimental-bleeding-edge}"
  ENABLE_EXPERIMENTAL_PACKS="${ENABLE_EXPERIMENTAL_PACKS:-0}"
  SKILL_SPECS="${SKILL_SPECS:-}"
  SKILL_EXCLUDES="${SKILL_EXCLUDES:-}"
  PLUGIN_SPECS="${PLUGIN_SPECS:-}"
  PLUGIN_EXCLUDES="${PLUGIN_EXCLUDES:-}"
  HOOK_SPECS="${HOOK_SPECS:-}"
  HOOK_EXCLUDES="${HOOK_EXCLUDES:-}"
  MCP_SPECS="${MCP_SPECS:-}"
  MCP_EXCLUDES="${MCP_EXCLUDES:-}"
  AGENT_SPECS="${AGENT_SPECS:-}"
  AGENT_EXCLUDES="${AGENT_EXCLUDES:-}"
  PERMISSIONS_ALLOW="${PERMISSIONS_ALLOW:-}"
  PERMISSIONS_DENY="${PERMISSIONS_DENY:-}"
  normalize_mode_profile

  GLOBAL_CLAUDE_DIR="${GLOBAL_CLAUDE_DIR:-/root/.claude}"
  GLOBAL_SETTINGS_PATH="${GLOBAL_SETTINGS_PATH:-${GLOBAL_CLAUDE_DIR}/settings.json}"
  GLOBAL_SETTINGS_LOCAL_PATH="${GLOBAL_SETTINGS_LOCAL_PATH:-${GLOBAL_CLAUDE_DIR}/settings.local.json}"
  GLOBAL_CLAUDE_MD_PATH="${GLOBAL_CLAUDE_MD_PATH:-${GLOBAL_CLAUDE_DIR}/CLAUDE.md}"
  GLOBAL_PLUGINS_DIR="${GLOBAL_PLUGINS_DIR:-${GLOBAL_CLAUDE_DIR}/plugins}"
  GLOBAL_SKILLS_DIR="${GLOBAL_SKILLS_DIR:-${GLOBAL_CLAUDE_DIR}/skills}"
  GLOBAL_AGENTS_DIR="${GLOBAL_AGENTS_DIR:-${GLOBAL_CLAUDE_DIR}/agents}"
  GLOBAL_SESSION_PATH="${GLOBAL_SESSION_PATH:-/root/.claude.json}"
  GLOBAL_PLUGINS_NOTE_PATH="${GLOBAL_PLUGINS_DIR}/README.managed.md"
  GLOBAL_SKILLS_NOTE_PATH="${GLOBAL_SKILLS_DIR}/README.managed.md"
  GLOBAL_AGENTS_NOTE_PATH="${GLOBAL_AGENTS_DIR}/README.managed.md"

  TOOL_RUNTIME_ROOT="${TOOL_RUNTIME_ROOT:-${SCRIPT_DIR}}"
  BACKUP_ROOT="${BACKUP_ROOT:-${TOOL_RUNTIME_ROOT}/backups}"
  TOOL_CONFIG_DIR="${TOOL_RUNTIME_ROOT}/config"
  TOOL_GLOBAL_DIR="${TOOL_CONFIG_DIR}/global"
  TOOL_SETTINGS_PATH="${TOOL_GLOBAL_DIR}/settings.json"
  TOOL_SETTINGS_LOCAL_PATH="${TOOL_GLOBAL_DIR}/settings.local.json"
  TOOL_CLAUDE_MD_PATH="${TOOL_GLOBAL_DIR}/CLAUDE.md"
  TOOL_ONBOARDING_PATH="${TOOL_GLOBAL_DIR}/claude.json"
  TOOL_MANIFESTS_DIR="${TOOL_RUNTIME_ROOT}/manifests"
  TOOL_PACKS_MANIFEST_PATH="${TOOL_MANIFESTS_DIR}/packs.manifest"
  TOOL_SKILLS_MANIFEST_PATH="${TOOL_MANIFESTS_DIR}/skills.manifest"
  TOOL_PLUGINS_MANIFEST_PATH="${TOOL_MANIFESTS_DIR}/plugins.manifest"
  TOOL_PLUGIN_STATUS_PATH="${TOOL_MANIFESTS_DIR}/plugins.status"
  TOOL_AVAILABLE_PLUGINS_JSON_PATH="${TOOL_MANIFESTS_DIR}/plugins.available.json"
  TOOL_INSTALLED_PLUGINS_JSON_PATH="${TOOL_MANIFESTS_DIR}/plugins.installed.json"
  TOOL_HOOKS_MANIFEST_PATH="${TOOL_MANIFESTS_DIR}/hooks.manifest"
  TOOL_MCP_MANIFEST_PATH="${TOOL_MANIFESTS_DIR}/mcp.manifest"
  TOOL_AGENTS_MANIFEST_PATH="${TOOL_MANIFESTS_DIR}/agents.manifest"
}

refresh_plugin_plan() {
  if [[ "${ENABLE_DEFAULT_PLUGINS}" == "1" ]]; then
    RESOLVED_PLUGIN_SPECS="$(resolve_installable_capability_items_csv "claude-code" "plugin" "repl-plugin" "${COMMON_DEFAULT_PACKS}" "${TOOL_DEFAULT_PACKS}" "${ENHANCED_PACKS}" "${ENABLE_ENHANCED_PACKS}" "${EXPERIMENTAL_PACKS}" "${ENABLE_EXPERIMENTAL_PACKS}" "${PLUGIN_SPECS}" "${PLUGIN_EXCLUDES}")"
  else
    RESOLVED_PLUGIN_SPECS="$(csv_subtract "${PLUGIN_SPECS}" "${PLUGIN_EXCLUDES}")"
  fi
}

require_config() {
  [[ -n "${CONFIG_FILE}" ]] || die "必须提供 --config"
  [[ -f "${CONFIG_FILE}" ]] || die "配置文件不存在：${CONFIG_FILE}"
  load_key_value_config "${CONFIG_FILE}" || die "配置文件解析失败：${CONFIG_FILE}"
  normalize_config
  refresh_plugin_plan
}

load_config_if_present() {
  if [[ -n "${CONFIG_FILE}" ]]; then
    require_config
  else
    normalize_config
    refresh_plugin_plan
  fi
}

claude_external_source_like_spec() {
  case "${1:-}" in
    github:*)
      return 0
      ;;
  esac

  if url_like_spec "${1:-}" || path_like_spec "${1:-}" || github_repo_like_spec "${1:-}"; then
    return 0
  fi

  return 1
}

claude_plugin_explicit_name_from_spec() {
  local spec="${1:-}"
  if [[ "${spec}" == *"@"* ]]; then
    printf '%s' "${spec%@*}"
  fi
}

claude_plugin_source_spec_from_spec() {
  local spec="${1:-}"
  local rhs=""

  if [[ "${spec}" == *"@"* ]]; then
    rhs="${spec#*@}"
    if claude_external_source_like_spec "${rhs}"; then
      printf '%s' "${rhs}"
      return 0
    fi
  fi

  if claude_external_source_like_spec "${spec}"; then
    printf '%s' "${spec}"
    return 0
  fi

  return 1
}

claude_plugin_name_hint_from_source_spec() {
  local source_spec="${1:-}"
  local normalized="${source_spec#github:}"
  local name=""

  name="${normalized%%\?*}"
  name="${name%/}"
  name="${name##*/}"
  name="${name%.git}"
  name="${name%-plugin}"
  name="${name%-plugins}"
  name="${name%-skill}"
  name="${name%-skills}"
  name="${name%-marketplace}"
  printf '%s' "${name}"
}

claude_plugin_name_from_spec() {
  local spec="${1:-}"
  local explicit_name=""
  local source_spec=""

  explicit_name="$(claude_plugin_explicit_name_from_spec "${spec}")"
  if [[ -n "${explicit_name}" ]]; then
    printf '%s' "${explicit_name}"
    return 0
  fi

  source_spec="$(claude_plugin_source_spec_from_spec "${spec}" || true)"
  if [[ -n "${source_spec}" ]]; then
    printf '%s' "$(claude_plugin_name_hint_from_source_spec "${source_spec}")"
    return 0
  fi

  printf '%s' "${spec}"
}

claude_plugin_source_add_arg() {
  local source_spec="${1:-}"

  case "${source_spec}" in
    github:*)
      printf '%s' "${source_spec#github:}"
      ;;
    /*|./*|../*)
      if [[ "${source_spec}" == /* ]]; then
        printf '%s' "${source_spec}"
      elif command -v realpath >/dev/null 2>&1; then
        realpath -m "${source_spec}"
      else
        printf '%s' "${source_spec}"
      fi
      ;;
    *)
      printf '%s' "${source_spec}"
      ;;
  esac
}

claude_known_marketplace_name_from_source_spec() {
  local source_spec="${1:-}"
  local known_file="${GLOBAL_PLUGINS_DIR}/known_marketplaces.json"
  local add_arg=""

  [[ -f "${known_file}" ]] || return 1
  add_arg="$(claude_plugin_source_add_arg "${source_spec}")"

  case "${source_spec}" in
    github:*)
      awk -v needle="${add_arg}" '
        /^[[:space:]]*"[^"]+": \{$/ {
          current=$1
          gsub(/[":]/, "", current)
        }
        index($0, "\"repo\": \"" needle "\"") {
          print current
          exit
        }
      ' "${known_file}"
      ;;
    http://*|https://*)
      awk -v needle="${add_arg}" '
        /^[[:space:]]*"[^"]+": \{$/ {
          current=$1
          gsub(/[":]/, "", current)
        }
        index($0, "\"url\": \"" needle "\"") {
          print current
          exit
        }
      ' "${known_file}"
      ;;
    *)
      awk -v needle="${add_arg}" '
        /^[[:space:]]*"[^"]+": \{$/ {
          current=$1
          gsub(/[":]/, "", current)
        }
        index($0, "\"installLocation\": \"" needle "\"") {
          print current
          exit
        }
      ' "${known_file}"
      ;;
  esac
}

claude_available_plugin_names_for_marketplace() {
  local marketplace_name="${1:-}"

  [[ -n "${marketplace_name}" && -f "${TOOL_AVAILABLE_PLUGINS_JSON_PATH}" ]] || return 0

  awk -v marketplace="${marketplace_name}" '
    BEGIN { RS="},"; FS="\n" }
    index($0, "\"marketplaceName\": \"" marketplace "\"") {
      for (i = 1; i <= NF; i++) {
        if ($i ~ /"name":[[:space:]]*"/) {
          line = $i
          sub(/.*"name":[[:space:]]*"/, "", line)
          sub(/".*/, "", line)
          print line
          break
        }
      }
    }
  ' "${TOOL_AVAILABLE_PLUGINS_JSON_PATH}"
}

claude_plugin_resolved_name_from_spec() {
  local spec="${1:-}"
  local explicit_name=""
  local source_spec=""
  local marketplace_name=""
  local hint_name=""
  local candidate=""
  local -a available_names=()

  explicit_name="$(claude_plugin_explicit_name_from_spec "${spec}")"
  if [[ -n "${explicit_name}" ]]; then
    printf '%s' "${explicit_name}"
    return 0
  fi

  source_spec="$(claude_plugin_source_spec_from_spec "${spec}" || true)"
  if [[ -z "${source_spec}" ]]; then
    printf '%s' "${spec}"
    return 0
  fi

  marketplace_name="$(claude_known_marketplace_name_from_source_spec "${source_spec}" || true)"
  [[ -n "${marketplace_name}" ]] || return 1

  mapfile -t available_names < <(claude_available_plugin_names_for_marketplace "${marketplace_name}")
  if [[ "${#available_names[@]}" -eq 1 ]]; then
    printf '%s' "${available_names[0]}"
    return 0
  fi

  hint_name="$(claude_plugin_name_hint_from_source_spec "${source_spec}")"
  for candidate in "${available_names[@]}"; do
    [[ "${candidate}" == "${hint_name}" ]] && {
      printf '%s' "${candidate}"
      return 0
    }
  done

  return 1
}

claude_plugin_marketplace_from_spec() {
  local spec="${1:-}"
  local rhs=""
  local source_spec=""

  if [[ "${spec}" == *"@"* ]]; then
    rhs="${spec#*@}"
    if ! claude_external_source_like_spec "${rhs}"; then
      printf '%s' "${rhs}"
      return 0
    fi
  fi

  source_spec="$(claude_plugin_source_spec_from_spec "${spec}" || true)"
  if [[ -n "${source_spec}" ]]; then
    claude_known_marketplace_name_from_source_spec "${source_spec}"
    return 0
  fi

  printf 'claude-plugins-official'
}

claude_plugin_install_arg_from_spec() {
  local spec="${1:-}"
  local plugin_name=""
  local marketplace_name=""

  plugin_name="$(claude_plugin_resolved_name_from_spec "${spec}" || true)"
  marketplace_name="$(claude_plugin_marketplace_from_spec "${spec}" || true)"
  [[ -n "${plugin_name}" && -n "${marketplace_name}" ]] || return 1
  printf '%s@%s' "${plugin_name}" "${marketplace_name}"
}

claude_plugin_source_hint_from_spec() {
  local spec="${1:-}"
  local source_spec=""
  local install_arg=""

  source_spec="$(claude_plugin_source_spec_from_spec "${spec}" || true)"
  if [[ -n "${source_spec}" ]]; then
    printf '%s' "${source_spec}"
    return 0
  fi

  install_arg="$(claude_plugin_install_arg_from_spec "${spec}" || true)"
  if [[ -n "${install_arg}" ]]; then
    printf '%s' "${install_arg}"
    return 0
  fi

  printf '%s' "${spec}"
}

ensure_runtime_layout() {
  mkdir -p \
    "${TOOL_RUNTIME_ROOT}" \
    "${TOOL_GLOBAL_DIR}" \
    "${BACKUP_ROOT}" \
    "${TOOL_MANIFESTS_DIR}" \
    "${GLOBAL_CLAUDE_DIR}" \
    "${GLOBAL_PLUGINS_DIR}" \
    "${GLOBAL_SKILLS_DIR}" \
    "${GLOBAL_AGENTS_DIR}"
}

ensure_runtime_workspace() {
  mkdir -p \
    "${TOOL_RUNTIME_ROOT}" \
    "${TOOL_GLOBAL_DIR}" \
    "${BACKUP_ROOT}" \
    "${TOOL_MANIFESTS_DIR}"
}

backup_path_if_exists() {
  local src="$1"
  local label="$2"
  local stamp=""
  local dest=""

  [[ -e "${src}" ]] || return 0
  stamp="$(date '+%Y%m%d-%H%M%S')"
  dest="${BACKUP_ROOT}/$(basename "${src}").${stamp}.bak"
  cp -a "${src}" "${dest}"
  log_info "已备份${label}：${dest}"
}

ensure_node_runtime() {
  if command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1; then
    return 0
  fi

  require_root
  ensure_command curl
  log_info "未检测到 Node.js / npm，开始按 NodeSource 安装 Node.js 24"
  curl -fsSL https://deb.nodesource.com/setup_24.x | bash -
  apt-get install -y nodejs
}

claude_binary_path() {
  command -v claude 2>/dev/null || true
}

claude_version_value() {
  if command -v claude >/dev/null 2>&1; then
    claude --version 2>&1 | tail -n 1
  else
    printf '未安装'
  fi
}

snapshot_plugin_inventory() {
  mkdir -p "$(dirname "${TOOL_INSTALLED_PLUGINS_JSON_PATH}")"

  if ! command -v claude >/dev/null 2>&1; then
    printf '{ "installed": [] }\n' > "${TOOL_INSTALLED_PLUGINS_JSON_PATH}"
    printf '{ "installed": [], "available": [] }\n' > "${TOOL_AVAILABLE_PLUGINS_JSON_PATH}"
    return 1
  fi

  if ! claude plugin list --json > "${TOOL_INSTALLED_PLUGINS_JSON_PATH}" 2>/dev/null; then
    printf '{ "installed": [] }\n' > "${TOOL_INSTALLED_PLUGINS_JSON_PATH}"
  fi

  if ! claude plugin list --json --available > "${TOOL_AVAILABLE_PLUGINS_JSON_PATH}" 2>/dev/null; then
    printf '{ "installed": [], "available": [] }\n' > "${TOOL_AVAILABLE_PLUGINS_JSON_PATH}"
  fi

  return 0
}

plugin_list_json_contains_plugin() {
  local json_path="$1"
  local install_arg="$2"
  local plugin_name="$3"

  [[ -f "${json_path}" ]] || return 1

  grep -F "\"id\": \"${install_arg}\"" "${json_path}" >/dev/null 2>&1 && return 0
  grep -F "\"pluginId\": \"${install_arg}\"" "${json_path}" >/dev/null 2>&1 && return 0
  grep -F "\"name\": \"${plugin_name}\"" "${json_path}" >/dev/null 2>&1 && return 0
  return 1
}

ensure_plugin_marketplace_from_source_spec() {
  local source_spec="${1:-}"
  local add_arg=""
  local marketplace_name=""

  [[ -n "${source_spec}" ]] || return 0
  marketplace_name="$(claude_known_marketplace_name_from_source_spec "${source_spec}" || true)"
  if [[ -n "${marketplace_name}" ]]; then
    return 0
  fi

  add_arg="$(claude_plugin_source_add_arg "${source_spec}")"
  if claude plugin marketplace add "${add_arg}" --scope user >/dev/null 2>&1; then
    log_info "已接入第三方 marketplace：${source_spec}"
  else
    log_warn "接入第三方 marketplace 失败：${source_spec}"
  fi
}

write_plugin_status_snapshot() {
  local spec=""
  local name=""
  local resolved_name=""
  local install_arg=""
  local source_spec=""
  local marketplace_name=""
  local source=""
  local status=""
  local detail=""
  local -a plugin_specs=()

  mkdir -p "$(dirname "${TOOL_PLUGIN_STATUS_PATH}")"
  snapshot_plugin_inventory || true

  {
    printf '# Claude Code plugin 状态\n'
    printf 'name|status|source|detail\n'
  } > "${TOOL_PLUGIN_STATUS_PATH}"

  mapfile -t plugin_specs < <(csv_clean_lines "${RESOLVED_PLUGIN_SPECS}")
  for spec in "${plugin_specs[@]}"; do
    [[ -n "${spec}" ]] || continue
    name="$(claude_plugin_name_from_spec "${spec}")"
    resolved_name="$(claude_plugin_resolved_name_from_spec "${spec}" || true)"
    install_arg="$(claude_plugin_install_arg_from_spec "${spec}" || true)"
    source_spec="$(claude_plugin_source_spec_from_spec "${spec}" || true)"
    marketplace_name="$(claude_plugin_marketplace_from_spec "${spec}" || true)"
    source="$(claude_plugin_source_hint_from_spec "${spec}")"

    if [[ -n "${install_arg}" ]] && plugin_list_json_contains_plugin "${TOOL_INSTALLED_PLUGINS_JSON_PATH}" "${install_arg}" "${resolved_name:-${name}}"; then
      status="已安装"
      detail="${install_arg}"
    elif [[ -n "${install_arg}" ]] && plugin_list_json_contains_plugin "${TOOL_AVAILABLE_PLUGINS_JSON_PATH}" "${install_arg}" "${resolved_name:-${name}}"; then
      status="缺失"
      detail="${install_arg}"
    elif [[ -n "${source_spec}" && -z "${marketplace_name}" ]]; then
      status="缺失"
      detail="第三方 marketplace 未接入：${source}"
    elif [[ -n "${source_spec}" ]]; then
      status="需人工处理"
      detail="已接入 marketplace，但未能唯一确定 plugin 名，请显式写 plugin@source"
    else
      status="缺失"
      detail="当前 marketplace 未收录该插件"
    fi

    printf '%s|%s|%s|%s\n' "${resolved_name:-${name}}" "${status}" "${source}" "${detail}" >> "${TOOL_PLUGIN_STATUS_PATH}"
  done
}

plugin_status_count() {
  local target_status="${1:-}"

  [[ -f "${TOOL_PLUGIN_STATUS_PATH}" ]] || {
    printf '0'
    return 0
  }

  awk -F'|' -v target="${target_status}" 'NR > 2 && $2 == target { count++ } END { print count + 0 }' "${TOOL_PLUGIN_STATUS_PATH}"
}

plugin_status_summary() {
  printf '已安装 %s / 缺失 %s / 需人工处理 %s' \
    "$(plugin_status_count "已安装")" \
    "$(plugin_status_count "缺失")" \
    "$(plugin_status_count "需人工处理")"
}

plugin_status_names_csv() {
  local target_status="${1:-}"

  [[ -f "${TOOL_PLUGIN_STATUS_PATH}" ]] || return 0

  awk -F'|' -v target="${target_status}" '
    NR > 2 && $2 == target {
      names[++count] = $1
    }
    END {
      for (i = 1; i <= count; i++) {
        printf "%s%s", names[i], (i < count ? "," : "")
      }
    }
  ' "${TOOL_PLUGIN_STATUS_PATH}"
}

sync_plugins() {
  local mode="${1:-安装}"
  local spec=""
  local source_spec=""
  local install_arg=""
  local plugin_name=""
  local -a plugin_specs=()

  ensure_runtime_layout

  if [[ -z "${RESOLVED_PLUGIN_SPECS}" ]]; then
    write_plugin_status_snapshot
    return 0
  fi

  if ! command -v claude >/dev/null 2>&1; then
    log_warn "Claude Code 未安装，跳过 plugin 处理。"
    write_plugin_status_snapshot
    return 0
  fi

  if [[ "${mode}" == "更新" ]]; then
    if claude plugin marketplace update >/dev/null 2>&1; then
      log_info "已刷新 Claude Code marketplaces"
    else
      log_warn "刷新 Claude Code marketplaces 失败，继续按当前列表处理"
    fi
  fi

  mapfile -t plugin_specs < <(csv_clean_lines "${RESOLVED_PLUGIN_SPECS}")
  for spec in "${plugin_specs[@]}"; do
    [[ -n "${spec}" ]] || continue
    source_spec="$(claude_plugin_source_spec_from_spec "${spec}" || true)"
    [[ -n "${source_spec}" ]] || continue
    ensure_plugin_marketplace_from_source_spec "${source_spec}"
  done

  snapshot_plugin_inventory || true

  for spec in "${plugin_specs[@]}"; do
    [[ -n "${spec}" ]] || continue
    plugin_name="$(claude_plugin_resolved_name_from_spec "${spec}" || true)"
    install_arg="$(claude_plugin_install_arg_from_spec "${spec}" || true)"

    if [[ -z "${plugin_name}" || -z "${install_arg}" ]]; then
      log_warn "plugin 规格无法自动解析，跳过：${spec}"
      continue
    fi

    if plugin_list_json_contains_plugin "${TOOL_INSTALLED_PLUGINS_JSON_PATH}" "${install_arg}" "${plugin_name}"; then
      if [[ "${mode}" == "更新" ]]; then
        if claude plugin update "${plugin_name}" >/dev/null 2>&1; then
          log_info "已更新 plugin：${plugin_name}"
        else
          log_warn "更新 plugin 失败，保留现状：${plugin_name}"
        fi
      else
        log_info "plugin 已存在，跳过：${plugin_name}"
      fi
      continue
    fi

    if ! plugin_list_json_contains_plugin "${TOOL_AVAILABLE_PLUGINS_JSON_PATH}" "${install_arg}" "${plugin_name}"; then
      log_warn "当前 marketplace 未找到 plugin，跳过：${install_arg}"
      continue
    fi

    if claude plugin install "${install_arg}" --scope user >/dev/null 2>&1; then
      log_info "已安装 plugin：${install_arg}"
    else
      log_warn "安装 plugin 失败：${install_arg}"
    fi
  done

  write_plugin_status_snapshot
}

claude_runtime_state() {
  local claude_path="${1:-}"
  local settings_exists="${2:-no}"
  local auth_mode="${3:-未检测到}"

  if [[ -z "${claude_path}" ]]; then
    printf '未安装'
  elif [[ "${settings_exists}" != "yes" ]]; then
    printf '未配置'
  elif [[ "${auth_mode}" == "未检测到" ]]; then
    printf '需人工登录或授权'
  elif [[ "$(plugin_status_count "需人工处理")" != "0" ]]; then
    printf '需人工处理'
  elif [[ "$(plugin_status_count "缺失")" != "0" ]]; then
    printf '未生效'
  else
    printf '已安装'
  fi
}

claude_best_practice_readiness() {
  local claude_path="${1:-}"
  local settings_exists="${2:-no}"
  local auth_mode="${3:-未检测到}"

  if [[ -z "${claude_path}" ]]; then
    printf '未安装'
  elif [[ "${settings_exists}" != "yes" ]]; then
    printf '未配置'
  elif [[ "${auth_mode}" == "未检测到" ]]; then
    printf '待授权'
  elif [[ ! -f "${TOOL_PACKS_MANIFEST_PATH}" || ! -f "${TOOL_PLUGINS_MANIFEST_PATH}" || ! -f "${TOOL_PLUGIN_STATUS_PATH}" ]]; then
    printf '工具清单缺失'
  elif [[ "$(plugin_status_count "需人工处理")" != "0" ]]; then
    printf '需人工处理'
  elif [[ "$(plugin_status_count "缺失")" != "0" ]]; then
    printf '推荐基线待补齐'
  elif [[ "${ENABLE_ENHANCED_PACKS}" == "1" || "${ENABLE_EXPERIMENTAL_PACKS}" == "1" ]]; then
    printf '增强基线已启用'
  else
    printf '推荐基线已就绪'
  fi
}

claude_onboarding_state_value() {
  local session_path="${1:-${GLOBAL_SESSION_PATH}}"

  if [[ ! -f "${session_path}" ]]; then
    printf '缺失'
  elif grep -Eq '"hasCompletedOnboarding"[[:space:]]*:[[:space:]]*true' "${session_path}"; then
    printf '已启用'
  else
    printf '未启用'
  fi
}

claude_base_url_display_value() {
  local value="${1:-}"
  local empty_label="${2:-未配置}"
  local configured_label="${3:-已配置（已脱敏）}"

  sensitive_endpoint_display_value "${value}" "${empty_label}" "${configured_label}"
}

render_onboarding_state_json() {
  cat > "${TOOL_ONBOARDING_PATH}" <<EOF
{
  "hasCompletedOnboarding": $( [[ "${CLAUDE_SKIP_ONBOARDING}" == "1" ]] && printf 'true' || printf 'false' )
}
EOF
}

sync_onboarding_state() {
  if [[ "${CLAUDE_SKIP_ONBOARDING}" != "1" ]]; then
    log_info "已按配置跳过 ~/.claude.json 自动写入。"
    return 0
  fi

  backup_path_if_exists "${GLOBAL_SESSION_PATH}" "Claude 引导状态文件"
  if command -v node >/dev/null 2>&1; then
    node - "${GLOBAL_SESSION_PATH}" <<'EOF'
const fs = require("fs");
const targetPath = process.argv[2];
let payload = {};

if (fs.existsSync(targetPath)) {
  try {
    const parsed = JSON.parse(fs.readFileSync(targetPath, "utf8"));
    if (parsed && typeof parsed === "object" && !Array.isArray(parsed)) {
      payload = parsed;
    }
  } catch (_) {
    payload = {};
  }
}

payload.hasCompletedOnboarding = true;
fs.writeFileSync(targetPath, JSON.stringify(payload, null, 2) + "\n");
EOF
  else
    install -m 600 "${TOOL_ONBOARDING_PATH}" "${GLOBAL_SESSION_PATH}"
  fi
  log_info "已同步引导跳过文件：${GLOBAL_SESSION_PATH}"
}

render_settings_json() {
  cat > "${TOOL_SETTINGS_PATH}" <<EOF
{
  "model": "$(json_escape "${DEFAULT_MODEL}")",
  "env": {
EOF

  if [[ -n "${ANTHROPIC_API_KEY}" ]]; then
    printf '    "ANTHROPIC_API_KEY": "%s"' "$(json_escape "${ANTHROPIC_API_KEY}")" >> "${TOOL_SETTINGS_PATH}"
  elif [[ -n "${ANTHROPIC_AUTH_TOKEN}" ]]; then
    printf '    "ANTHROPIC_AUTH_TOKEN": "%s"' "$(json_escape "${ANTHROPIC_AUTH_TOKEN}")" >> "${TOOL_SETTINGS_PATH}"
  else
    printf '    "CLAUDE_PLACEHOLDER": ""' >> "${TOOL_SETTINGS_PATH}"
  fi

  if [[ -n "${ANTHROPIC_BASE_URL}" ]]; then
    printf ',\n    "ANTHROPIC_BASE_URL": "%s"' "$(json_escape "${ANTHROPIC_BASE_URL}")" >> "${TOOL_SETTINGS_PATH}"
  fi
  printf ',\n    "API_TIMEOUT_MS": %s' "$(json_escape "${API_TIMEOUT_MS}")" >> "${TOOL_SETTINGS_PATH}"
  printf ',\n    "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC": "%s"\n' "$(json_escape "${CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC}")" >> "${TOOL_SETTINGS_PATH}"
  cat >> "${TOOL_SETTINGS_PATH}" <<EOF
  },
  "permissions": {
    "allow": [],
    "deny": []
  }
}
EOF
}

render_settings_local_template() {
  cat > "${TOOL_SETTINGS_LOCAL_PATH}" <<EOF
{
  "permissions": {
    "allow": $(json_array_from_csv "${PERMISSIONS_ALLOW}"),
    "deny": $(json_array_from_csv "${PERMISSIONS_DENY}")
  }
}
EOF
}

render_claude_md_if_missing() {
  if [[ -f "${TOOL_CLAUDE_MD_PATH}" ]]; then
    return 0
  fi

  cat > "${TOOL_CLAUDE_MD_PATH}" <<'EOF'
# Claude Code 全局工作习惯

## 偏好
- 回复使用中文
- 先给结论，再补原因
- 不改无关代码

## 常用约束
- 变更前先看现有实现
- 高风险命令前给出明确提示
- 优先用项目已有工具链
EOF
}

render_runtime_manifests() {
  write_pack_manifest "${TOOL_PACKS_MANIFEST_PATH}" "claude-code" "${COMMON_DEFAULT_PACKS}" "${TOOL_DEFAULT_PACKS}" "${ENHANCED_PACKS}" "${ENABLE_ENHANCED_PACKS}" "${EXPERIMENTAL_PACKS}" "${ENABLE_EXPERIMENTAL_PACKS}"
  write_capability_manifest "${TOOL_SKILLS_MANIFEST_PATH}" "Claude Code skill 初始化清单" "${ENABLE_DEFAULT_SKILLS}" "${SKILL_SPECS}" "默认仅初始化 ~/.claude/skills 目录结构" "claude-code" "skill" "${COMMON_DEFAULT_PACKS}" "${TOOL_DEFAULT_PACKS}" "${ENHANCED_PACKS}" "${ENABLE_ENHANCED_PACKS}" "${EXPERIMENTAL_PACKS}" "${ENABLE_EXPERIMENTAL_PACKS}" "${SKILL_EXCLUDES}"
  write_capability_manifest "${TOOL_PLUGINS_MANIFEST_PATH}" "Claude Code plugin 初始化清单" "${ENABLE_DEFAULT_PLUGINS}" "${PLUGIN_SPECS}" "默认仅初始化 ~/.claude/plugins 目录结构" "claude-code" "plugin" "${COMMON_DEFAULT_PACKS}" "${TOOL_DEFAULT_PACKS}" "${ENHANCED_PACKS}" "${ENABLE_ENHANCED_PACKS}" "${EXPERIMENTAL_PACKS}" "${ENABLE_EXPERIMENTAL_PACKS}" "${PLUGIN_EXCLUDES}"
  write_capability_manifest "${TOOL_HOOKS_MANIFEST_PATH}" "Claude Code hook 初始化清单" "${ENABLE_DEFAULT_HOOKS}" "${HOOK_SPECS}" "默认保留为空，按团队约定再补" "claude-code" "hook" "${COMMON_DEFAULT_PACKS}" "${TOOL_DEFAULT_PACKS}" "${ENHANCED_PACKS}" "${ENABLE_ENHANCED_PACKS}" "${EXPERIMENTAL_PACKS}" "${ENABLE_EXPERIMENTAL_PACKS}" "${HOOK_EXCLUDES}"
  write_capability_manifest "${TOOL_MCP_MANIFEST_PATH}" "Claude Code MCP 初始化清单" "${ENABLE_DEFAULT_MCP}" "${MCP_SPECS}" "默认保留为空，按实际服务器再接入" "claude-code" "mcp" "${COMMON_DEFAULT_PACKS}" "${TOOL_DEFAULT_PACKS}" "${ENHANCED_PACKS}" "${ENABLE_ENHANCED_PACKS}" "${EXPERIMENTAL_PACKS}" "${ENABLE_EXPERIMENTAL_PACKS}" "${MCP_EXCLUDES}"
  write_capability_manifest "${TOOL_AGENTS_MANIFEST_PATH}" "Claude Code agent 初始化清单" "${ENABLE_DEFAULT_AGENTS}" "${AGENT_SPECS}" "默认初始化 ~/.claude/agents 目录结构" "claude-code" "agent" "${COMMON_DEFAULT_PACKS}" "${TOOL_DEFAULT_PACKS}" "${ENHANCED_PACKS}" "${ENABLE_ENHANCED_PACKS}" "${EXPERIMENTAL_PACKS}" "${ENABLE_EXPERIMENTAL_PACKS}" "${AGENT_EXCLUDES}"
}

render_support_notes_if_missing() {
  if [[ ! -f "${GLOBAL_PLUGINS_NOTE_PATH}" ]]; then
    cat > "${GLOBAL_PLUGINS_NOTE_PATH}" <<'EOF'
# Claude Plugins 目录说明

- 这里放 Claude Code 相关的全局插件
- 建议把安装说明和依赖要求一并写清楚
EOF
  fi

  if [[ ! -f "${GLOBAL_SKILLS_NOTE_PATH}" ]]; then
    cat > "${GLOBAL_SKILLS_NOTE_PATH}" <<'EOF'
# Claude Skills 目录说明

- 这里放 Claude Code 的全局 skills
- 公共流程、检查单、规范优先收敛到这里
EOF
  fi

  if [[ ! -f "${GLOBAL_AGENTS_NOTE_PATH}" ]]; then
    cat > "${GLOBAL_AGENTS_NOTE_PATH}" <<'EOF'
# Claude Agents 目录说明

- 这里放 Claude Code 全局 agents / role 模板
- 与单个项目强绑定的内容优先写回项目目录
EOF
  fi
}

render_project_template_if_missing() {
  local project_root="$1"
  local project_claude_dir="${project_root}/.claude"
  local project_doc="${project_root}/CLAUDE.md"
  local project_settings="${project_claude_dir}/settings.json"
  local project_settings_local="${project_claude_dir}/settings.local.json"
  local project_skills_note="${project_claude_dir}/skills/README.managed.md"
  local project_agents_dir="${project_claude_dir}/agents"
  local project_agents_note="${project_claude_dir}/agents/README.managed.md"

  mkdir -p "${project_claude_dir}/skills" "${project_agents_dir}" "${project_claude_dir}/rules"
  render_shared_project_bundle_if_missing "${project_root}"
  render_shared_role_templates_if_missing "${project_agents_dir}"

  if [[ ! -f "${project_doc}" ]]; then
    cat > "${project_doc}" <<'EOF'
# 项目协作约定

## 先读这些文件
- `.agents/project-context.md`
- `.agents/architecture.md`
- `.agents/workflow.md`
- `.agents/checklist.md`

## 默认约束
- 不改无关代码
- 不引入未讨论的新依赖
- 先做最小变更，再补测试和文档

## 默认分工
- 需求与边界：看 `.agents/project-context.md`
- 架构与风险：看 `.agents/architecture.md`
- 执行与发布：看 `.agents/workflow.md`
- 测试与交付：看 `.agents/checklist.md`

## Claude Code 项目要求
- 权限放行优先最小化，项目内额外放行写到 `.claude/settings.local.json`
- 项目专用 skills 和 agents 优先放到 `.claude/skills`、`.claude/agents`
- 重要决策、关键失败原因和回滚方式及时回写 `.agents` 文档
EOF
  fi

  if [[ ! -f "${project_settings}" ]]; then
    cat > "${project_settings}" <<EOF
{
  "model": "$(json_escape "${DEFAULT_MODEL}")"
}
EOF
  fi

  if [[ ! -f "${project_settings_local}" ]]; then
    cat > "${project_settings_local}" <<'EOF'
{
  "permissions": {
    "allow": [],
    "deny": []
  }
}
EOF
  fi

  if [[ ! -f "${project_skills_note}" ]]; then
    cat > "${project_skills_note}" <<'EOF'
# 项目 Skills 目录

- 放当前项目专用 skills
- 项目流程、命令模板、发布检查单优先写这里
- 适合沉淀固定评审提示词、测试流程、设计约束
EOF
  fi

  if [[ ! -f "${project_agents_note}" ]]; then
    cat > "${project_agents_note}" <<'EOF'
# 项目 Agents 目录

- 放当前项目专用 agents / role 模板
- 全局通用内容请回收到 ~/.claude/agents
- 建议至少拆分：规划、实现、评审、测试、发布观察
- 默认已生成：`planner.md`、`implementer.md`、`reviewer.md`、`tester.md`
EOF
  fi
}

sync_global_config() {
  local plugin_mode="${1:-安装}"

  ensure_runtime_layout
  render_settings_json
  render_settings_local_template
  render_onboarding_state_json
  render_claude_md_if_missing
  render_runtime_manifests
  render_support_notes_if_missing
  render_shared_global_governance_templates_if_missing "${GLOBAL_AGENTS_DIR}"
  render_shared_global_role_templates_if_missing "${GLOBAL_AGENTS_DIR}"

  backup_path_if_exists "${GLOBAL_SETTINGS_PATH}" "Claude settings.json"
  install -m 600 "${TOOL_SETTINGS_PATH}" "${GLOBAL_SETTINGS_PATH}"
  log_info "已同步全局 settings.json：${GLOBAL_SETTINGS_PATH}"

  if [[ ! -f "${GLOBAL_SETTINGS_LOCAL_PATH}" ]]; then
    install -m 600 "${TOOL_SETTINGS_LOCAL_PATH}" "${GLOBAL_SETTINGS_LOCAL_PATH}"
    log_info "已初始化 settings.local.json：${GLOBAL_SETTINGS_LOCAL_PATH}"
  else
    log_info "保留现有 settings.local.json：${GLOBAL_SETTINGS_LOCAL_PATH}"
  fi

  if [[ ! -f "${GLOBAL_CLAUDE_MD_PATH}" ]]; then
    install -m 644 "${TOOL_CLAUDE_MD_PATH}" "${GLOBAL_CLAUDE_MD_PATH}"
    log_info "已初始化全局 CLAUDE.md：${GLOBAL_CLAUDE_MD_PATH}"
  else
    log_info "保留现有全局 CLAUDE.md：${GLOBAL_CLAUDE_MD_PATH}"
  fi

  sync_onboarding_state

  sync_plugins "${plugin_mode}"
  log_info "已生成初始化清单：${TOOL_PACKS_MANIFEST_PATH}、${TOOL_SKILLS_MANIFEST_PATH}、${TOOL_PLUGINS_MANIFEST_PATH}、${TOOL_HOOKS_MANIFEST_PATH}、${TOOL_MCP_MANIFEST_PATH}、${TOOL_AGENTS_MANIFEST_PATH}"
}

print_summary() {
  print_section "Claude Code 配置摘要"
  log_info "安装方式：${INSTALL_METHOD}"
  log_info "模型：${DEFAULT_MODEL}"
  log_info "认证方式：${AUTH_MODE}"
  log_info "跳过登录引导：${CLAUDE_SKIP_ONBOARDING}"
  if [[ -n "${ANTHROPIC_BASE_URL}" ]]; then
    log_info "自定义 Base URL：$(claude_base_url_display_value "${ANTHROPIC_BASE_URL}")"
  fi
  log_info "官方目录：${GLOBAL_CLAUDE_DIR}"
  log_info "工具目录：${TOOL_RUNTIME_ROOT}"
}

cmd_service_install_like() {
  local mode="$1"
  require_config
  require_root
  print_summary

  if ! confirm_action "将${mode} Claude Code 并同步全局配置，是否继续？" "${ASSUME_YES}"; then
    log_warn "已取消执行。"
    exit 0
  fi

  ensure_node_runtime
  case "${INSTALL_METHOD}" in
    npm)
      npm install -g "${CLAUDE_PACKAGE}"
      ;;
    *)
      die "当前仅实现 INSTALL_METHOD=npm，收到：${INSTALL_METHOD}"
      ;;
  esac

  sync_global_config "${mode}"
  log_info "Claude Code 当前版本：$(claude_version_value)"
}

cmd_service_uninstall() {
  require_config
  require_root

  if ! confirm_action "将卸载 Claude Code CLI，但默认保留 ~/.claude 与 ~/.claude.json，是否继续？" "${ASSUME_YES}"; then
    log_warn "已取消执行。"
    exit 0
  fi

  case "${INSTALL_METHOD}" in
    npm)
      if npm list -g @anthropic-ai/claude-code --depth=0 >/dev/null 2>&1; then
        npm uninstall -g @anthropic-ai/claude-code
        log_info "已卸载 npm 全局包：@anthropic-ai/claude-code"
      else
        log_warn "未发现 npm 全局包 @anthropic-ai/claude-code，跳过卸载。"
      fi
      ;;
    *)
      die "当前仅实现 INSTALL_METHOD=npm，收到：${INSTALL_METHOD}"
      ;;
  esac
}

cmd_service_check() {
  local claude_path=""
  local runtime_state=""
  local not_ready_reason=""
  local settings_exists="no"
  local settings_local_exists="no"
  local claude_md_exists="no"
  local plugins_exists="no"
  local skills_exists="no"
  local agents_exists="no"
  local onboarding_state="缺失"
  local current_model="未检测到"
  local auth_mode="未检测到"
  local base_url="未检测到"
  local plugin_missing_count="0"
  local plugin_missing_names=""
  local plugin_manual_names=""
  local plugin_summary="未检测到"
  local readiness_summary="未检测到"
  local capability_stats="未检测到"
  local capability_counts="skill 0 / plugin 0 / hook 0 / mcp 0 / agent 0"
  local global_governance_state="0/4"
  local global_role_state="0/4"

  load_config_if_present
  readonly_manifest_scope_begin TOOL_PLUGIN_STATUS_PATH TOOL_AVAILABLE_PLUGINS_JSON_PATH TOOL_INSTALLED_PLUGINS_JSON_PATH
  render_runtime_manifests
  claude_path="$(claude_binary_path)"

  print_section "Claude Code 检查"
  print_report_line "Claude 命令" "${claude_path:-未安装}"
  print_report_line "Claude 版本" "$(claude_version_value)"

  if npm list -g @anthropic-ai/claude-code --depth=0 >/dev/null 2>&1; then
    print_report_line "npm 全局包" "@anthropic-ai/claude-code 已安装"
  else
    print_report_line "npm 全局包" "未检测到"
  fi

  [[ -f "${GLOBAL_SETTINGS_PATH}" ]] && settings_exists="yes"
  [[ -f "${GLOBAL_SETTINGS_LOCAL_PATH}" ]] && settings_local_exists="yes"
  [[ -f "${GLOBAL_CLAUDE_MD_PATH}" ]] && claude_md_exists="yes"
  [[ -d "${GLOBAL_PLUGINS_DIR}" ]] && plugins_exists="yes"
  [[ -d "${GLOBAL_SKILLS_DIR}" ]] && skills_exists="yes"
  [[ -d "${GLOBAL_AGENTS_DIR}" ]] && agents_exists="yes"
  global_governance_state="$(managed_global_governance_state "${GLOBAL_AGENTS_DIR}")"
  global_role_state="$(managed_global_role_state "${GLOBAL_AGENTS_DIR}")"
  onboarding_state="$(claude_onboarding_state_value "${GLOBAL_SESSION_PATH}")"

  if [[ -f "${GLOBAL_SETTINGS_PATH}" ]]; then
    current_model="$(extract_json_string_value "model" "${GLOBAL_SETTINGS_PATH}")"
    [[ -n "${current_model}" ]] || current_model="未检测到"
    if grep -q '"ANTHROPIC_AUTH_TOKEN"' "${GLOBAL_SETTINGS_PATH}"; then
      auth_mode="auth-token"
    elif grep -q '"ANTHROPIC_API_KEY"' "${GLOBAL_SETTINGS_PATH}"; then
      auth_mode="api-key"
    fi
    base_url="$(extract_json_string_value "ANTHROPIC_BASE_URL" "${GLOBAL_SETTINGS_PATH}")"
    [[ -n "${base_url}" ]] || base_url="未配置"
  fi

  write_plugin_status_snapshot
  runtime_state="$(claude_runtime_state "${claude_path}" "${settings_exists}" "${auth_mode}")"
  plugin_missing_count="$(plugin_status_count "缺失")"
  plugin_missing_names="$(plugin_status_names_csv "缺失")"
  plugin_manual_names="$(plugin_status_names_csv "需人工处理")"
  plugin_summary="$(plugin_status_summary)"
  readiness_summary="$(claude_best_practice_readiness "${claude_path}" "${settings_exists}" "${auth_mode}")"
  capability_stats="$(capability_stats_summary "${TOOL_SKILLS_MANIFEST_PATH}" "${TOOL_PLUGINS_MANIFEST_PATH}" "${TOOL_HOOKS_MANIFEST_PATH}" "${TOOL_MCP_MANIFEST_PATH}" "${TOOL_AGENTS_MANIFEST_PATH}" "plugin")"
  capability_counts="skill $(manifest_item_count "${TOOL_SKILLS_MANIFEST_PATH}") / plugin $(manifest_item_count "${TOOL_PLUGINS_MANIFEST_PATH}") / hook $(manifest_item_count "${TOOL_HOOKS_MANIFEST_PATH}") / mcp $(manifest_item_count "${TOOL_MCP_MANIFEST_PATH}") / agent $(manifest_item_count "${TOOL_AGENTS_MANIFEST_PATH}")"
  if [[ "${readiness_summary}" == "推荐基线已就绪" || "${readiness_summary}" == "增强基线已启用" ]]; then
    if ! managed_global_governance_ready "${GLOBAL_AGENTS_DIR}" || ! managed_global_role_ready "${GLOBAL_AGENTS_DIR}"; then
      readiness_summary="推荐基线待补齐"
    fi
  fi
  readonly_manifest_scope_end

  case "${runtime_state}" in
    未安装)
      not_ready_reason="$(append_reason_text "${not_ready_reason}" "未检测到 claude 命令")"
      ;;
    未配置)
      not_ready_reason="$(append_reason_text "${not_ready_reason}" "缺少 settings.json")"
      ;;
    需人工登录或授权)
      not_ready_reason="$(append_reason_text "${not_ready_reason}" "当前认证信息未检测到")"
      ;;
  esac

  if [[ -n "${CONFIG_FILE}" ]]; then
    [[ "$(setting_compare_state "${current_model}" "${DEFAULT_MODEL}")" == "不一致" ]] && not_ready_reason="$(append_reason_text "${not_ready_reason}" "模型与目标不一致")"
    [[ "$(setting_compare_state "${current_model}" "${DEFAULT_MODEL}")" == "缺失" ]] && not_ready_reason="$(append_reason_text "${not_ready_reason}" "当前模型未配置")"
    [[ "$(setting_compare_state "${auth_mode}" "${AUTH_MODE}")" == "不一致" ]] && not_ready_reason="$(append_reason_text "${not_ready_reason}" "认证模式与目标不一致")"
    [[ "$(setting_compare_state "${base_url}" "${ANTHROPIC_BASE_URL:-}")" == "不一致" ]] && not_ready_reason="$(append_reason_text "${not_ready_reason}" "Base URL 与目标不一致")"
  fi

  [[ "${plugin_missing_count}" != "0" ]] && not_ready_reason="$(append_reason_text "${not_ready_reason}" "默认 plugin 缺失 ${plugin_missing_count} 项${plugin_missing_names:+（${plugin_missing_names}）}")"
  [[ "${claude_md_exists}" != "yes" ]] && not_ready_reason="$(append_reason_text "${not_ready_reason}" "全局 CLAUDE.md 未初始化")"
  if [[ "${CLAUDE_SKIP_ONBOARDING}" == "1" && "${onboarding_state}" != "已启用" ]]; then
    not_ready_reason="$(append_reason_text "${not_ready_reason}" "缺少 ~/.claude.json 跳过登录状态")"
  fi
  ! managed_global_governance_ready "${GLOBAL_AGENTS_DIR}" && not_ready_reason="$(append_reason_text "${not_ready_reason}" "全局治理模板未补齐")"
  ! managed_global_role_ready "${GLOBAL_AGENTS_DIR}" && not_ready_reason="$(append_reason_text "${not_ready_reason}" "全局角色模板未补齐")"

  print_report_line "settings.json" "${GLOBAL_SETTINGS_PATH} (${settings_exists})"
  print_report_line "settings.local" "${GLOBAL_SETTINGS_LOCAL_PATH} (${settings_local_exists})"
  print_report_line "引导跳过文件" "${GLOBAL_SESSION_PATH} (${onboarding_state})"
  print_report_line "全局 CLAUDE.md" "${GLOBAL_CLAUDE_MD_PATH} (${claude_md_exists})"
  print_report_line "全局治理模板" "${GLOBAL_AGENTS_DIR} (${global_governance_state})"
  print_report_line "全局角色模板" "${GLOBAL_AGENTS_DIR} (${global_role_state})"
  print_report_line "运行状态" "${runtime_state}"
  print_report_line "建议动作" "$(recommended_service_action "claude-code" "${runtime_state}" "${CONFIG_FILE:-}")"
  [[ -n "${not_ready_reason}" ]] && print_report_line "未就绪原因" "${not_ready_reason}"
  print_report_line "最佳实践就绪度" "${readiness_summary}"
  print_report_line "当前模型" "${current_model}"
  print_report_line "认证模式" "${auth_mode}"
  print_report_line "Base URL" "$(claude_base_url_display_value "${base_url}")"
  print_report_line "插件目录" "${GLOBAL_PLUGINS_DIR} (${plugins_exists})"
  print_report_line "插件状态" "${plugin_summary}"
  [[ -n "${plugin_missing_names}" ]] && print_report_line "缺失 plugin" "${plugin_missing_names}"
  [[ -n "${plugin_manual_names}" ]] && print_report_line "人工处理 plugin" "${plugin_manual_names}"
  print_report_line "技能目录" "${GLOBAL_SKILLS_DIR} (${skills_exists})"
  print_report_line "Agents 目录" "${GLOBAL_AGENTS_DIR} (${agents_exists})"
  print_report_line "工具目录" "${TOOL_RUNTIME_ROOT}"
  print_report_line "备份目录" "${BACKUP_ROOT}"
  print_report_line "能力包策略" "$(pack_strategy_summary "${COMMON_DEFAULT_PACKS}" "${TOOL_DEFAULT_PACKS}" "${ENHANCED_PACKS}" "${ENABLE_ENHANCED_PACKS}" "${EXPERIMENTAL_PACKS}" "${ENABLE_EXPERIMENTAL_PACKS}")"
  print_report_line "核心能力统计" "${capability_stats}"
  print_report_line "能力项统计" "${capability_counts}"
  print_report_line "能力包清单" "${TOOL_PACKS_MANIFEST_PATH} ($(path_state "${TOOL_PACKS_MANIFEST_PATH}"))"
  print_report_line "技能清单" "${TOOL_SKILLS_MANIFEST_PATH} ($(path_state "${TOOL_SKILLS_MANIFEST_PATH}"))"
  print_report_line "插件清单" "${TOOL_PLUGINS_MANIFEST_PATH} ($(path_state "${TOOL_PLUGINS_MANIFEST_PATH}"))"
  print_report_line "插件快照" "${TOOL_PLUGIN_STATUS_PATH} ($(path_state "${TOOL_PLUGIN_STATUS_PATH}"))"
  print_report_line "Hook 清单" "${TOOL_HOOKS_MANIFEST_PATH} ($(path_state "${TOOL_HOOKS_MANIFEST_PATH}"))"
  print_report_line "MCP 清单" "${TOOL_MCP_MANIFEST_PATH} ($(path_state "${TOOL_MCP_MANIFEST_PATH}"))"
  print_report_line "Agent 清单" "${TOOL_AGENTS_MANIFEST_PATH} ($(path_state "${TOOL_AGENTS_MANIFEST_PATH}"))"

  if [[ -n "${CONFIG_FILE}" ]]; then
    print_report_line "目标配置文件" "${CONFIG_FILE}"
    print_report_line "目标模型" "${DEFAULT_MODEL}"
    print_report_line "目标认证" "${AUTH_MODE}"
    print_report_line "目标 Base URL" "$(claude_base_url_display_value "${ANTHROPIC_BASE_URL:-}" "未声明" "已声明（已脱敏）")"
    print_report_line "模型比对" "$(setting_compare_state "${current_model}" "${DEFAULT_MODEL}")"
    print_report_line "认证比对" "$(setting_compare_state "${auth_mode}" "${AUTH_MODE}")"
    print_report_line "Base URL 比对" "$(setting_compare_state "${base_url}" "${ANTHROPIC_BASE_URL:-}")"
  fi
}

cmd_service_report() {
  local claude_path=""
  local install_state="未安装"
  local not_ready_reason=""
  local settings_state="missing"
  local onboarding_state="缺失"
  local current_model="未检测到"
  local auth_mode="未检测到"
  local base_url="未检测到"
  local plugin_missing_count="0"
  local plugin_missing_names=""
  local plugin_manual_names=""
  local plugin_summary="未检测到"
  local readiness_summary="未检测到"
  local capability_stats="未检测到"
  local capability_counts="skill 0 / plugin 0 / hook 0 / mcp 0 / agent 0"
  local global_governance_state="0/4"
  local global_role_state="0/4"

  load_config_if_present
  readonly_manifest_scope_begin TOOL_PLUGIN_STATUS_PATH TOOL_AVAILABLE_PLUGINS_JSON_PATH TOOL_INSTALLED_PLUGINS_JSON_PATH
  render_runtime_manifests
  claude_path="$(claude_binary_path)"

  if [[ -n "${claude_path}" ]]; then
    install_state="已安装"
  fi

  if [[ -f "${GLOBAL_SETTINGS_PATH}" ]]; then
    settings_state="present"
    current_model="$(extract_json_string_value "model" "${GLOBAL_SETTINGS_PATH}")"
    [[ -n "${current_model}" ]] || current_model="未检测到"
    if grep -q '"ANTHROPIC_AUTH_TOKEN"' "${GLOBAL_SETTINGS_PATH}"; then
      auth_mode="auth-token"
    elif grep -q '"ANTHROPIC_API_KEY"' "${GLOBAL_SETTINGS_PATH}"; then
      auth_mode="api-key"
    fi
    base_url="$(extract_json_string_value "ANTHROPIC_BASE_URL" "${GLOBAL_SETTINGS_PATH}")"
    [[ -n "${base_url}" ]] || base_url="未配置"
  fi
  onboarding_state="$(claude_onboarding_state_value "${GLOBAL_SESSION_PATH}")"
  global_governance_state="$(managed_global_governance_state "${GLOBAL_AGENTS_DIR}")"
  global_role_state="$(managed_global_role_state "${GLOBAL_AGENTS_DIR}")"

  write_plugin_status_snapshot
  install_state="$(claude_runtime_state "${claude_path}" "$( [[ "${settings_state}" == "present" ]] && printf 'yes' || printf 'no' )" "${auth_mode}")"
  plugin_missing_count="$(plugin_status_count "缺失")"
  plugin_missing_names="$(plugin_status_names_csv "缺失")"
  plugin_manual_names="$(plugin_status_names_csv "需人工处理")"
  plugin_summary="$(plugin_status_summary)"
  readiness_summary="$(claude_best_practice_readiness "${claude_path}" "$( [[ "${settings_state}" == "present" ]] && printf 'yes' || printf 'no' )" "${auth_mode}")"
  capability_stats="$(capability_stats_summary "${TOOL_SKILLS_MANIFEST_PATH}" "${TOOL_PLUGINS_MANIFEST_PATH}" "${TOOL_HOOKS_MANIFEST_PATH}" "${TOOL_MCP_MANIFEST_PATH}" "${TOOL_AGENTS_MANIFEST_PATH}" "plugin")"
  capability_counts="skill $(manifest_item_count "${TOOL_SKILLS_MANIFEST_PATH}") / plugin $(manifest_item_count "${TOOL_PLUGINS_MANIFEST_PATH}") / hook $(manifest_item_count "${TOOL_HOOKS_MANIFEST_PATH}") / mcp $(manifest_item_count "${TOOL_MCP_MANIFEST_PATH}") / agent $(manifest_item_count "${TOOL_AGENTS_MANIFEST_PATH}")"
  if [[ "${readiness_summary}" == "推荐基线已就绪" || "${readiness_summary}" == "增强基线已启用" ]]; then
    if ! managed_global_governance_ready "${GLOBAL_AGENTS_DIR}" || ! managed_global_role_ready "${GLOBAL_AGENTS_DIR}"; then
      readiness_summary="推荐基线待补齐"
    fi
  fi
  readonly_manifest_scope_end

  case "${install_state}" in
    未安装)
      not_ready_reason="$(append_reason_text "${not_ready_reason}" "未检测到 claude 命令")"
      ;;
    未配置)
      not_ready_reason="$(append_reason_text "${not_ready_reason}" "缺少 settings.json")"
      ;;
    需人工登录或授权)
      not_ready_reason="$(append_reason_text "${not_ready_reason}" "当前认证信息未检测到")"
      ;;
  esac

  if [[ -n "${CONFIG_FILE}" ]]; then
    [[ "$(setting_compare_state "${current_model}" "${DEFAULT_MODEL}")" == "不一致" ]] && not_ready_reason="$(append_reason_text "${not_ready_reason}" "模型与目标不一致")"
    [[ "$(setting_compare_state "${current_model}" "${DEFAULT_MODEL}")" == "缺失" ]] && not_ready_reason="$(append_reason_text "${not_ready_reason}" "当前模型未配置")"
    [[ "$(setting_compare_state "${auth_mode}" "${AUTH_MODE}")" == "不一致" ]] && not_ready_reason="$(append_reason_text "${not_ready_reason}" "认证模式与目标不一致")"
  fi

  [[ "${plugin_missing_count}" != "0" ]] && not_ready_reason="$(append_reason_text "${not_ready_reason}" "默认 plugin 缺失 ${plugin_missing_count} 项${plugin_missing_names:+（${plugin_missing_names}）}")"
  if [[ "${CLAUDE_SKIP_ONBOARDING}" == "1" && "${onboarding_state}" != "已启用" ]]; then
    not_ready_reason="$(append_reason_text "${not_ready_reason}" "缺少 ~/.claude.json 跳过登录状态")"
  fi
  ! managed_global_governance_ready "${GLOBAL_AGENTS_DIR}" && not_ready_reason="$(append_reason_text "${not_ready_reason}" "全局治理模板未补齐")"
  ! managed_global_role_ready "${GLOBAL_AGENTS_DIR}" && not_ready_reason="$(append_reason_text "${not_ready_reason}" "全局角色模板未补齐")"

  print_section "Claude Code 概览"
  print_report_line "安装状态" "${install_state}"
  print_report_line "建议动作" "$(recommended_service_action "claude-code" "${install_state}" "${CONFIG_FILE:-}")"
  [[ -n "${not_ready_reason}" ]] && print_report_line "未就绪原因" "${not_ready_reason}"
  print_report_line "Claude 命令" "${claude_path:-未安装}"
  print_report_line "当前模型" "${current_model}"
  print_report_line "认证模式" "${auth_mode}"
  print_report_line "Base URL" "$(claude_base_url_display_value "${base_url}")"
  print_report_line "settings.json" "${GLOBAL_SETTINGS_PATH} (${settings_state})"
  print_report_line "引导跳过文件" "${GLOBAL_SESSION_PATH} (${onboarding_state})"
  print_report_line "全局治理模板" "${GLOBAL_AGENTS_DIR} (${global_governance_state})"
  print_report_line "全局角色模板" "${GLOBAL_AGENTS_DIR} (${global_role_state})"
  print_report_line "工具目录" "${TOOL_RUNTIME_ROOT}"
  print_report_line "最佳实践就绪度" "${readiness_summary}"
  print_report_line "能力包策略" "$(pack_strategy_summary "${COMMON_DEFAULT_PACKS}" "${TOOL_DEFAULT_PACKS}" "${ENHANCED_PACKS}" "${ENABLE_ENHANCED_PACKS}" "${EXPERIMENTAL_PACKS}" "${ENABLE_EXPERIMENTAL_PACKS}")"
  print_report_line "插件状态" "${plugin_summary}"
  [[ -n "${plugin_missing_names}" ]] && print_report_line "缺失 plugin" "${plugin_missing_names}"
  [[ -n "${plugin_manual_names}" ]] && print_report_line "人工处理 plugin" "${plugin_manual_names}"
  print_report_line "核心能力统计" "${capability_stats}"
  print_report_line "能力项统计" "${capability_counts}"
  print_report_line "能力包清单" "${TOOL_PACKS_MANIFEST_PATH} ($(path_state "${TOOL_PACKS_MANIFEST_PATH}"))"
  print_report_line "插件快照" "${TOOL_PLUGIN_STATUS_PATH} ($(path_state "${TOOL_PLUGIN_STATUS_PATH}"))"
  print_report_line "Agent 清单" "${TOOL_AGENTS_MANIFEST_PATH} ($(path_state "${TOOL_AGENTS_MANIFEST_PATH}"))"

  if [[ -n "${CONFIG_FILE}" ]]; then
    print_report_line "目标模型" "${DEFAULT_MODEL}"
    print_report_line "目标认证" "${AUTH_MODE}"
    print_report_line "模型比对" "$(setting_compare_state "${current_model}" "${DEFAULT_MODEL}")"
    print_report_line "认证比对" "$(setting_compare_state "${auth_mode}" "${AUTH_MODE}")"
  fi
}

cmd_config_backup() {
  local backup_dir=""
  local stamp=""

  require_config
  ensure_runtime_workspace

  stamp="$(date '+%Y%m%d-%H%M%S')"
  backup_dir="${TARGET_PATH:-${BACKUP_ROOT}/${stamp}}"
  mkdir -p "${backup_dir}"

  cp -a "${CONFIG_FILE}" "${backup_dir}/config.conf"
  [[ -f "${GLOBAL_SETTINGS_PATH}" ]] && cp -a "${GLOBAL_SETTINGS_PATH}" "${backup_dir}/settings.json"
  [[ -f "${GLOBAL_SETTINGS_LOCAL_PATH}" ]] && cp -a "${GLOBAL_SETTINGS_LOCAL_PATH}" "${backup_dir}/settings.local.json"
  [[ -f "${GLOBAL_CLAUDE_MD_PATH}" ]] && cp -a "${GLOBAL_CLAUDE_MD_PATH}" "${backup_dir}/CLAUDE.md"
  [[ -f "${GLOBAL_SESSION_PATH}" ]] && cp -a "${GLOBAL_SESSION_PATH}" "${backup_dir}/claude-session.json"
  [[ -d "${TOOL_MANIFESTS_DIR}" ]] && cp -a "${TOOL_MANIFESTS_DIR}" "${backup_dir}/manifests"

  log_info "已创建 Claude Code 配置备份：${backup_dir}"
}

cmd_config_restore() {
  local backup_dir="${TARGET_PATH:-}"

  require_config
  require_root
  ensure_runtime_layout
  [[ -n "${backup_dir}" ]] || die "config restore 必须通过 --path 指定备份目录"
  [[ -d "${backup_dir}" ]] || die "备份目录不存在：${backup_dir}"

  if ! confirm_action "将从 ${backup_dir} 恢复 Claude Code 配置，是否继续？" "${ASSUME_YES}"; then
    log_warn "已取消执行。"
    exit 0
  fi

  [[ -f "${backup_dir}/config.conf" ]] && cp -a "${backup_dir}/config.conf" "${CONFIG_FILE}"
  [[ -f "${backup_dir}/settings.json" ]] && cp -a "${backup_dir}/settings.json" "${GLOBAL_SETTINGS_PATH}"
  [[ -f "${backup_dir}/settings.local.json" ]] && cp -a "${backup_dir}/settings.local.json" "${GLOBAL_SETTINGS_LOCAL_PATH}"
  [[ -f "${backup_dir}/CLAUDE.md" ]] && cp -a "${backup_dir}/CLAUDE.md" "${GLOBAL_CLAUDE_MD_PATH}"
  [[ -f "${backup_dir}/claude-session.json" ]] && cp -a "${backup_dir}/claude-session.json" "${GLOBAL_SESSION_PATH}"
  if [[ -d "${backup_dir}/manifests" ]]; then
    rm -rf "${TOOL_MANIFESTS_DIR}"
    cp -a "${backup_dir}/manifests" "${TOOL_MANIFESTS_DIR}"
  fi

  log_info "已恢复 Claude Code 配置：${backup_dir}"
}

cmd_config_show() {
  local section="${TARGET_SECTION:-summary}"

  require_config

  print_section "Claude Code 配置"

  case "${section}" in
    summary)
      print_report_line "目标配置文件" "${CONFIG_FILE}"
      print_report_line "安装方式" "${INSTALL_METHOD}"
      print_report_line "模型" "${DEFAULT_MODEL}"
      print_report_line "认证方式" "${AUTH_MODE}"
      print_report_line "Base URL" "$(claude_base_url_display_value "${ANTHROPIC_BASE_URL:-}" "未声明" "已声明（已脱敏）")"
      print_report_line "API 超时" "${API_TIMEOUT_MS}"
      print_report_line "非必要流量" "${CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC}"
      print_report_line "允许权限数" "$(csv_item_count "${PERMISSIONS_ALLOW}")"
      print_report_line "拒绝权限数" "$(csv_item_count "${PERMISSIONS_DENY}")"
      ;;
    paths)
      print_report_line "全局目录" "${GLOBAL_CLAUDE_DIR}"
      print_report_line "settings.json" "${GLOBAL_SETTINGS_PATH}"
      print_report_line "settings.local" "${GLOBAL_SETTINGS_LOCAL_PATH}"
      print_report_line "全局 CLAUDE.md" "${GLOBAL_CLAUDE_MD_PATH}"
      print_report_line "插件目录" "${GLOBAL_PLUGINS_DIR}"
      print_report_line "技能目录" "${GLOBAL_SKILLS_DIR}"
      print_report_line "Agents 目录" "${GLOBAL_AGENTS_DIR}"
      print_report_line "会话文件" "${GLOBAL_SESSION_PATH}"
      print_report_line "工具目录" "${TOOL_RUNTIME_ROOT}"
      print_report_line "备份目录" "${BACKUP_ROOT}"
      ;;
    extensions)
      print_report_line "默认技能" "${ENABLE_DEFAULT_SKILLS}"
      print_report_line "默认插件" "${ENABLE_DEFAULT_PLUGINS}"
      print_report_line "默认 Hook" "${ENABLE_DEFAULT_HOOKS}"
      print_report_line "默认 MCP" "${ENABLE_DEFAULT_MCP}"
      print_report_line "默认 Agents" "${ENABLE_DEFAULT_AGENTS}"
      print_report_line "通用默认包" "${COMMON_DEFAULT_PACKS:-<空>}"
      print_report_line "工具默认包" "${TOOL_DEFAULT_PACKS:-<空>}"
      print_report_line "模式" "${MODE}"
      print_report_line "进阶包" "${ENHANCED_PACKS:-<空>}"
      print_report_line "探索包" "${EXPERIMENTAL_PACKS:-<空>}"
      print_report_line "SKILL_SPECS" "${SKILL_SPECS:-<空>}"
      print_report_line "SKILL_EXCLUDES" "${SKILL_EXCLUDES:-<空>}"
      print_report_line "PLUGIN_SPECS" "${PLUGIN_SPECS:-<空>}"
      print_report_line "PLUGIN_EXCLUDES" "${PLUGIN_EXCLUDES:-<空>}"
      print_report_line "HOOK_SPECS" "${HOOK_SPECS:-<空>}"
      print_report_line "HOOK_EXCLUDES" "${HOOK_EXCLUDES:-<空>}"
      print_report_line "MCP_SPECS" "${MCP_SPECS:-<空>}"
      print_report_line "MCP_EXCLUDES" "${MCP_EXCLUDES:-<空>}"
      print_report_line "AGENT_SPECS" "${AGENT_SPECS:-<空>}"
      print_report_line "AGENT_EXCLUDES" "${AGENT_EXCLUDES:-<空>}"
      ;;
    *)
      die "config show 仅支持 --section summary|paths|extensions，收到：${section}"
      ;;
  esac
}

cmd_config_init() {
  require_config

  case "${TARGET_SCOPE}" in
    global)
      ensure_runtime_layout
      render_settings_json
      render_settings_local_template
      render_onboarding_state_json
      render_claude_md_if_missing
      render_runtime_manifests
      render_support_notes_if_missing
      render_shared_global_governance_templates_if_missing "${GLOBAL_AGENTS_DIR}"
      render_shared_global_role_templates_if_missing "${GLOBAL_AGENTS_DIR}"
      if [[ ! -f "${GLOBAL_SETTINGS_LOCAL_PATH}" ]]; then
        install -m 600 "${TOOL_SETTINGS_LOCAL_PATH}" "${GLOBAL_SETTINGS_LOCAL_PATH}"
      fi
      if [[ ! -f "${GLOBAL_CLAUDE_MD_PATH}" ]]; then
        install -m 644 "${TOOL_CLAUDE_MD_PATH}" "${GLOBAL_CLAUDE_MD_PATH}"
      fi
      log_info "已初始化 Claude Code 工具目录：${TOOL_RUNTIME_ROOT}"
      log_info "已生成工具目录 settings.json：${TOOL_SETTINGS_PATH}"
      log_info "已生成工具目录 settings.local.json：${TOOL_SETTINGS_LOCAL_PATH}"
      log_info "已生成工具目录引导跳过模板：${TOOL_ONBOARDING_PATH}"
      log_info "已准备工具目录 CLAUDE.md 模板：${TOOL_CLAUDE_MD_PATH}"
      log_info "已准备官方目录治理模板：${GLOBAL_AGENTS_DIR}"
      log_info "已准备官方目录角色模板：${GLOBAL_AGENTS_DIR}"
      log_info "已准备官方目录 settings.local.json：${GLOBAL_SETTINGS_LOCAL_PATH}"
      log_info "已准备官方目录 CLAUDE.md：${GLOBAL_CLAUDE_MD_PATH}"
      write_plugin_status_snapshot
      log_info "已生成初始化清单：${TOOL_PACKS_MANIFEST_PATH}、${TOOL_SKILLS_MANIFEST_PATH}、${TOOL_PLUGINS_MANIFEST_PATH}、${TOOL_HOOKS_MANIFEST_PATH}、${TOOL_MCP_MANIFEST_PATH}、${TOOL_AGENTS_MANIFEST_PATH}"
      ;;
    project)
      ensure_runtime_workspace
      render_runtime_manifests
      [[ -n "${TARGET_PATH}" ]] || die "config init --scope project 必须提供 --path"
      if [[ ! -d "${TARGET_PATH}" ]]; then
        if ! confirm_action "目标目录不存在，将创建：${TARGET_PATH}，是否继续？" "${ASSUME_YES}"; then
          log_warn "已取消执行。"
          exit 0
        fi
      fi
      mkdir -p "${TARGET_PATH}"
      render_project_template_if_missing "${TARGET_PATH}"
      log_info "已初始化项目目录：${TARGET_PATH}"
      log_info "已生成：${TARGET_PATH}/CLAUDE.md"
      log_info "已生成：${TARGET_PATH}/.agents/project-context.md"
      log_info "已生成：${TARGET_PATH}/.agents/architecture.md"
      log_info "已生成：${TARGET_PATH}/.agents/workflow.md"
      log_info "已生成：${TARGET_PATH}/.agents/checklist.md"
      log_info "已生成：${TARGET_PATH}/.claude/settings.json"
      log_info "已生成：${TARGET_PATH}/.claude/settings.local.json"
      log_info "已生成：${TARGET_PATH}/.claude/skills/"
      log_info "已生成：${TARGET_PATH}/.claude/agents/"
      ;;
    *)
      die "仅支持 --scope global 或 --scope project，收到：${TARGET_SCOPE:-<空>}"
      ;;
  esac
}

cmd_service_configure() {
  require_config
  if ! confirm_action "将按配置重写全局 Claude Code settings.json，是否继续？" "${ASSUME_YES}"; then
    log_warn "已取消执行。"
    exit 0
  fi
  sync_global_config
}

cmd_extension_commands_not_exposed() {
  die "Claude Code 当前不单独提供 ${COMMAND_GROUP} ${COMMAND_ACTION} 命令，请使用 service install 或 config init 自动准备相关目录与运行清单。"
}

dispatch() {
  case "${COMMAND_GROUP}:${COMMAND_ACTION}" in
    service:install)
      cmd_service_install_like "安装"
      ;;
    service:configure)
      cmd_service_configure
      ;;
    service:update)
      cmd_service_install_like "更新"
      ;;
    service:uninstall)
      cmd_service_uninstall
      ;;
    service:report)
      cmd_service_report
      ;;
    service:check)
      cmd_service_check
      ;;
    config:backup)
      cmd_config_backup
      ;;
    config:restore)
      cmd_config_restore
      ;;
    config:show)
      cmd_config_show
      ;;
    config:init)
      cmd_config_init
      ;;
    skill:*|plugin:*|hook:*|mcp:*)
      cmd_extension_commands_not_exposed
      ;;
    *)
      usage
      exit 1
      ;;
  esac
}

main() {
  if [[ "${COMMAND_GROUP}" == "help" || -z "${COMMAND_ACTION}" ]]; then
    usage
    exit 0
  fi

  parse_args "$@"
  dispatch
}

main "$@"
