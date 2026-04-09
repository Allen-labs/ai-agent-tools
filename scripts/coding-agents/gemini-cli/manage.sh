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
  help_print_title "Gemini CLI"
  help_print_strong_rule
  help_print_context "最短入口" "manage.sh guide start --tool-name gemini-cli"
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
  help_print_step "1" "manage.sh guide start --tool-name gemini-cli"
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

bool_to_json() {
  case "${1:-0}" in
    1|true|TRUE|yes|YES|on|ON)
      printf 'true'
      ;;
    *)
      printf 'false'
      ;;
  esac
}

path_like_spec() {
  case "${1:-}" in
    /*|./*|../*)
      return 0
      ;;
  esac
  return 1
}

github_repo_like_spec() {
  case "${1:-}" in
    */*)
      [[ "${1}" =~ ^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+(\.git)?$ ]]
      return
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

resolve_local_spec_path() {
  local spec="${1:-}"
  local base_dir=""

  if [[ "${spec}" == /* ]]; then
    printf '%s' "${spec}"
    return 0
  fi

  if [[ -n "${CONFIG_FILE}" ]]; then
    base_dir="$(cd "$(dirname "${CONFIG_FILE}")" && pwd)"
  else
    base_dir="$(pwd)"
  fi

  if command -v realpath >/dev/null 2>&1; then
    realpath -m "${base_dir}/${spec}"
  else
    printf '%s/%s' "${base_dir}" "${spec}"
  fi
}

gemini_extension_repo_from_spec() {
  local spec="${1:-}"
  local repo=""

  case "${spec}" in
    github:*)
      repo="${spec#github:}"
      repo="${repo%/}"
      repo="${repo%.git}"
      github_repo_like_spec "${repo}" || return 1
      printf '%s' "${repo}"
      return 0
      ;;
  esac

  if url_like_spec "${spec}" && [[ "${spec}" =~ ^https?://github\.com/ ]]; then
    repo="${spec#https://github.com/}"
    repo="${repo#http://github.com/}"
    repo="${repo%%\?*}"
    repo="${repo%/}"
    repo="${repo%.git}"
    github_repo_like_spec "${repo}" || return 1
    printf '%s' "${repo}"
    return 0
  fi

  if github_repo_like_spec "${spec}"; then
    repo="${spec%/}"
    repo="${repo%.git}"
    printf '%s' "${repo}"
    return 0
  fi

  case "${spec}" in
    conductor|code-review|security|jules|workspace|stitch|flutter|cloud-sql-postgresql|bigquery-data-analytics)
      printf 'gemini-cli-extensions/%s' "${spec}"
      return 0
      ;;
  esac

  return 1
}

gemini_extension_install_source_from_spec() {
  local spec="${1:-}"
  local repo=""

  if path_like_spec "${spec}"; then
    printf '%s' "$(resolve_local_spec_path "${spec}")"
    return 0
  fi

  repo="$(gemini_extension_repo_from_spec "${spec}" || true)"
  if [[ -n "${repo}" ]]; then
    printf '%s' "${repo}"
    return 0
  fi

  if url_like_spec "${spec}"; then
    printf '%s' "${spec}"
    return 0
  fi

  return 1
}

gemini_extension_name_from_spec() {
  local spec="${1:-}"
  local repo=""
  local resolved=""
  local name=""

  repo="$(gemini_extension_repo_from_spec "${spec}" || true)"
  if [[ -n "${repo}" ]]; then
    printf '%s' "${repo##*/}"
    return 0
  fi

  if url_like_spec "${spec}"; then
    name="${spec%%\?*}"
    name="${name%/}"
    name="${name##*/}"
    name="${name%.git}"
    printf '%s' "${name}"
    return 0
  fi

  if path_like_spec "${spec}"; then
    resolved="$(resolve_local_spec_path "${spec}")"
    printf '%s' "$(basename "${resolved}")"
    return 0
  fi

  printf '%s' "${spec}"
}

gemini_extension_source_from_spec() {
  local spec="${1:-}"
  local repo=""

  if path_like_spec "${spec}"; then
    printf '%s' "$(resolve_local_spec_path "${spec}")"
    return 0
  fi

  repo="$(gemini_extension_repo_from_spec "${spec}" || true)"
  if [[ -n "${repo}" ]]; then
    printf 'https://github.com/%s' "${repo}"
    return 0
  fi

  if url_like_spec "${spec}"; then
    printf '%s' "${spec}"
    return 0
  fi

  return 1
}

normalize_config() {
  INSTALL_METHOD="${INSTALL_METHOD:-npm}"
  GEMINI_PACKAGE="${GEMINI_PACKAGE:-@google/gemini-cli@latest}"
  AUTH_MODE="${AUTH_MODE:-api-key}"
  DEFAULT_MODEL="${DEFAULT_MODEL:-gemini-2.5-pro}"
  GEMINI_API_KEY="${GEMINI_API_KEY:-}"
  GOOGLE_API_KEY="${GOOGLE_API_KEY:-}"
  GOOGLE_CLOUD_PROJECT="${GOOGLE_CLOUD_PROJECT:-}"
  GOOGLE_CLOUD_LOCATION="${GOOGLE_CLOUD_LOCATION:-us-central1}"
  GOOGLE_GENAI_USE_VERTEXAI="${GOOGLE_GENAI_USE_VERTEXAI:-false}"
  POLICY_MODE="${POLICY_MODE:-balanced}"
  TOOL_SANDBOXING="${TOOL_SANDBOXING:-0}"
  FOLDER_TRUST_ENABLED="${FOLDER_TRUST_ENABLED:-1}"
  ENABLE_DEFAULT_SKILLS="${ENABLE_DEFAULT_SKILLS:-1}"
  ENABLE_DEFAULT_PLUGINS="${ENABLE_DEFAULT_PLUGINS:-1}"
  ENABLE_DEFAULT_HOOKS="${ENABLE_DEFAULT_HOOKS:-1}"
  ENABLE_DEFAULT_MCP="${ENABLE_DEFAULT_MCP:-1}"
  ENABLE_DEFAULT_AGENTS="${ENABLE_DEFAULT_AGENTS:-1}"
  MODE="${MODE:-}"
  COMMON_DEFAULT_PACKS="${COMMON_DEFAULT_PACKS:-common-core,common-docs-architecture,common-quality,common-backend,common-frontend}"
  TOOL_DEFAULT_PACKS="${TOOL_DEFAULT_PACKS:-gemini-core,gemini-collaboration}"
  ENHANCED_PACKS="${ENHANCED_PACKS:-gemini-ui,gemini-data,enhanced-browser-deep,enhanced-background-agents,enhanced-observability}"
  ENABLE_ENHANCED_PACKS="${ENABLE_ENHANCED_PACKS:-0}"
  EXPERIMENTAL_PACKS="${EXPERIMENTAL_PACKS:-experimental-bleeding-edge}"
  ENABLE_EXPERIMENTAL_PACKS="${ENABLE_EXPERIMENTAL_PACKS:-0}"
  SKILL_SPECS="${SKILL_SPECS:-}"
  PLUGIN_SPECS="${PLUGIN_SPECS:-}"
  HOOK_SPECS="${HOOK_SPECS:-}"
  MCP_SPECS="${MCP_SPECS:-}"
  AGENT_SPECS="${AGENT_SPECS:-}"
  normalize_mode_profile
  GLOBAL_GEMINI_DIR="${GLOBAL_GEMINI_DIR:-/root/.gemini}"
  GLOBAL_SETTINGS_PATH="${GLOBAL_SETTINGS_PATH:-${GLOBAL_GEMINI_DIR}/settings.json}"
  GLOBAL_ENV_PATH="${GLOBAL_ENV_PATH:-${GLOBAL_GEMINI_DIR}/.env}"
  GLOBAL_MEMORY_PATH="${GLOBAL_MEMORY_PATH:-${GLOBAL_GEMINI_DIR}/GEMINI.md}"
  GLOBAL_SKILLS_DIR="${GLOBAL_SKILLS_DIR:-${GLOBAL_GEMINI_DIR}/skills}"
  GLOBAL_EXTENSIONS_DIR="${GLOBAL_EXTENSIONS_DIR:-${GLOBAL_GEMINI_DIR}/extensions}"
  GLOBAL_POLICIES_DIR="${GLOBAL_POLICIES_DIR:-${GLOBAL_GEMINI_DIR}/policies}"
  GLOBAL_AGENTS_DIR="${GLOBAL_AGENTS_DIR:-${GLOBAL_GEMINI_DIR}/agents}"
  GLOBAL_SKILLS_NOTE_PATH="${GLOBAL_SKILLS_DIR}/README.managed.md"
  GLOBAL_EXTENSIONS_NOTE_PATH="${GLOBAL_EXTENSIONS_DIR}/README.managed.md"
  GLOBAL_POLICIES_NOTE_PATH="${GLOBAL_POLICIES_DIR}/README.managed.md"
  GLOBAL_AGENTS_NOTE_PATH="${GLOBAL_AGENTS_DIR}/README.managed.md"

  TOOL_RUNTIME_ROOT="${TOOL_RUNTIME_ROOT:-${SCRIPT_DIR}}"
  BACKUP_ROOT="${BACKUP_ROOT:-${TOOL_RUNTIME_ROOT}/backups}"
  TOOL_CONFIG_DIR="${TOOL_RUNTIME_ROOT}/config"
  TOOL_GLOBAL_DIR="${TOOL_CONFIG_DIR}/global"
  TOOL_SETTINGS_PATH="${TOOL_GLOBAL_DIR}/settings.json"
  TOOL_ENV_PATH="${TOOL_GLOBAL_DIR}/.env"
  TOOL_MEMORY_PATH="${TOOL_GLOBAL_DIR}/GEMINI.md"
  TOOL_MANIFESTS_DIR="${TOOL_RUNTIME_ROOT}/manifests"
  TOOL_PACKS_MANIFEST_PATH="${TOOL_MANIFESTS_DIR}/packs.manifest"
  TOOL_SKILLS_MANIFEST_PATH="${TOOL_MANIFESTS_DIR}/skills.manifest"
  TOOL_PLUGINS_MANIFEST_PATH="${TOOL_MANIFESTS_DIR}/plugins.manifest"
  TOOL_PLUGIN_STATUS_PATH="${TOOL_MANIFESTS_DIR}/extensions.status"
  TOOL_HOOKS_MANIFEST_PATH="${TOOL_MANIFESTS_DIR}/hooks.manifest"
  TOOL_MCP_MANIFEST_PATH="${TOOL_MANIFESTS_DIR}/mcp.manifest"
  TOOL_AGENTS_MANIFEST_PATH="${TOOL_MANIFESTS_DIR}/agents.manifest"

  case "${POLICY_MODE}" in
    safe)
      TOOL_SANDBOXING=1
      FOLDER_TRUST_ENABLED=0
      GEMINI_APPROVAL_MODE=default
      ;;
    auto)
      TOOL_SANDBOXING=0
      FOLDER_TRUST_ENABLED=1
      GEMINI_APPROVAL_MODE=auto_edit
      ;;
    *)
      TOOL_SANDBOXING="${TOOL_SANDBOXING:-0}"
      FOLDER_TRUST_ENABLED="${FOLDER_TRUST_ENABLED:-1}"
      GEMINI_APPROVAL_MODE=default
      ;;
  esac
}

refresh_extension_plan() {
  if [[ "${ENABLE_DEFAULT_PLUGINS}" == "1" ]]; then
    RESOLVED_EXTENSION_SPECS="$(resolve_installable_capability_items_csv "gemini-cli" "plugin" "extensions-install" "${COMMON_DEFAULT_PACKS}" "${TOOL_DEFAULT_PACKS}" "${ENHANCED_PACKS}" "${ENABLE_ENHANCED_PACKS}" "${EXPERIMENTAL_PACKS}" "${ENABLE_EXPERIMENTAL_PACKS}" "${PLUGIN_SPECS}")"
  else
    RESOLVED_EXTENSION_SPECS="${PLUGIN_SPECS}"
  fi
}

require_config() {
  [[ -n "${CONFIG_FILE}" ]] || die "必须提供 --config"
  [[ -f "${CONFIG_FILE}" ]] || die "配置文件不存在：${CONFIG_FILE}"
  load_key_value_config "${CONFIG_FILE}" || die "配置文件解析失败：${CONFIG_FILE}"
  normalize_config
  refresh_extension_plan
}

load_config_if_present() {
  if [[ -n "${CONFIG_FILE}" ]]; then
    require_config
  else
    normalize_config
    refresh_extension_plan
  fi
}

ensure_runtime_layout() {
  mkdir -p \
    "${TOOL_RUNTIME_ROOT}" \
    "${TOOL_GLOBAL_DIR}" \
    "${BACKUP_ROOT}" \
    "${TOOL_MANIFESTS_DIR}" \
    "${GLOBAL_GEMINI_DIR}" \
    "${GLOBAL_SKILLS_DIR}" \
    "${GLOBAL_EXTENSIONS_DIR}" \
    "${GLOBAL_POLICIES_DIR}" \
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

gemini_binary_path() {
  command -v gemini 2>/dev/null || true
}

gemini_version_value() {
  if command -v gemini >/dev/null 2>&1; then
    gemini --version 2>&1 | tail -n 1
  else
    printf '未安装'
  fi
}

render_settings_json() {
  cat > "${TOOL_SETTINGS_PATH}" <<EOF
{
  "model": {
    "name": "$(json_escape "${DEFAULT_MODEL}")",
    "compressionThreshold": 0.7
  },
  "general": {
    "defaultApprovalMode": "$(json_escape "${GEMINI_APPROVAL_MODE}")",
    "enableAutoUpdate": true
  },
  "tools": {
    "useRipgrep": true,
    "sandbox": $(bool_to_json "${TOOL_SANDBOXING}")
  },
  "security": {
    "toolSandboxing": $(bool_to_json "${TOOL_SANDBOXING}"),
    "folderTrust": {
      "enabled": $(bool_to_json "${FOLDER_TRUST_ENABLED}")
    }
  },
  "skills": {
    "enabled": true
  },
  "hooksConfig": {
    "enabled": true
  }
}
EOF
}

render_env_file() {
  : > "${TOOL_ENV_PATH}"
  [[ -n "${GEMINI_API_KEY}" ]] && printf 'GEMINI_API_KEY=%s\n' "${GEMINI_API_KEY}" >> "${TOOL_ENV_PATH}"
  [[ -n "${GOOGLE_API_KEY}" ]] && printf 'GOOGLE_API_KEY=%s\n' "${GOOGLE_API_KEY}" >> "${TOOL_ENV_PATH}"
  [[ -n "${GOOGLE_CLOUD_PROJECT}" ]] && printf 'GOOGLE_CLOUD_PROJECT=%s\n' "${GOOGLE_CLOUD_PROJECT}" >> "${TOOL_ENV_PATH}"
  [[ -n "${GOOGLE_CLOUD_LOCATION}" ]] && printf 'GOOGLE_CLOUD_LOCATION=%s\n' "${GOOGLE_CLOUD_LOCATION}" >> "${TOOL_ENV_PATH}"
  [[ -n "${GOOGLE_GENAI_USE_VERTEXAI}" ]] && printf 'GOOGLE_GENAI_USE_VERTEXAI=%s\n' "${GOOGLE_GENAI_USE_VERTEXAI}" >> "${TOOL_ENV_PATH}"
  return 0
}

render_memory_template_if_missing() {
  if [[ -f "${TOOL_MEMORY_PATH}" ]]; then
    return 0
  fi

  cat > "${TOOL_MEMORY_PATH}" <<'EOF'
# Gemini CLI 全局工作习惯

## 偏好
- 回复使用中文
- 先给结论，再补原因
- 不改无关代码

## 常用约束
- 变更前先理解已有实现
- 高风险命令前明确提示
- 优先使用项目已有工具链
EOF
}

write_extension_status_snapshot() {
  local spec=""
  local name=""
  local source=""
  local install_source=""
  local manifest_path=""
  local extension_dir=""
  local status=""
  local detail=""
  local -a extension_specs=()

  mkdir -p "$(dirname "${TOOL_PLUGIN_STATUS_PATH}")"

  {
    printf '# Gemini CLI extension 状态\n'
    printf 'name|status|source|detail\n'
  } > "${TOOL_PLUGIN_STATUS_PATH}"

  mapfile -t extension_specs < <(csv_clean_lines "${RESOLVED_EXTENSION_SPECS}")
  for spec in "${extension_specs[@]}"; do
    [[ -n "${spec}" ]] || continue
    name="$(gemini_extension_name_from_spec "${spec}")"
    source="$(gemini_extension_source_from_spec "${spec}" || true)"
    install_source="$(gemini_extension_install_source_from_spec "${spec}" || true)"
    extension_dir="${GLOBAL_EXTENSIONS_DIR}/${name}"
    manifest_path="${extension_dir}/gemini-extension.json"

    if [[ -f "${manifest_path}" ]]; then
      status="已安装"
      detail="${manifest_path}"
    elif [[ -d "${extension_dir}" ]]; then
      status="未生效"
      detail="目录存在，但缺少 gemini-extension.json"
    elif [[ -n "${source}" || -n "${install_source}" ]]; then
      status="缺失"
      detail="${source:-${install_source}}"
    else
      status="需人工处理"
      detail="未识别来源，请使用官方名称、github:org/repo、GitHub URL、org/repo 或本地路径"
    fi

    printf '%s|%s|%s|%s\n' "${name}" "${status}" "${source:-<空>}" "${detail}" >> "${TOOL_PLUGIN_STATUS_PATH}"
  done
}

extension_status_count() {
  local target_status="${1:-}"

  [[ -f "${TOOL_PLUGIN_STATUS_PATH}" ]] || {
    printf '0'
    return 0
  }

  awk -F'|' -v target="${target_status}" 'NR > 2 && $2 == target { count++ } END { print count + 0 }' "${TOOL_PLUGIN_STATUS_PATH}"
}

extension_status_summary() {
  printf '已安装 %s / 缺失 %s / 未生效 %s / 需人工处理 %s' \
    "$(extension_status_count "已安装")" \
    "$(extension_status_count "缺失")" \
    "$(extension_status_count "未生效")" \
    "$(extension_status_count "需人工处理")"
}

sync_extensions() {
  local mode="${1:-安装}"
  local spec=""
  local source=""
  local install_source=""
  local name=""
  local -a extension_specs=()

  ensure_runtime_layout

  if [[ -z "${RESOLVED_EXTENSION_SPECS}" ]]; then
    write_extension_status_snapshot
    return 0
  fi

  if ! command -v gemini >/dev/null 2>&1; then
    log_warn "Gemini CLI 未安装，跳过 extension 处理。"
    write_extension_status_snapshot
    return 0
  fi

  ensure_command git

  mapfile -t extension_specs < <(csv_clean_lines "${RESOLVED_EXTENSION_SPECS}")
  for spec in "${extension_specs[@]}"; do
    [[ -n "${spec}" ]] || continue
    name="$(gemini_extension_name_from_spec "${spec}")"
    source="$(gemini_extension_source_from_spec "${spec}" || true)"
    install_source="$(gemini_extension_install_source_from_spec "${spec}" || true)"

    if [[ -z "${install_source}" ]]; then
      log_warn "extension 缺少可安装来源，跳过：${spec}"
      continue
    fi

    if [[ "${mode}" == "更新" && -f "${GLOBAL_EXTENSIONS_DIR}/${name}/gemini-extension.json" ]]; then
      if gemini extensions update "${name}"; then
        log_info "已更新 extension：${name}"
      else
        log_warn "更新 extension 失败，保留现状：${name}"
      fi
      continue
    fi

    if [[ -f "${GLOBAL_EXTENSIONS_DIR}/${name}/gemini-extension.json" ]]; then
      log_info "extension 已存在，跳过：${name}"
      continue
    fi

    if gemini extensions install "${install_source}" --auto-update --consent; then
      log_info "已安装 extension：${name}"
    else
      log_warn "安装 extension 失败：${name}"
    fi
  done

  write_extension_status_snapshot
}

gemini_runtime_state() {
  local gemini_path="${1:-}"
  local settings_exists="${2:-no}"
  local env_exists="${3:-no}"
  local current_auth="${4:-未检测到}"
  local missing_count="0"
  local inactive_count="0"
  local manual_count="0"

  missing_count="$(extension_status_count "缺失")"
  inactive_count="$(extension_status_count "未生效")"
  manual_count="$(extension_status_count "需人工处理")"

  if [[ -z "${gemini_path}" ]]; then
    printf '未安装'
  elif [[ "${settings_exists}" != "yes" || "${env_exists}" != "yes" ]]; then
    printf '未配置'
  elif [[ "${current_auth}" == "未检测到" ]]; then
    printf '需人工登录或授权'
  elif [[ "${manual_count}" != "0" ]]; then
    printf '需人工处理'
  elif [[ "${missing_count}" != "0" || "${inactive_count}" != "0" ]]; then
    printf '未生效'
  else
    printf '已安装'
  fi
}

gemini_best_practice_readiness() {
  local gemini_path="${1:-}"
  local settings_exists="${2:-no}"
  local env_exists="${3:-no}"
  local current_auth="${4:-未检测到}"

  if [[ -z "${gemini_path}" ]]; then
    printf '未安装'
  elif [[ "${settings_exists}" != "yes" || "${env_exists}" != "yes" ]]; then
    printf '未配置'
  elif [[ "${current_auth}" == "未检测到" ]]; then
    printf '待授权'
  elif [[ ! -f "${TOOL_PACKS_MANIFEST_PATH}" || ! -f "${TOOL_PLUGINS_MANIFEST_PATH}" || ! -f "${TOOL_PLUGIN_STATUS_PATH}" ]]; then
    printf '工具清单缺失'
  elif [[ "$(extension_status_count "需人工处理")" != "0" ]]; then
    printf '需人工处理'
  elif [[ "$(extension_status_count "缺失")" != "0" || "$(extension_status_count "未生效")" != "0" ]]; then
    printf '推荐基线待补齐'
  elif [[ "${ENABLE_ENHANCED_PACKS}" == "1" || "${ENABLE_EXPERIMENTAL_PACKS}" == "1" ]]; then
    printf '增强基线已启用'
  else
    printf '推荐基线已就绪'
  fi
}

render_runtime_manifests() {
  write_pack_manifest "${TOOL_PACKS_MANIFEST_PATH}" "gemini-cli" "${COMMON_DEFAULT_PACKS}" "${TOOL_DEFAULT_PACKS}" "${ENHANCED_PACKS}" "${ENABLE_ENHANCED_PACKS}" "${EXPERIMENTAL_PACKS}" "${ENABLE_EXPERIMENTAL_PACKS}"
  write_capability_manifest "${TOOL_SKILLS_MANIFEST_PATH}" "Gemini CLI skill 初始化清单" "${ENABLE_DEFAULT_SKILLS}" "${SKILL_SPECS}" "默认仅初始化 ~/.gemini/skills 目录结构" "gemini-cli" "skill" "${COMMON_DEFAULT_PACKS}" "${TOOL_DEFAULT_PACKS}" "${ENHANCED_PACKS}" "${ENABLE_ENHANCED_PACKS}" "${EXPERIMENTAL_PACKS}" "${ENABLE_EXPERIMENTAL_PACKS}"
  write_capability_manifest "${TOOL_PLUGINS_MANIFEST_PATH}" "Gemini CLI extension 初始化清单" "${ENABLE_DEFAULT_PLUGINS}" "${PLUGIN_SPECS}" "默认仅初始化 ~/.gemini/extensions 目录结构" "gemini-cli" "plugin" "${COMMON_DEFAULT_PACKS}" "${TOOL_DEFAULT_PACKS}" "${ENHANCED_PACKS}" "${ENABLE_ENHANCED_PACKS}" "${EXPERIMENTAL_PACKS}" "${ENABLE_EXPERIMENTAL_PACKS}"
  write_capability_manifest "${TOOL_HOOKS_MANIFEST_PATH}" "Gemini CLI hook 初始化清单" "${ENABLE_DEFAULT_HOOKS}" "${HOOK_SPECS}" "默认依赖 settings.json 中的 hooksConfig 骨架" "gemini-cli" "hook" "${COMMON_DEFAULT_PACKS}" "${TOOL_DEFAULT_PACKS}" "${ENHANCED_PACKS}" "${ENABLE_ENHANCED_PACKS}" "${EXPERIMENTAL_PACKS}" "${ENABLE_EXPERIMENTAL_PACKS}"
  write_capability_manifest "${TOOL_MCP_MANIFEST_PATH}" "Gemini CLI MCP 初始化清单" "${ENABLE_DEFAULT_MCP}" "${MCP_SPECS}" "默认保留为空，按实际服务器再接入" "gemini-cli" "mcp" "${COMMON_DEFAULT_PACKS}" "${TOOL_DEFAULT_PACKS}" "${ENHANCED_PACKS}" "${ENABLE_ENHANCED_PACKS}" "${EXPERIMENTAL_PACKS}" "${ENABLE_EXPERIMENTAL_PACKS}"
  write_capability_manifest "${TOOL_AGENTS_MANIFEST_PATH}" "Gemini CLI agent 初始化清单" "${ENABLE_DEFAULT_AGENTS}" "${AGENT_SPECS}" "默认初始化 ~/.gemini/agents 目录结构" "gemini-cli" "agent" "${COMMON_DEFAULT_PACKS}" "${TOOL_DEFAULT_PACKS}" "${ENHANCED_PACKS}" "${ENABLE_ENHANCED_PACKS}" "${EXPERIMENTAL_PACKS}" "${ENABLE_EXPERIMENTAL_PACKS}"
}

render_support_notes_if_missing() {
  if [[ ! -f "${GLOBAL_SKILLS_NOTE_PATH}" ]]; then
    cat > "${GLOBAL_SKILLS_NOTE_PATH}" <<'EOF'
# Gemini Skills 目录说明

- 这里放 Gemini CLI 的全局 skills
- 建议把常用提示词、固定流程和检查单收敛到这里
EOF
  fi

  if [[ ! -f "${GLOBAL_POLICIES_NOTE_PATH}" ]]; then
    cat > "${GLOBAL_POLICIES_NOTE_PATH}" <<'EOF'
# Gemini Policies 目录说明

- 这里放 Gemini CLI 的全局策略文件
- 安全边界、审批习惯、项目约束建议集中维护
EOF
  fi

  if [[ ! -f "${GLOBAL_EXTENSIONS_NOTE_PATH}" ]]; then
    cat > "${GLOBAL_EXTENSIONS_NOTE_PATH}" <<'EOF'
# Gemini Extensions 目录说明

- 这里放 Gemini CLI 的本地 extensions
- 官方扩展与本地扩展建议统一记录来源和用途
EOF
  fi

  if [[ ! -f "${GLOBAL_AGENTS_NOTE_PATH}" ]]; then
    cat > "${GLOBAL_AGENTS_NOTE_PATH}" <<'EOF'
# Gemini Agents 目录说明

- 这里放 Gemini CLI 的全局 agents / role 模板
- 规划、评审、测试、安全等角色建议拆分维护
EOF
  fi
}

render_project_template_if_missing() {
  local project_root="$1"
  local project_gemini_dir="${project_root}/.gemini"
  local project_doc="${project_root}/GEMINI.md"
  local project_settings="${project_gemini_dir}/settings.json"
  local project_skills_note="${project_gemini_dir}/skills/README.managed.md"
  local project_extensions_note="${project_gemini_dir}/extensions/README.managed.md"
  local project_policies_note="${project_gemini_dir}/policies/README.managed.md"
  local project_agents_dir="${project_gemini_dir}/agents"
  local project_agents_note="${project_gemini_dir}/agents/README.managed.md"

  mkdir -p "${project_gemini_dir}/skills" "${project_gemini_dir}/extensions" "${project_gemini_dir}/policies" "${project_agents_dir}"
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
- 项目边界和成功标准：看 `.agents/project-context.md`
- 模块和依赖：看 `.agents/architecture.md`
- 开发、测试、发布顺序：看 `.agents/workflow.md`
- 交付门槛：看 `.agents/checklist.md`

## Gemini CLI 项目要求
- 项目级策略优先写到 `.gemini/policies`
- 项目级扩展来源、启用条件和边界优先写到 `.gemini/extensions`
- 新增重要规则、已知坑点、手工步骤后，及时回写 `.agents` 文档
EOF
  fi

  if [[ ! -f "${project_settings}" ]]; then
    cat > "${project_settings}" <<EOF
{
  "model": {
    "name": "$(json_escape "${DEFAULT_MODEL}")"
  },
  "skills": {
    "enabled": true
  }
}
EOF
  fi

  if [[ ! -f "${project_skills_note}" ]]; then
    cat > "${project_skills_note}" <<'EOF'
# 项目 Skills 目录

- 放当前项目专用 skills
- 项目内的固定工作流、命令模板优先写这里
- 适合沉淀实施步骤、测试流程、评审规则
EOF
  fi

  if [[ ! -f "${project_extensions_note}" ]]; then
    cat > "${project_extensions_note}" <<'EOF'
# 项目 Extensions 目录

- 放当前项目专用 extensions
- 记录来源、能力边界和启用条件
- 建议补充依赖、最低权限、失败回退方式
EOF
  fi

  if [[ ! -f "${project_policies_note}" ]]; then
    cat > "${project_policies_note}" <<'EOF'
# 项目 Policies 目录

- 放当前项目专用策略文件
- 包括审批边界、敏感目录、发布约束等
- 变更后要同步检查 `.agents/workflow.md` 和 `.agents/checklist.md`
EOF
  fi

  if [[ ! -f "${project_agents_note}" ]]; then
    cat > "${project_agents_note}" <<'EOF'
# 项目 Agents 目录

- 放当前项目专用 agents / role 模板
- 规划、实现、评审、测试建议分角色管理
- 发布观察和事故处置也建议单独保留角色模板
- 默认已生成：`planner.md`、`implementer.md`、`reviewer.md`、`tester.md`
EOF
  fi
}

sync_global_config() {
  ensure_runtime_layout
  render_settings_json
  render_env_file
  render_memory_template_if_missing
  render_runtime_manifests
  render_support_notes_if_missing

  backup_path_if_exists "${GLOBAL_SETTINGS_PATH}" "Gemini settings.json"
  install -m 600 "${TOOL_SETTINGS_PATH}" "${GLOBAL_SETTINGS_PATH}"
  log_info "已同步全局 settings.json：${GLOBAL_SETTINGS_PATH}"

  backup_path_if_exists "${GLOBAL_ENV_PATH}" "Gemini .env"
  install -m 600 "${TOOL_ENV_PATH}" "${GLOBAL_ENV_PATH}"
  log_info "已同步全局 .env：${GLOBAL_ENV_PATH}"

  if [[ ! -f "${GLOBAL_MEMORY_PATH}" ]]; then
    install -m 644 "${TOOL_MEMORY_PATH}" "${GLOBAL_MEMORY_PATH}"
    log_info "已初始化全局 GEMINI.md：${GLOBAL_MEMORY_PATH}"
  else
    log_info "保留现有全局 GEMINI.md：${GLOBAL_MEMORY_PATH}"
  fi

  sync_extensions "${1:-安装}"
  log_info "已生成初始化清单：${TOOL_PACKS_MANIFEST_PATH}、${TOOL_SKILLS_MANIFEST_PATH}、${TOOL_PLUGINS_MANIFEST_PATH}、${TOOL_HOOKS_MANIFEST_PATH}、${TOOL_MCP_MANIFEST_PATH}、${TOOL_AGENTS_MANIFEST_PATH}"
}

print_summary() {
  print_section "Gemini CLI 配置摘要"
  log_info "安装方式：${INSTALL_METHOD}"
  log_info "模型：${DEFAULT_MODEL}"
  log_info "认证方式：${AUTH_MODE}"
  log_info "官方目录：${GLOBAL_GEMINI_DIR}"
  log_info "工具目录：${TOOL_RUNTIME_ROOT}"
}

cmd_service_install_like() {
  local mode="$1"
  require_config
  require_root
  print_summary

  if ! confirm_action "将${mode} Gemini CLI 并同步全局配置，是否继续？" "${ASSUME_YES}"; then
    log_warn "已取消执行。"
    exit 0
  fi

  ensure_node_runtime
  case "${INSTALL_METHOD}" in
    npm)
      npm install -g "${GEMINI_PACKAGE}"
      ;;
    *)
      die "当前仅实现 INSTALL_METHOD=npm，收到：${INSTALL_METHOD}"
      ;;
  esac

  sync_global_config "${mode}"
  log_info "Gemini CLI 当前版本：$(gemini_version_value)"
}

cmd_service_uninstall() {
  require_config
  require_root

  if ! confirm_action "将卸载 Gemini CLI，但默认保留 ~/.gemini，是否继续？" "${ASSUME_YES}"; then
    log_warn "已取消执行。"
    exit 0
  fi

  case "${INSTALL_METHOD}" in
    npm)
      if npm list -g @google/gemini-cli --depth=0 >/dev/null 2>&1; then
        npm uninstall -g @google/gemini-cli
        log_info "已卸载 npm 全局包：@google/gemini-cli"
      else
        log_warn "未发现 npm 全局包 @google/gemini-cli，跳过卸载。"
      fi
      ;;
    *)
      die "当前仅实现 INSTALL_METHOD=npm，收到：${INSTALL_METHOD}"
      ;;
  esac
}

cmd_service_check() {
  local gemini_path=""
  local runtime_state=""
  local not_ready_reason=""
  local settings_exists="no"
  local env_exists="no"
  local memory_exists="no"
  local skills_exists="no"
  local extensions_exists="no"
  local policies_exists="no"
  local agents_exists="no"
  local current_model="未检测到"
  local current_auth="未检测到"
  local current_approval_mode="未检测到"
  local settings_state="no"
  local env_state="no"
  local extension_missing_count="0"
  local extension_inactive_count="0"
  local extension_summary="未检测到"
  local readiness_summary="未检测到"
  local capability_stats="未检测到"
  local capability_counts="skill 0 / extension 0 / hook 0 / mcp 0 / agent 0"

  load_config_if_present
  readonly_manifest_scope_begin TOOL_PLUGIN_STATUS_PATH
  render_runtime_manifests
  gemini_path="$(gemini_binary_path)"
  write_extension_status_snapshot

  print_section "Gemini CLI 检查"
  print_report_line "Gemini 命令" "${gemini_path:-未安装}"
  print_report_line "Gemini 版本" "$(gemini_version_value)"

  if npm list -g @google/gemini-cli --depth=0 >/dev/null 2>&1; then
    print_report_line "npm 全局包" "@google/gemini-cli 已安装"
  else
    print_report_line "npm 全局包" "未检测到"
  fi

  [[ -f "${GLOBAL_SETTINGS_PATH}" ]] && settings_exists="yes"
  [[ -f "${GLOBAL_ENV_PATH}" ]] && env_exists="yes"
  [[ -f "${GLOBAL_MEMORY_PATH}" ]] && memory_exists="yes"
  [[ -d "${GLOBAL_SKILLS_DIR}" ]] && skills_exists="yes"
  [[ -d "${GLOBAL_EXTENSIONS_DIR}" ]] && extensions_exists="yes"
  [[ -d "${GLOBAL_POLICIES_DIR}" ]] && policies_exists="yes"
  [[ -d "${GLOBAL_AGENTS_DIR}" ]] && agents_exists="yes"

  if [[ -f "${GLOBAL_SETTINGS_PATH}" ]]; then
    current_model="$(extract_json_string_value "name" "${GLOBAL_SETTINGS_PATH}")"
    current_approval_mode="$(extract_json_string_value "defaultApprovalMode" "${GLOBAL_SETTINGS_PATH}")"
    [[ -n "${current_model}" ]] || current_model="未检测到"
    [[ -n "${current_approval_mode}" ]] || current_approval_mode="未检测到"
  fi

  if [[ -f "${GLOBAL_ENV_PATH}" ]]; then
    if grep -Eq '^(GEMINI_API_KEY|GOOGLE_API_KEY)=' "${GLOBAL_ENV_PATH}"; then
      current_auth="api-key"
    elif grep -Eq '^GOOGLE_GENAI_USE_VERTEXAI=(1|true|TRUE|yes|YES|on|ON)$' "${GLOBAL_ENV_PATH}"; then
      current_auth="vertex-ai"
    fi
  fi

  print_report_line "settings.json" "${GLOBAL_SETTINGS_PATH} (${settings_exists})"
  print_report_line ".env" "${GLOBAL_ENV_PATH} (${env_exists})"
  print_report_line "全局 GEMINI.md" "${GLOBAL_MEMORY_PATH} (${memory_exists})"
  print_report_line "当前模型" "${current_model}"
  print_report_line "认证模式" "${current_auth}"
  print_report_line "审批模式" "${current_approval_mode}"
  runtime_state="$(gemini_runtime_state "${gemini_path}" "${settings_exists}" "${env_exists}" "${current_auth}")"
  extension_missing_count="$(extension_status_count "缺失")"
  extension_inactive_count="$(extension_status_count "未生效")"
  extension_summary="$(extension_status_summary)"
  readiness_summary="$(gemini_best_practice_readiness "${gemini_path}" "${settings_exists}" "${env_exists}" "${current_auth}")"
  capability_stats="$(capability_stats_summary "${TOOL_SKILLS_MANIFEST_PATH}" "${TOOL_PLUGINS_MANIFEST_PATH}" "${TOOL_HOOKS_MANIFEST_PATH}" "${TOOL_MCP_MANIFEST_PATH}" "${TOOL_AGENTS_MANIFEST_PATH}" "extension")"
  capability_counts="skill $(manifest_item_count "${TOOL_SKILLS_MANIFEST_PATH}") / extension $(manifest_item_count "${TOOL_PLUGINS_MANIFEST_PATH}") / hook $(manifest_item_count "${TOOL_HOOKS_MANIFEST_PATH}") / mcp $(manifest_item_count "${TOOL_MCP_MANIFEST_PATH}") / agent $(manifest_item_count "${TOOL_AGENTS_MANIFEST_PATH}")"
  readonly_manifest_scope_end

  case "${runtime_state}" in
    未安装)
      not_ready_reason="$(append_reason_text "${not_ready_reason}" "未检测到 gemini 命令")"
      ;;
    未配置)
      [[ "${settings_exists}" != "yes" ]] && not_ready_reason="$(append_reason_text "${not_ready_reason}" "缺少 settings.json")"
      [[ "${env_exists}" != "yes" ]] && not_ready_reason="$(append_reason_text "${not_ready_reason}" "缺少 .env")"
      ;;
    需人工登录或授权)
      not_ready_reason="$(append_reason_text "${not_ready_reason}" "当前认证信息未检测到")"
      ;;
  esac

  if [[ -n "${CONFIG_FILE}" ]]; then
    [[ "$(setting_compare_state "${current_model}" "${DEFAULT_MODEL}")" == "不一致" ]] && not_ready_reason="$(append_reason_text "${not_ready_reason}" "模型与目标不一致")"
    [[ "$(setting_compare_state "${current_model}" "${DEFAULT_MODEL}")" == "缺失" && "${runtime_state}" != "未安装" ]] && not_ready_reason="$(append_reason_text "${not_ready_reason}" "当前模型未配置")"
    [[ "$(setting_compare_state "${current_auth}" "${AUTH_MODE}")" == "不一致" ]] && not_ready_reason="$(append_reason_text "${not_ready_reason}" "认证方式与目标不一致")"
    [[ "$(setting_compare_state "${current_auth}" "${AUTH_MODE}")" == "缺失" && "${runtime_state}" != "未安装" ]] && not_ready_reason="$(append_reason_text "${not_ready_reason}" "当前认证方式未配置")"
  fi

  [[ "${extension_missing_count}" != "0" ]] && not_ready_reason="$(append_reason_text "${not_ready_reason}" "默认 extension 缺失 ${extension_missing_count} 项")"
  [[ "${extension_inactive_count}" != "0" ]] && not_ready_reason="$(append_reason_text "${not_ready_reason}" "默认 extension 未生效 ${extension_inactive_count} 项")"

  print_report_line "当前状态" "${runtime_state}"
  print_report_line "建议动作" "$(recommended_service_action "gemini-cli" "${runtime_state}" "${CONFIG_FILE:-}")"
  [[ -n "${not_ready_reason}" ]] && print_report_line "未就绪原因" "${not_ready_reason}"
  print_report_line "最佳实践就绪度" "${readiness_summary}"
  print_report_line "技能目录" "${GLOBAL_SKILLS_DIR} (${skills_exists})"
  print_report_line "扩展目录" "${GLOBAL_EXTENSIONS_DIR} (${extensions_exists})"
  print_report_line "扩展状态" "${extension_summary}"
  print_report_line "策略目录" "${GLOBAL_POLICIES_DIR} (${policies_exists})"
  print_report_line "Agents 目录" "${GLOBAL_AGENTS_DIR} (${agents_exists})"
  print_report_line "工具目录" "${TOOL_RUNTIME_ROOT}"
  print_report_line "备份目录" "${BACKUP_ROOT}"
  print_report_line "能力包策略" "$(pack_strategy_summary "${COMMON_DEFAULT_PACKS}" "${TOOL_DEFAULT_PACKS}" "${ENHANCED_PACKS}" "${ENABLE_ENHANCED_PACKS}" "${EXPERIMENTAL_PACKS}" "${ENABLE_EXPERIMENTAL_PACKS}")"
  print_report_line "核心能力统计" "${capability_stats}"
  print_report_line "能力项统计" "${capability_counts}"
  print_report_line "能力包清单" "${TOOL_PACKS_MANIFEST_PATH} ($(path_state "${TOOL_PACKS_MANIFEST_PATH}"))"
  print_report_line "技能清单" "${TOOL_SKILLS_MANIFEST_PATH} ($(path_state "${TOOL_SKILLS_MANIFEST_PATH}"))"
  print_report_line "扩展清单" "${TOOL_PLUGINS_MANIFEST_PATH} ($(path_state "${TOOL_PLUGINS_MANIFEST_PATH}"))"
  print_report_line "扩展状态文件" "${TOOL_PLUGIN_STATUS_PATH} ($(path_state "${TOOL_PLUGIN_STATUS_PATH}"))"
  print_report_line "Hook 清单" "${TOOL_HOOKS_MANIFEST_PATH} ($(path_state "${TOOL_HOOKS_MANIFEST_PATH}"))"
  print_report_line "MCP 清单" "${TOOL_MCP_MANIFEST_PATH} ($(path_state "${TOOL_MCP_MANIFEST_PATH}"))"
  print_report_line "Agent 清单" "${TOOL_AGENTS_MANIFEST_PATH} ($(path_state "${TOOL_AGENTS_MANIFEST_PATH}"))"

  if [[ -n "${CONFIG_FILE}" ]]; then
    print_report_line "目标配置文件" "${CONFIG_FILE}"
    print_report_line "目标模型" "${DEFAULT_MODEL}"
    print_report_line "目标认证" "${AUTH_MODE}"
    print_report_line "模型比对" "$(setting_compare_state "${current_model}" "${DEFAULT_MODEL}")"
    print_report_line "认证比对" "$(setting_compare_state "${current_auth}" "${AUTH_MODE}")"
  fi
}

cmd_service_report() {
  local gemini_path=""
  local install_state="未安装"
  local not_ready_reason=""
  local settings_state="missing"
  local current_model="未检测到"
  local current_auth="未检测到"
  local env_state="no"
  local extension_missing_count="0"
  local extension_inactive_count="0"
  local extension_summary="未检测到"
  local readiness_summary="未检测到"
  local capability_stats="未检测到"
  local capability_counts="skill 0 / extension 0 / hook 0 / mcp 0 / agent 0"

  load_config_if_present
  readonly_manifest_scope_begin TOOL_PLUGIN_STATUS_PATH
  render_runtime_manifests
  gemini_path="$(gemini_binary_path)"
  write_extension_status_snapshot

  if [[ -n "${gemini_path}" ]]; then
    install_state="已安装"
  fi

  if [[ -f "${GLOBAL_SETTINGS_PATH}" ]]; then
    settings_state="present"
    current_model="$(extract_json_string_value "name" "${GLOBAL_SETTINGS_PATH}")"
    [[ -n "${current_model}" ]] || current_model="未检测到"
  fi

  if [[ -f "${GLOBAL_ENV_PATH}" ]]; then
    if grep -Eq '^(GEMINI_API_KEY|GOOGLE_API_KEY)=' "${GLOBAL_ENV_PATH}"; then
      current_auth="api-key"
    elif grep -Eq '^GOOGLE_GENAI_USE_VERTEXAI=(1|true|TRUE|yes|YES|on|ON)$' "${GLOBAL_ENV_PATH}"; then
      current_auth="vertex-ai"
    fi
  fi

  install_state="$(gemini_runtime_state "${gemini_path}" "$([[ "${settings_state}" == "present" ]] && printf yes || printf no)" "$([[ -f "${GLOBAL_ENV_PATH}" ]] && printf yes || printf no)" "${current_auth}")"
  extension_missing_count="$(extension_status_count "缺失")"
  extension_inactive_count="$(extension_status_count "未生效")"
  extension_summary="$(extension_status_summary)"
  readiness_summary="$(gemini_best_practice_readiness "${gemini_path}" "$([[ "${settings_state}" == "present" ]] && printf yes || printf no)" "$([[ -f "${GLOBAL_ENV_PATH}" ]] && printf yes || printf no)" "${current_auth}")"
  capability_stats="$(capability_stats_summary "${TOOL_SKILLS_MANIFEST_PATH}" "${TOOL_PLUGINS_MANIFEST_PATH}" "${TOOL_HOOKS_MANIFEST_PATH}" "${TOOL_MCP_MANIFEST_PATH}" "${TOOL_AGENTS_MANIFEST_PATH}" "extension")"
  capability_counts="skill $(manifest_item_count "${TOOL_SKILLS_MANIFEST_PATH}") / extension $(manifest_item_count "${TOOL_PLUGINS_MANIFEST_PATH}") / hook $(manifest_item_count "${TOOL_HOOKS_MANIFEST_PATH}") / mcp $(manifest_item_count "${TOOL_MCP_MANIFEST_PATH}") / agent $(manifest_item_count "${TOOL_AGENTS_MANIFEST_PATH}")"
  readonly_manifest_scope_end

  case "${install_state}" in
    未安装)
      not_ready_reason="$(append_reason_text "${not_ready_reason}" "未检测到 gemini 命令")"
      ;;
    未配置)
      [[ "${settings_state}" != "present" ]] && not_ready_reason="$(append_reason_text "${not_ready_reason}" "缺少 settings.json")"
      [[ ! -f "${GLOBAL_ENV_PATH}" ]] && not_ready_reason="$(append_reason_text "${not_ready_reason}" "缺少 .env")"
      ;;
    需人工登录或授权)
      not_ready_reason="$(append_reason_text "${not_ready_reason}" "当前认证信息未检测到")"
      ;;
  esac

  if [[ -n "${CONFIG_FILE}" ]]; then
    [[ "$(setting_compare_state "${current_model}" "${DEFAULT_MODEL}")" == "不一致" ]] && not_ready_reason="$(append_reason_text "${not_ready_reason}" "模型与目标不一致")"
    [[ "$(setting_compare_state "${current_model}" "${DEFAULT_MODEL}")" == "缺失" && "${install_state}" != "未安装" ]] && not_ready_reason="$(append_reason_text "${not_ready_reason}" "当前模型未配置")"
    [[ "$(setting_compare_state "${current_auth}" "${AUTH_MODE}")" == "不一致" ]] && not_ready_reason="$(append_reason_text "${not_ready_reason}" "认证方式与目标不一致")"
    [[ "$(setting_compare_state "${current_auth}" "${AUTH_MODE}")" == "缺失" && "${install_state}" != "未安装" ]] && not_ready_reason="$(append_reason_text "${not_ready_reason}" "当前认证方式未配置")"
  fi

  [[ "${extension_missing_count}" != "0" ]] && not_ready_reason="$(append_reason_text "${not_ready_reason}" "默认 extension 缺失 ${extension_missing_count} 项")"
  [[ "${extension_inactive_count}" != "0" ]] && not_ready_reason="$(append_reason_text "${not_ready_reason}" "默认 extension 未生效 ${extension_inactive_count} 项")"

  print_section "Gemini CLI 概览"
  print_report_line "安装状态" "${install_state}"
  print_report_line "建议动作" "$(recommended_service_action "gemini-cli" "${install_state}" "${CONFIG_FILE:-}")"
  [[ -n "${not_ready_reason}" ]] && print_report_line "未就绪原因" "${not_ready_reason}"
  print_report_line "Gemini 命令" "${gemini_path:-未安装}"
  print_report_line "当前模型" "${current_model}"
  print_report_line "认证模式" "${current_auth}"
  print_report_line "settings.json" "${GLOBAL_SETTINGS_PATH} (${settings_state})"
  print_report_line "工具目录" "${TOOL_RUNTIME_ROOT}"
  print_report_line "最佳实践就绪度" "${readiness_summary}"
  print_report_line "能力包策略" "$(pack_strategy_summary "${COMMON_DEFAULT_PACKS}" "${TOOL_DEFAULT_PACKS}" "${ENHANCED_PACKS}" "${ENABLE_ENHANCED_PACKS}" "${EXPERIMENTAL_PACKS}" "${ENABLE_EXPERIMENTAL_PACKS}")"
  print_report_line "扩展状态" "${extension_summary}"
  print_report_line "核心能力统计" "${capability_stats}"
  print_report_line "能力项统计" "${capability_counts}"
  print_report_line "能力包清单" "${TOOL_PACKS_MANIFEST_PATH} ($(path_state "${TOOL_PACKS_MANIFEST_PATH}"))"
  print_report_line "扩展状态文件" "${TOOL_PLUGIN_STATUS_PATH} ($(path_state "${TOOL_PLUGIN_STATUS_PATH}"))"
  print_report_line "Agent 清单" "${TOOL_AGENTS_MANIFEST_PATH} ($(path_state "${TOOL_AGENTS_MANIFEST_PATH}"))"

  if [[ -n "${CONFIG_FILE}" ]]; then
    print_report_line "目标模型" "${DEFAULT_MODEL}"
    print_report_line "目标认证" "${AUTH_MODE}"
    print_report_line "模型比对" "$(setting_compare_state "${current_model}" "${DEFAULT_MODEL}")"
    print_report_line "认证比对" "$(setting_compare_state "${current_auth}" "${AUTH_MODE}")"
  fi
}

cmd_config_show() {
  local section="${TARGET_SECTION:-summary}"

  require_config

  print_section "Gemini CLI 配置"

  case "${section}" in
    summary)
      print_report_line "目标配置文件" "${CONFIG_FILE}"
      print_report_line "安装方式" "${INSTALL_METHOD}"
      print_report_line "模型" "${DEFAULT_MODEL}"
      print_report_line "认证方式" "${AUTH_MODE}"
      print_report_line "策略模式" "${POLICY_MODE}"
      print_report_line "审批模式" "${GEMINI_APPROVAL_MODE}"
      ;;
    paths)
      print_report_line "全局目录" "${GLOBAL_GEMINI_DIR}"
      print_report_line "settings.json" "${GLOBAL_SETTINGS_PATH}"
      print_report_line ".env" "${GLOBAL_ENV_PATH}"
      print_report_line "全局 GEMINI.md" "${GLOBAL_MEMORY_PATH}"
      print_report_line "技能目录" "${GLOBAL_SKILLS_DIR}"
      print_report_line "扩展目录" "${GLOBAL_EXTENSIONS_DIR}"
      print_report_line "策略目录" "${GLOBAL_POLICIES_DIR}"
      print_report_line "Agents 目录" "${GLOBAL_AGENTS_DIR}"
      print_report_line "工具目录" "${TOOL_RUNTIME_ROOT}"
      print_report_line "备份目录" "${BACKUP_ROOT}"
      ;;
    extensions)
      print_report_line "默认技能" "${ENABLE_DEFAULT_SKILLS}"
      print_report_line "默认扩展" "${ENABLE_DEFAULT_PLUGINS}"
      print_report_line "默认 Hook" "${ENABLE_DEFAULT_HOOKS}"
      print_report_line "默认 MCP" "${ENABLE_DEFAULT_MCP}"
      print_report_line "默认 Agents" "${ENABLE_DEFAULT_AGENTS}"
      print_report_line "通用默认包" "${COMMON_DEFAULT_PACKS:-<空>}"
      print_report_line "工具默认包" "${TOOL_DEFAULT_PACKS:-<空>}"
      print_report_line "模式" "${MODE}"
      print_report_line "进阶包" "${ENHANCED_PACKS:-<空>}"
      print_report_line "探索包" "${EXPERIMENTAL_PACKS:-<空>}"
      print_report_line "SKILL_SPECS" "${SKILL_SPECS:-<空>}"
      print_report_line "PLUGIN_SPECS" "${PLUGIN_SPECS:-<空>}"
      print_report_line "HOOK_SPECS" "${HOOK_SPECS:-<空>}"
      print_report_line "MCP_SPECS" "${MCP_SPECS:-<空>}"
      print_report_line "AGENT_SPECS" "${AGENT_SPECS:-<空>}"
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
      write_extension_status_snapshot
      render_settings_json
      render_env_file
      render_memory_template_if_missing
      render_runtime_manifests
      render_support_notes_if_missing
      log_info "已初始化 Gemini CLI 工具目录：${TOOL_RUNTIME_ROOT}"
      log_info "已生成工具目录 settings.json：${TOOL_SETTINGS_PATH}"
      log_info "已生成工具目录 .env：${TOOL_ENV_PATH}"
      log_info "已准备工具目录 GEMINI.md 模板：${TOOL_MEMORY_PATH}"
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
      log_info "已生成：${TARGET_PATH}/GEMINI.md"
      log_info "已生成：${TARGET_PATH}/.agents/project-context.md"
      log_info "已生成：${TARGET_PATH}/.agents/architecture.md"
      log_info "已生成：${TARGET_PATH}/.agents/workflow.md"
      log_info "已生成：${TARGET_PATH}/.agents/checklist.md"
      log_info "已生成：${TARGET_PATH}/.gemini/settings.json"
      log_info "已生成：${TARGET_PATH}/.gemini/skills/"
      log_info "已生成：${TARGET_PATH}/.gemini/extensions/"
      log_info "已生成：${TARGET_PATH}/.gemini/policies/"
      log_info "已生成：${TARGET_PATH}/.gemini/agents/"
      ;;
    *)
      die "仅支持 --scope global 或 --scope project，收到：${TARGET_SCOPE:-<空>}"
      ;;
  esac
}

cmd_service_configure() {
  require_config
  if ! confirm_action "将按配置重写全局 Gemini CLI settings.json 与 .env，是否继续？" "${ASSUME_YES}"; then
    log_warn "已取消执行。"
    exit 0
  fi
  sync_global_config
}

cmd_extension_commands_not_exposed() {
  die "Gemini CLI 当前不单独提供 ${COMMAND_GROUP} ${COMMAND_ACTION} 命令，请使用 service install 或 config init 自动准备相关目录与运行清单。"
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
    service:check)
      cmd_service_check
      ;;
    service:report)
      cmd_service_report
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
