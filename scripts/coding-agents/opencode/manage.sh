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
  help_print_title "OpenCode"
  help_print_strong_rule
  help_print_context "最短入口" "manage.sh guide start --tool-name opencode"
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
  help_print_step "1" "manage.sh guide start --tool-name opencode"
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

json_array_from_csv() {
  local input="${1:-}"
  local first=1
  local item=""

  printf '['
  while IFS= read -r item; do
    [[ -n "${item}" ]] || continue
    if [[ "${first}" -eq 0 ]]; then
      printf ', '
    fi
    printf '"%s"' "$(json_escape "${item}")"
    first=0
  done < <(csv_clean_lines "${input}")
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

resolve_local_plugin_spec_path() {
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

opencode_remote_plugin_name_from_spec() {
  local spec="${1:-}"
  local value=""

  case "${spec}" in
    github:*)
      value="${spec#github:}"
      value="${value%/}"
      value="${value%.git}"
      github_repo_like_spec "${value}" || return 1
      printf '%s' "${value##*/}"
      return 0
      ;;
  esac

  if url_like_spec "${spec}"; then
    value="${spec%%\?*}"
    value="${value%/}"
    value="${value##*/}"
    value="${value%.git}"
    printf '%s' "${value}"
    return 0
  fi

  return 1
}

opencode_plugin_has_file_entry() {
  case "${1:-}" in
    *.js|*.mjs|*.cjs|*.ts|*.mts|*.cts)
      return 0
      ;;
  esac
  return 1
}

opencode_plugin_target_state() {
  local target="${1:-}"
  local matches=()

  if [[ -f "${target}" ]]; then
    if opencode_plugin_has_file_entry "${target}"; then
      printf 'file'
    else
      printf 'invalid-file'
    fi
    return 0
  fi

  if [[ -d "${target}" ]]; then
    shopt -s nullglob
    matches=(
      "${target}"/*.js
      "${target}"/*.mjs
      "${target}"/*.cjs
      "${target}"/*.ts
      "${target}"/*.mts
      "${target}"/*.cts
    )
    shopt -u nullglob

    if [[ "${#matches[@]}" -gt 0 ]]; then
      printf 'directory'
    else
      printf 'directory-without-entry'
    fi
    return 0
  fi

  printf 'missing'
}

normalize_config() {
  INSTALL_METHOD="${INSTALL_METHOD:-npm}"
  OPENCODE_PACKAGE="${OPENCODE_PACKAGE:-opencode-ai@latest}"
  DEFAULT_MODEL="${DEFAULT_MODEL:-anthropic/claude-sonnet-4-6}"
  PROVIDER_DEFAULT="${PROVIDER_DEFAULT:-anthropic}"
  OPENAI_API_KEY="${OPENAI_API_KEY:-}"
  ANTHROPIC_API_KEY="${ANTHROPIC_API_KEY:-}"
  GOOGLE_GENERATIVEAI_API_KEY="${GOOGLE_GENERATIVEAI_API_KEY:-}"
  OLLAMA_BASE_URL="${OLLAMA_BASE_URL:-http://localhost:11434}"
  ENABLE_DEFAULT_SKILLS="${ENABLE_DEFAULT_SKILLS:-1}"
  ENABLE_DEFAULT_PLUGINS="${ENABLE_DEFAULT_PLUGINS:-1}"
  ENABLE_DEFAULT_HOOKS="${ENABLE_DEFAULT_HOOKS:-1}"
  ENABLE_DEFAULT_MCP="${ENABLE_DEFAULT_MCP:-1}"
  ENABLE_DEFAULT_AGENTS="${ENABLE_DEFAULT_AGENTS:-1}"
  MODE="${MODE:-}"
  COMMON_DEFAULT_PACKS="${COMMON_DEFAULT_PACKS:-common-core,common-docs-architecture,common-quality,common-backend,common-frontend}"
  TOOL_DEFAULT_PACKS="${TOOL_DEFAULT_PACKS:-opencode-core,opencode-workspace}"
  ENHANCED_PACKS="${ENHANCED_PACKS:-opencode-memory,opencode-safety,enhanced-browser-deep,enhanced-long-memory,enhanced-background-agents}"
  ENABLE_ENHANCED_PACKS="${ENABLE_ENHANCED_PACKS:-0}"
  EXPERIMENTAL_PACKS="${EXPERIMENTAL_PACKS:-experimental-bleeding-edge}"
  ENABLE_EXPERIMENTAL_PACKS="${ENABLE_EXPERIMENTAL_PACKS:-0}"
  SKILL_SPECS="${SKILL_SPECS:-}"
  PLUGIN_SPECS="${PLUGIN_SPECS:-}"
  HOOK_SPECS="${HOOK_SPECS:-}"
  MCP_SPECS="${MCP_SPECS:-}"
  AGENT_SPECS="${AGENT_SPECS:-}"
  normalize_mode_profile
  GLOBAL_OPENCODE_DIR="${GLOBAL_OPENCODE_DIR:-/root/.config/opencode}"
  GLOBAL_CONFIG_PATH="${GLOBAL_CONFIG_PATH:-${GLOBAL_OPENCODE_DIR}/opencode.json}"
  GLOBAL_AGENTS_PATH="${GLOBAL_AGENTS_PATH:-${GLOBAL_OPENCODE_DIR}/AGENTS.md}"
  GLOBAL_AGENTS_DIR="${GLOBAL_AGENTS_DIR:-${GLOBAL_OPENCODE_DIR}/agents}"
  GLOBAL_PLUGINS_DIR="${GLOBAL_PLUGINS_DIR:-${GLOBAL_OPENCODE_DIR}/plugins}"
  GLOBAL_PLUGIN_CACHE_DIR="${GLOBAL_PLUGIN_CACHE_DIR:-/root/.cache/opencode/node_modules}"
  GLOBAL_SKILLS_DIR="${GLOBAL_SKILLS_DIR:-/root/.agents/skills}"
  GLOBAL_SKILLS_NOTE_PATH="${GLOBAL_SKILLS_DIR}/README.managed.md"
  GLOBAL_PLUGINS_NOTE_PATH="${GLOBAL_PLUGINS_DIR}/README.managed.md"
  GLOBAL_AGENTS_NOTE_PATH="${GLOBAL_AGENTS_DIR}/README.managed.md"

  TOOL_RUNTIME_ROOT="${TOOL_RUNTIME_ROOT:-${SCRIPT_DIR}}"
  BACKUP_ROOT="${BACKUP_ROOT:-${TOOL_RUNTIME_ROOT}/backups}"
  TOOL_BIN_DIR="${TOOL_RUNTIME_ROOT}/bin"
  TOOL_CONFIG_DIR="${TOOL_RUNTIME_ROOT}/config"
  TOOL_GLOBAL_DIR="${TOOL_CONFIG_DIR}/global"
  TOOL_GLOBAL_CONFIG_PATH="${TOOL_GLOBAL_DIR}/opencode.json"
  TOOL_GLOBAL_AGENTS_PATH="${TOOL_GLOBAL_DIR}/AGENTS.md"
  TOOL_ENV_PATH="${TOOL_GLOBAL_DIR}/provider.env"
  TOOL_WRAPPER_PATH="${TOOL_BIN_DIR}/opencode-managed"
  TOOL_MANIFESTS_DIR="${TOOL_RUNTIME_ROOT}/manifests"
  TOOL_PACKS_MANIFEST_PATH="${TOOL_MANIFESTS_DIR}/packs.manifest"
  TOOL_SKILLS_MANIFEST_PATH="${TOOL_MANIFESTS_DIR}/skills.manifest"
  TOOL_PLUGINS_MANIFEST_PATH="${TOOL_MANIFESTS_DIR}/plugins.manifest"
  TOOL_PLUGIN_STATUS_PATH="${TOOL_MANIFESTS_DIR}/plugins.status"
  TOOL_HOOKS_MANIFEST_PATH="${TOOL_MANIFESTS_DIR}/hooks.manifest"
  TOOL_MCP_MANIFEST_PATH="${TOOL_MANIFESTS_DIR}/mcp.manifest"
  TOOL_AGENTS_MANIFEST_PATH="${TOOL_MANIFESTS_DIR}/agents.manifest"
}

refresh_plugin_plan() {
  local spec=""
  local resolved_path=""
  local -a plugin_specs=()

  if [[ "${ENABLE_DEFAULT_PLUGINS}" == "1" ]]; then
    RESOLVED_PLUGIN_SPECS="$(resolve_installable_capability_items_csv "opencode" "plugin" "config-plugin" "${COMMON_DEFAULT_PACKS}" "${TOOL_DEFAULT_PACKS}" "${ENHANCED_PACKS}" "${ENABLE_ENHANCED_PACKS}" "${EXPERIMENTAL_PACKS}" "${ENABLE_EXPERIMENTAL_PACKS}" "${PLUGIN_SPECS}")"
  else
    RESOLVED_PLUGIN_SPECS="${PLUGIN_SPECS}"
  fi
  RESOLVED_PACKAGE_PLUGIN_SPECS=""
  RESOLVED_LOCAL_PLUGIN_SPECS=""
  RESOLVED_MANUAL_PLUGIN_SPECS=""

  mapfile -t plugin_specs < <(csv_clean_lines "${RESOLVED_PLUGIN_SPECS}")
  for spec in "${plugin_specs[@]}"; do
    [[ -n "${spec}" ]] || continue
    if [[ "${spec}" == github:* ]]; then
      RESOLVED_MANUAL_PLUGIN_SPECS="$(csv_merge_unique "${RESOLVED_MANUAL_PLUGIN_SPECS}" "${spec}")"
      continue
    fi
    if url_like_spec "${spec}"; then
      RESOLVED_MANUAL_PLUGIN_SPECS="$(csv_merge_unique "${RESOLVED_MANUAL_PLUGIN_SPECS}" "${spec}")"
      continue
    fi
    if path_like_spec "${spec}"; then
      resolved_path="$(resolve_local_plugin_spec_path "${spec}")"
      RESOLVED_LOCAL_PLUGIN_SPECS="$(csv_merge_unique "${RESOLVED_LOCAL_PLUGIN_SPECS}" "${resolved_path}")"
      continue
    fi
    RESOLVED_PACKAGE_PLUGIN_SPECS="$(csv_merge_unique "${RESOLVED_PACKAGE_PLUGIN_SPECS}" "${spec}")"
  done
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

ensure_runtime_layout() {
  mkdir -p \
    "${TOOL_RUNTIME_ROOT}" \
    "${TOOL_BIN_DIR}" \
    "${TOOL_GLOBAL_DIR}" \
    "${BACKUP_ROOT}" \
    "${TOOL_MANIFESTS_DIR}" \
    "${GLOBAL_OPENCODE_DIR}" \
    "${GLOBAL_SKILLS_DIR}" \
    "${GLOBAL_PLUGINS_DIR}" \
    "${GLOBAL_AGENTS_DIR}"
}

ensure_runtime_workspace() {
  mkdir -p \
    "${TOOL_RUNTIME_ROOT}" \
    "${TOOL_BIN_DIR}" \
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

opencode_binary_path() {
  command -v opencode 2>/dev/null || true
}

opencode_version_value() {
  if command -v opencode >/dev/null 2>&1; then
    opencode --version 2>&1 | tail -n 1
  else
    printf '未安装'
  fi
}

render_global_config() {
  cat > "${TOOL_GLOBAL_CONFIG_PATH}" <<EOF
{
  "\$schema": "https://opencode.ai/config.json",
  "model": "$(json_escape "${DEFAULT_MODEL}")",
  "instructions": [
    "${GLOBAL_AGENTS_PATH}"
  ]$(if [[ -n "${RESOLVED_PACKAGE_PLUGIN_SPECS}" ]]; then printf ',\n  "plugin": %s' "$(json_array_from_csv "${RESOLVED_PACKAGE_PLUGIN_SPECS}")"; fi),
  "provider": {
    "$(json_escape "${PROVIDER_DEFAULT}")": {
      "options": {
EOF

  case "${PROVIDER_DEFAULT}" in
    anthropic)
      printf '        "apiKey": "{env:ANTHROPIC_API_KEY}"\n' >> "${TOOL_GLOBAL_CONFIG_PATH}"
      ;;
    openai)
      printf '        "apiKey": "{env:OPENAI_API_KEY}"\n' >> "${TOOL_GLOBAL_CONFIG_PATH}"
      ;;
    google)
      printf '        "apiKey": "{env:GOOGLE_GENERATIVEAI_API_KEY}"\n' >> "${TOOL_GLOBAL_CONFIG_PATH}"
      ;;
    ollama)
      printf '        "baseUrl": "%s"\n' "$(json_escape "${OLLAMA_BASE_URL}")" >> "${TOOL_GLOBAL_CONFIG_PATH}"
      ;;
    *)
      printf '        "apiKey": ""\n' >> "${TOOL_GLOBAL_CONFIG_PATH}"
      ;;
  esac

  cat >> "${TOOL_GLOBAL_CONFIG_PATH}" <<EOF
      }
    }
  }
}
EOF
}

opencode_plugin_cache_path() {
  local package_name="${1:-}"
  printf '%s/%s' "${GLOBAL_PLUGIN_CACHE_DIR}" "${package_name}"
}

sync_local_plugins() {
  local source_path=""
  local target_path=""
  local -a local_plugin_specs=()

  mapfile -t local_plugin_specs < <(csv_clean_lines "${RESOLVED_LOCAL_PLUGIN_SPECS}")
  for source_path in "${local_plugin_specs[@]}"; do
    [[ -n "${source_path}" ]] || continue
    target_path="${GLOBAL_PLUGINS_DIR}/$(basename "${source_path}")"

    if [[ ! -e "${source_path}" ]]; then
      log_warn "本地插件路径不存在，跳过：${source_path}"
      continue
    fi

    if [[ -e "${target_path}" ]]; then
      log_info "保留现有本地插件：${target_path}"
      continue
    fi

    cp -a "${source_path}" "${target_path}"
    log_info "已接入本地插件：${target_path}"
    if [[ -d "${target_path}" ]]; then
      log_warn "已同步插件目录：${target_path}。OpenCode 官方文档优先建议直接把 JS/TS 插件文件放到 ~/.config/opencode/plugins 根目录。"
    fi
  done
}

write_plugin_status_snapshot() {
  local package_name=""
  local source_path=""
  local target_path=""
  local cache_path=""
  local target_state=""
  local configured="no"
  local -a package_plugins=()
  local -a local_plugins=()
  local -a manual_plugins=()

  mkdir -p "$(dirname "${TOOL_PLUGIN_STATUS_PATH}")"

  {
    printf '# OpenCode plugin 状态\n'
    printf 'name|status|source|detail\n'
  } > "${TOOL_PLUGIN_STATUS_PATH}"

  mapfile -t package_plugins < <(csv_clean_lines "${RESOLVED_PACKAGE_PLUGIN_SPECS}")
  for package_name in "${package_plugins[@]}"; do
    [[ -n "${package_name}" ]] || continue
    cache_path="$(opencode_plugin_cache_path "${package_name}")"
    configured="no"

    if [[ -f "${GLOBAL_CONFIG_PATH}" ]] && grep -F "\"${package_name}\"" "${GLOBAL_CONFIG_PATH}" >/dev/null 2>&1; then
      configured="yes"
    fi

    if [[ "${configured}" == "yes" && -d "${cache_path}" ]]; then
      printf '%s|已安装|%s|%s\n' "${package_name}" "${package_name}" "${cache_path}" >> "${TOOL_PLUGIN_STATUS_PATH}"
    elif [[ "${configured}" == "yes" ]]; then
      printf '%s|已配置|%s|等待 OpenCode 首次启动后自动下载\n' "${package_name}" "${package_name}" >> "${TOOL_PLUGIN_STATUS_PATH}"
    else
      printf '%s|缺失|%s|未写入 opencode.json\n' "${package_name}" "${package_name}" >> "${TOOL_PLUGIN_STATUS_PATH}"
    fi
  done

  mapfile -t local_plugins < <(csv_clean_lines "${RESOLVED_LOCAL_PLUGIN_SPECS}")
  for source_path in "${local_plugins[@]}"; do
    [[ -n "${source_path}" ]] || continue
    target_path="${GLOBAL_PLUGINS_DIR}/$(basename "${source_path}")"
    target_state="$(opencode_plugin_target_state "${target_path}")"
    if [[ "${target_state}" == "file" ]]; then
      printf '%s|已安装|%s|%s\n' "$(basename "${source_path}")" "${source_path}" "${target_path}" >> "${TOOL_PLUGIN_STATUS_PATH}"
    elif [[ "${target_state}" == "directory" ]]; then
      printf '%s|需人工处理|%s|已同步目录 %s；OpenCode 官方文档只明确支持把 JS/TS 插件文件直接放到插件根目录\n' "$(basename "${source_path}")" "${source_path}" "${target_path}" >> "${TOOL_PLUGIN_STATUS_PATH}"
    elif [[ "${target_state}" == "directory-without-entry" ]]; then
      printf '%s|需人工处理|%s|已同步目录 %s，但未发现顶层 JS/TS 插件入口\n' "$(basename "${source_path}")" "${source_path}" "${target_path}" >> "${TOOL_PLUGIN_STATUS_PATH}"
    elif [[ "${target_state}" == "invalid-file" ]]; then
      printf '%s|需人工处理|%s|目标文件已同步到 %s，但文件后缀不是 OpenCode 支持的 JS/TS 插件文件\n' "$(basename "${source_path}")" "${source_path}" "${target_path}" >> "${TOOL_PLUGIN_STATUS_PATH}"
    elif [[ -e "${source_path}" ]]; then
      printf '%s|缺失|%s|插件源存在，但未同步到 %s\n' "$(basename "${source_path}")" "${source_path}" "${target_path}" >> "${TOOL_PLUGIN_STATUS_PATH}"
    else
      printf '%s|缺失|%s|本地插件源不存在\n' "$(basename "${source_path}")" "${source_path}" >> "${TOOL_PLUGIN_STATUS_PATH}"
    fi
  done

  mapfile -t manual_plugins < <(csv_clean_lines "${RESOLVED_MANUAL_PLUGIN_SPECS}")
  for source_path in "${manual_plugins[@]}"; do
    [[ -n "${source_path}" ]] || continue
    printf '%s|需人工处理|%s|远程来源已登记。OpenCode 官方当前只直接支持 npm 包或本地 JS/TS 插件文件，请先将仓库内容落地到 ~/.config/opencode/plugins/ 或发布为 npm 包\n' "$(opencode_remote_plugin_name_from_spec "${source_path}" || basename "${source_path}")" "${source_path}" >> "${TOOL_PLUGIN_STATUS_PATH}"
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
  printf '已安装 %s / 已配置 %s / 缺失 %s / 需人工处理 %s' \
    "$(plugin_status_count "已安装")" \
    "$(plugin_status_count "已配置")" \
    "$(plugin_status_count "缺失")" \
    "$(plugin_status_count "需人工处理")"
}

opencode_auth_state() {
  case "${PROVIDER_DEFAULT}" in
    anthropic)
      if [[ -n "${ANTHROPIC_API_KEY}" ]] || printenv ANTHROPIC_API_KEY >/dev/null 2>&1 || [[ -f "${TOOL_ENV_PATH}" && "$(grep -c '^export ANTHROPIC_API_KEY=' "${TOOL_ENV_PATH}" 2>/dev/null)" != "0" ]]; then
        printf '已配置'
      else
        printf '未配置'
      fi
      ;;
    openai)
      if [[ -n "${OPENAI_API_KEY}" ]] || printenv OPENAI_API_KEY >/dev/null 2>&1 || [[ -f "${TOOL_ENV_PATH}" && "$(grep -c '^export OPENAI_API_KEY=' "${TOOL_ENV_PATH}" 2>/dev/null)" != "0" ]]; then
        printf '已配置'
      else
        printf '未配置'
      fi
      ;;
    google)
      if [[ -n "${GOOGLE_GENERATIVEAI_API_KEY}" ]] || printenv GOOGLE_GENERATIVEAI_API_KEY >/dev/null 2>&1 || [[ -f "${TOOL_ENV_PATH}" && "$(grep -c '^export GOOGLE_GENERATIVEAI_API_KEY=' "${TOOL_ENV_PATH}" 2>/dev/null)" != "0" ]]; then
        printf '已配置'
      else
        printf '未配置'
      fi
      ;;
    ollama)
      printf '本地 provider'
      ;;
    *)
      printf '未检测到'
      ;;
  esac
}

opencode_runtime_state() {
  local opencode_path="${1:-}"
  local config_exists="${2:-no}"
  local auth_state="${3:-未检测到}"

  if [[ -z "${opencode_path}" ]]; then
    printf '未安装'
  elif [[ "${config_exists}" != "yes" ]]; then
    printf '未配置'
  elif [[ "${auth_state}" == "未配置" ]]; then
    printf '需人工登录或授权'
  elif [[ "$(plugin_status_count "需人工处理")" != "0" ]]; then
    printf '需人工处理'
  elif [[ "$(plugin_status_count "已配置")" != "0" || "$(plugin_status_count "缺失")" != "0" ]]; then
    printf '未生效'
  else
    printf '已安装'
  fi
}

opencode_best_practice_readiness() {
  local opencode_path="${1:-}"
  local config_exists="${2:-no}"
  local auth_state="${3:-未检测到}"

  if [[ -z "${opencode_path}" ]]; then
    printf '未安装'
  elif [[ "${config_exists}" != "yes" ]]; then
    printf '未配置'
  elif [[ "${auth_state}" == "未配置" ]]; then
    printf '待授权'
  elif [[ ! -f "${TOOL_PACKS_MANIFEST_PATH}" || ! -f "${TOOL_PLUGINS_MANIFEST_PATH}" || ! -f "${TOOL_PLUGIN_STATUS_PATH}" ]]; then
    printf '工具清单缺失'
  elif [[ "$(plugin_status_count "需人工处理")" != "0" ]]; then
    printf '需人工处理'
  elif [[ "$(plugin_status_count "已配置")" != "0" ]]; then
    printf '等待首次启动拉取依赖'
  elif [[ "$(plugin_status_count "缺失")" != "0" ]]; then
    printf '推荐基线待补齐'
  elif [[ "${ENABLE_ENHANCED_PACKS}" == "1" || "${ENABLE_EXPERIMENTAL_PACKS}" == "1" ]]; then
    printf '增强基线已启用'
  else
    printf '推荐基线已就绪'
  fi
}

render_global_agents_if_missing() {
  if [[ -f "${TOOL_GLOBAL_AGENTS_PATH}" ]]; then
    return 0
  fi

  cat > "${TOOL_GLOBAL_AGENTS_PATH}" <<'EOF'
# OpenCode 全局工作习惯

## 偏好
- 回复使用中文
- 先给结论，再补原因
- 不改无关代码

## 常用约束
- 变更前先看现有实现
- 高风险命令前明确提示
- 优先用项目已有工具链
EOF
}

render_runtime_manifests() {
  write_pack_manifest "${TOOL_PACKS_MANIFEST_PATH}" "opencode" "${COMMON_DEFAULT_PACKS}" "${TOOL_DEFAULT_PACKS}" "${ENHANCED_PACKS}" "${ENABLE_ENHANCED_PACKS}" "${EXPERIMENTAL_PACKS}" "${ENABLE_EXPERIMENTAL_PACKS}"
  write_capability_manifest "${TOOL_SKILLS_MANIFEST_PATH}" "OpenCode skill 初始化清单" "${ENABLE_DEFAULT_SKILLS}" "${SKILL_SPECS}" "默认仅初始化 ~/.agents/skills 目录结构" "opencode" "skill" "${COMMON_DEFAULT_PACKS}" "${TOOL_DEFAULT_PACKS}" "${ENHANCED_PACKS}" "${ENABLE_ENHANCED_PACKS}" "${EXPERIMENTAL_PACKS}" "${ENABLE_EXPERIMENTAL_PACKS}"
  write_capability_manifest "${TOOL_PLUGINS_MANIFEST_PATH}" "OpenCode plugin 初始化清单" "${ENABLE_DEFAULT_PLUGINS}" "${PLUGIN_SPECS}" "默认仅初始化 ~/.config/opencode/plugins 目录结构" "opencode" "plugin" "${COMMON_DEFAULT_PACKS}" "${TOOL_DEFAULT_PACKS}" "${ENHANCED_PACKS}" "${ENABLE_ENHANCED_PACKS}" "${EXPERIMENTAL_PACKS}" "${ENABLE_EXPERIMENTAL_PACKS}"
  write_capability_manifest "${TOOL_HOOKS_MANIFEST_PATH}" "OpenCode hook 初始化清单" "${ENABLE_DEFAULT_HOOKS}" "${HOOK_SPECS}" "默认保留为空，按团队约定再补" "opencode" "hook" "${COMMON_DEFAULT_PACKS}" "${TOOL_DEFAULT_PACKS}" "${ENHANCED_PACKS}" "${ENABLE_ENHANCED_PACKS}" "${EXPERIMENTAL_PACKS}" "${ENABLE_EXPERIMENTAL_PACKS}"
  write_capability_manifest "${TOOL_MCP_MANIFEST_PATH}" "OpenCode MCP 初始化清单" "${ENABLE_DEFAULT_MCP}" "${MCP_SPECS}" "默认保留为空，按实际服务器再接入" "opencode" "mcp" "${COMMON_DEFAULT_PACKS}" "${TOOL_DEFAULT_PACKS}" "${ENHANCED_PACKS}" "${ENABLE_ENHANCED_PACKS}" "${EXPERIMENTAL_PACKS}" "${ENABLE_EXPERIMENTAL_PACKS}"
  write_capability_manifest "${TOOL_AGENTS_MANIFEST_PATH}" "OpenCode agent 初始化清单" "${ENABLE_DEFAULT_AGENTS}" "${AGENT_SPECS}" "默认初始化 ~/.config/opencode/agents 目录结构" "opencode" "agent" "${COMMON_DEFAULT_PACKS}" "${TOOL_DEFAULT_PACKS}" "${ENHANCED_PACKS}" "${ENABLE_ENHANCED_PACKS}" "${EXPERIMENTAL_PACKS}" "${ENABLE_EXPERIMENTAL_PACKS}"
}

render_support_notes_if_missing() {
  if [[ ! -f "${GLOBAL_SKILLS_NOTE_PATH}" ]]; then
    cat > "${GLOBAL_SKILLS_NOTE_PATH}" <<'EOF'
# OpenCode Skills 目录说明

- 这里放 OpenCode 可复用的全局 skills
- 建议把通用流程、规范和检查单集中维护
EOF
  fi

  if [[ ! -f "${GLOBAL_PLUGINS_NOTE_PATH}" ]]; then
    cat > "${GLOBAL_PLUGINS_NOTE_PATH}" <<'EOF'
# OpenCode Plugins 目录说明

- 这里放 OpenCode 的全局插件或扩展说明
- 插件依赖和安装来源建议一并记录
EOF
  fi

  if [[ ! -f "${GLOBAL_AGENTS_NOTE_PATH}" ]]; then
    cat > "${GLOBAL_AGENTS_NOTE_PATH}" <<'EOF'
# OpenCode Agents 目录说明

- 这里放 OpenCode 的全局 agents / role 模板
- 规划、评审、安全等角色建议拆分维护
EOF
  fi
}

render_runtime_env_file() {
  : > "${TOOL_ENV_PATH}"
  [[ -n "${OPENAI_API_KEY}" ]] && printf 'export OPENAI_API_KEY=%q\n' "${OPENAI_API_KEY}" >> "${TOOL_ENV_PATH}"
  [[ -n "${ANTHROPIC_API_KEY}" ]] && printf 'export ANTHROPIC_API_KEY=%q\n' "${ANTHROPIC_API_KEY}" >> "${TOOL_ENV_PATH}"
  [[ -n "${GOOGLE_GENERATIVEAI_API_KEY}" ]] && printf 'export GOOGLE_GENERATIVEAI_API_KEY=%q\n' "${GOOGLE_GENERATIVEAI_API_KEY}" >> "${TOOL_ENV_PATH}"
  return 0
}

render_wrapper_script() {
  cat > "${TOOL_WRAPPER_PATH}" <<EOF
#!/usr/bin/env bash
set -Eeuo pipefail

if [[ -f "${TOOL_ENV_PATH}" ]]; then
  # shellcheck disable=SC1090
  source "${TOOL_ENV_PATH}"
fi

exec opencode "\$@"
EOF
  chmod 755 "${TOOL_WRAPPER_PATH}"
}

render_project_template_if_missing() {
  local project_root="$1"
  local project_opencode_dir="${project_root}/.opencode"
  local project_doc="${project_root}/AGENTS.md"
  local project_config="${project_root}/opencode.json"
  local project_skills_note="${project_opencode_dir}/skills/README.managed.md"
  local project_plugins_note="${project_opencode_dir}/plugins/README.managed.md"
  local project_agents_dir="${project_opencode_dir}/agents"
  local project_agents_note="${project_opencode_dir}/agents/README.managed.md"

  mkdir -p "${project_opencode_dir}/skills" "${project_opencode_dir}/plugins" "${project_agents_dir}"
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
- 目标和边界：看 `.agents/project-context.md`
- 架构和依赖：看 `.agents/architecture.md`
- 实施、测试、发布顺序：看 `.agents/workflow.md`
- 交付门槛：看 `.agents/checklist.md`

## OpenCode 项目要求
- 项目级配置优先放在 `opencode.json`
- 项目级插件说明优先放在 `.opencode/plugins`
- 项目级角色模板优先放在 `.opencode/agents`
- 变更涉及 provider、插件、发布步骤时，及时回写 `.agents` 文档
EOF
  fi

  if [[ ! -f "${project_config}" ]]; then
    cat > "${project_config}" <<EOF
{
  "\$schema": "https://opencode.ai/config.json",
  "model": "$(json_escape "${DEFAULT_MODEL}")",
  "instructions": [
    "./AGENTS.md",
    "./.agents/project-context.md",
    "./.agents/architecture.md",
    "./.agents/workflow.md",
    "./.agents/checklist.md"
  ]
}
EOF
  fi

  if [[ ! -f "${project_skills_note}" ]]; then
    cat > "${project_skills_note}" <<'EOF'
# 项目 Skills 目录

- 放当前项目专用 skills
- 项目 SOP、命令模板、交付检查单优先写这里
- 适合沉淀实现套路、测试步骤、评审规则
EOF
  fi

  if [[ ! -f "${project_plugins_note}" ]]; then
    cat > "${project_plugins_note}" <<'EOF'
# 项目 Plugins 目录

- 放当前项目专用插件或扩展说明
- 记录来源、依赖和启用条件
- 建议补充入口文件、最低权限、失败回退方式
EOF
  fi

  if [[ ! -f "${project_agents_note}" ]]; then
    cat > "${project_agents_note}" <<'EOF'
# 项目 Agents 目录

- 放当前项目专用 agents / role 模板
- 规划、实现、评审建议拆分维护
- 测试、发布观察、事故处置也建议拆角色维护
- 默认已生成：`planner.md`、`implementer.md`、`reviewer.md`、`tester.md`
EOF
  fi
}

sync_global_config() {
  ensure_runtime_layout
  render_global_config
  render_global_agents_if_missing
  render_runtime_env_file
  render_wrapper_script
  render_runtime_manifests
  render_support_notes_if_missing
  sync_local_plugins

  backup_path_if_exists "${GLOBAL_CONFIG_PATH}" "OpenCode opencode.json"
  install -m 600 "${TOOL_GLOBAL_CONFIG_PATH}" "${GLOBAL_CONFIG_PATH}"
  log_info "已同步全局 opencode.json：${GLOBAL_CONFIG_PATH}"

  if [[ ! -f "${GLOBAL_AGENTS_PATH}" ]]; then
    install -m 644 "${TOOL_GLOBAL_AGENTS_PATH}" "${GLOBAL_AGENTS_PATH}"
    log_info "已初始化全局 AGENTS.md：${GLOBAL_AGENTS_PATH}"
  else
    log_info "保留现有全局 AGENTS.md：${GLOBAL_AGENTS_PATH}"
  fi

  if [[ -s "${TOOL_ENV_PATH}" ]]; then
    log_info "已生成工具目录 provider 环境文件：${TOOL_ENV_PATH}"
  fi
  write_plugin_status_snapshot
  log_info "已生成工具目录包装命令：${TOOL_WRAPPER_PATH}"
  log_info "已生成初始化清单：${TOOL_PACKS_MANIFEST_PATH}、${TOOL_SKILLS_MANIFEST_PATH}、${TOOL_PLUGINS_MANIFEST_PATH}、${TOOL_HOOKS_MANIFEST_PATH}、${TOOL_MCP_MANIFEST_PATH}、${TOOL_AGENTS_MANIFEST_PATH}"
}

print_summary() {
  print_section "OpenCode 配置摘要"
  log_info "安装方式：${INSTALL_METHOD}"
  log_info "模型：${DEFAULT_MODEL}"
  log_info "默认 provider：${PROVIDER_DEFAULT}"
  log_info "官方目录：${GLOBAL_OPENCODE_DIR}"
  log_info "工具目录：${TOOL_RUNTIME_ROOT}"
}

cmd_service_install_like() {
  local mode="$1"
  require_config
  require_root
  print_summary

  if ! confirm_action "将${mode} OpenCode 并同步全局配置，是否继续？" "${ASSUME_YES}"; then
    log_warn "已取消执行。"
    exit 0
  fi

  ensure_node_runtime
  case "${INSTALL_METHOD}" in
    npm)
      npm install -g "${OPENCODE_PACKAGE}"
      ;;
    *)
      die "当前仅实现 INSTALL_METHOD=npm，收到：${INSTALL_METHOD}"
      ;;
  esac

  sync_global_config
  log_info "OpenCode 当前版本：$(opencode_version_value)"
}

cmd_service_uninstall() {
  require_config
  require_root

  if ! confirm_action "将卸载 OpenCode CLI，但默认保留 ~/.config/opencode，是否继续？" "${ASSUME_YES}"; then
    log_warn "已取消执行。"
    exit 0
  fi

  case "${INSTALL_METHOD}" in
    npm)
      if npm list -g opencode-ai --depth=0 >/dev/null 2>&1; then
        npm uninstall -g opencode-ai
        log_info "已卸载 npm 全局包：opencode-ai"
      else
        log_warn "未发现 npm 全局包 opencode-ai，跳过卸载。"
      fi
      ;;
    *)
      die "当前仅实现 INSTALL_METHOD=npm，收到：${INSTALL_METHOD}"
      ;;
  esac
}

cmd_service_check() {
  local opencode_path=""
  local runtime_state=""
  local not_ready_reason=""
  local config_exists="no"
  local agents_exists="no"
  local agents_dir_exists="no"
  local skills_exists="no"
  local plugins_exists="no"
  local current_model="未检测到"
  local current_provider="未检测到"
  local auth_state="未检测到"
  local plugin_configured_count="0"
  local plugin_missing_count="0"
  local plugin_summary="未检测到"
  local readiness_summary="未检测到"
  local capability_stats="未检测到"
  local capability_counts="skill 0 / plugin 0 / hook 0 / mcp 0 / agent 0"

  load_config_if_present
  readonly_manifest_scope_begin TOOL_PLUGIN_STATUS_PATH
  render_runtime_manifests
  opencode_path="$(opencode_binary_path)"
  write_plugin_status_snapshot

  print_section "OpenCode 检查"
  print_report_line "OpenCode 命令" "${opencode_path:-未安装}"
  print_report_line "OpenCode 版本" "$(opencode_version_value)"

  if npm list -g opencode-ai --depth=0 >/dev/null 2>&1; then
    print_report_line "npm 全局包" "opencode-ai 已安装"
  else
    print_report_line "npm 全局包" "未检测到"
  fi

  [[ -f "${GLOBAL_CONFIG_PATH}" ]] && config_exists="yes"
  [[ -f "${GLOBAL_AGENTS_PATH}" ]] && agents_exists="yes"
  [[ -d "${GLOBAL_AGENTS_DIR}" ]] && agents_dir_exists="yes"
  [[ -d "${GLOBAL_SKILLS_DIR}" ]] && skills_exists="yes"
  [[ -d "${GLOBAL_PLUGINS_DIR}" ]] && plugins_exists="yes"

  if [[ -f "${GLOBAL_CONFIG_PATH}" ]]; then
    current_model="$(extract_json_string_value "model" "${GLOBAL_CONFIG_PATH}")"
    [[ -n "${current_model}" ]] || current_model="未检测到"
    current_provider="$(grep -A3 '"provider"' "${GLOBAL_CONFIG_PATH}" | tail -n +2 | grep -o '"[^"]*"[[:space:]]*:[[:space:]]*{' | head -n 1 | sed 's/^"//; s/"[[:space:]]*:[[:space:]]*{$//' || true)"
    [[ -n "${current_provider}" ]] || current_provider="未检测到"
  fi
  auth_state="$(opencode_auth_state)"

  print_report_line "opencode.json" "${GLOBAL_CONFIG_PATH} (${config_exists})"
  print_report_line "全局 AGENTS" "${GLOBAL_AGENTS_PATH} (${agents_exists})"
  print_report_line "Agents 目录" "${GLOBAL_AGENTS_DIR} (${agents_dir_exists})"
  print_report_line "当前模型" "${current_model}"
  print_report_line "当前 provider" "${current_provider}"
  print_report_line "当前鉴权" "${auth_state}"
  runtime_state="$(opencode_runtime_state "${opencode_path}" "${config_exists}" "${auth_state}")"
  plugin_configured_count="$(plugin_status_count "已配置")"
  plugin_missing_count="$(plugin_status_count "缺失")"
  plugin_summary="$(plugin_status_summary)"
  readiness_summary="$(opencode_best_practice_readiness "${opencode_path}" "${config_exists}" "${auth_state}")"
  capability_stats="$(capability_stats_summary "${TOOL_SKILLS_MANIFEST_PATH}" "${TOOL_PLUGINS_MANIFEST_PATH}" "${TOOL_HOOKS_MANIFEST_PATH}" "${TOOL_MCP_MANIFEST_PATH}" "${TOOL_AGENTS_MANIFEST_PATH}" "plugin")"
  capability_counts="skill $(manifest_item_count "${TOOL_SKILLS_MANIFEST_PATH}") / plugin $(manifest_item_count "${TOOL_PLUGINS_MANIFEST_PATH}") / hook $(manifest_item_count "${TOOL_HOOKS_MANIFEST_PATH}") / mcp $(manifest_item_count "${TOOL_MCP_MANIFEST_PATH}") / agent $(manifest_item_count "${TOOL_AGENTS_MANIFEST_PATH}")"
  readonly_manifest_scope_end

  case "${runtime_state}" in
    未安装)
      not_ready_reason="$(append_reason_text "${not_ready_reason}" "未检测到 opencode 命令")"
      ;;
    未配置)
      not_ready_reason="$(append_reason_text "${not_ready_reason}" "缺少 opencode.json")"
      ;;
    需人工登录或授权)
      not_ready_reason="$(append_reason_text "${not_ready_reason}" "当前鉴权信息未配置")"
      ;;
  esac

  if [[ -n "${CONFIG_FILE}" ]]; then
    [[ "$(setting_compare_state "${current_model}" "${DEFAULT_MODEL}")" == "不一致" ]] && not_ready_reason="$(append_reason_text "${not_ready_reason}" "模型与目标不一致")"
    [[ "$(setting_compare_state "${current_model}" "${DEFAULT_MODEL}")" == "缺失" && "${runtime_state}" != "未安装" ]] && not_ready_reason="$(append_reason_text "${not_ready_reason}" "当前模型未配置")"
    [[ "$(setting_compare_state "${current_provider}" "${PROVIDER_DEFAULT}")" == "不一致" ]] && not_ready_reason="$(append_reason_text "${not_ready_reason}" "provider 与目标不一致")"
    [[ "$(setting_compare_state "${current_provider}" "${PROVIDER_DEFAULT}")" == "缺失" && "${runtime_state}" != "未安装" ]] && not_ready_reason="$(append_reason_text "${not_ready_reason}" "当前 provider 未配置")"
  fi

  [[ "${plugin_configured_count}" != "0" ]] && not_ready_reason="$(append_reason_text "${not_ready_reason}" "插件已写入配置但尚未生效 ${plugin_configured_count} 项")"
  [[ "${plugin_missing_count}" != "0" ]] && not_ready_reason="$(append_reason_text "${not_ready_reason}" "默认 plugin 缺失 ${plugin_missing_count} 项")"

  print_report_line "当前状态" "${runtime_state}"
  print_report_line "建议动作" "$(recommended_service_action "opencode" "${runtime_state}" "${CONFIG_FILE:-}")"
  [[ -n "${not_ready_reason}" ]] && print_report_line "未就绪原因" "${not_ready_reason}"
  print_report_line "最佳实践就绪度" "${readiness_summary}"
  print_report_line "技能目录" "${GLOBAL_SKILLS_DIR} (${skills_exists})"
  print_report_line "插件目录" "${GLOBAL_PLUGINS_DIR} (${plugins_exists})"
  print_report_line "插件状态" "${plugin_summary}"
  print_report_line "工具 env" "${TOOL_ENV_PATH}"
  print_report_line "工具包装命令" "${TOOL_WRAPPER_PATH}"
  print_report_line "工具目录" "${TOOL_RUNTIME_ROOT}"
  print_report_line "备份目录" "${BACKUP_ROOT}"
  print_report_line "能力包策略" "$(pack_strategy_summary "${COMMON_DEFAULT_PACKS}" "${TOOL_DEFAULT_PACKS}" "${ENHANCED_PACKS}" "${ENABLE_ENHANCED_PACKS}" "${EXPERIMENTAL_PACKS}" "${ENABLE_EXPERIMENTAL_PACKS}")"
  print_report_line "核心能力统计" "${capability_stats}"
  print_report_line "能力项统计" "${capability_counts}"
  print_report_line "能力包清单" "${TOOL_PACKS_MANIFEST_PATH} ($(path_state "${TOOL_PACKS_MANIFEST_PATH}"))"
  print_report_line "技能清单" "${TOOL_SKILLS_MANIFEST_PATH} ($(path_state "${TOOL_SKILLS_MANIFEST_PATH}"))"
  print_report_line "插件清单" "${TOOL_PLUGINS_MANIFEST_PATH} ($(path_state "${TOOL_PLUGINS_MANIFEST_PATH}"))"
  print_report_line "插件状态文件" "${TOOL_PLUGIN_STATUS_PATH} ($(path_state "${TOOL_PLUGIN_STATUS_PATH}"))"
  print_report_line "Hook 清单" "${TOOL_HOOKS_MANIFEST_PATH} ($(path_state "${TOOL_HOOKS_MANIFEST_PATH}"))"
  print_report_line "MCP 清单" "${TOOL_MCP_MANIFEST_PATH} ($(path_state "${TOOL_MCP_MANIFEST_PATH}"))"
  print_report_line "Agent 清单" "${TOOL_AGENTS_MANIFEST_PATH} ($(path_state "${TOOL_AGENTS_MANIFEST_PATH}"))"

  if [[ -n "${CONFIG_FILE}" ]]; then
    print_report_line "目标配置文件" "${CONFIG_FILE}"
    print_report_line "目标模型" "${DEFAULT_MODEL}"
    print_report_line "目标 provider" "${PROVIDER_DEFAULT}"
    print_report_line "模型比对" "$(setting_compare_state "${current_model}" "${DEFAULT_MODEL}")"
    print_report_line "Provider 比对" "$(setting_compare_state "${current_provider}" "${PROVIDER_DEFAULT}")"
  fi
}

cmd_service_report() {
  local opencode_path=""
  local install_state="未安装"
  local not_ready_reason=""
  local config_state="missing"
  local current_model="未检测到"
  local current_provider="未检测到"
  local auth_state="未检测到"
  local plugin_configured_count="0"
  local plugin_missing_count="0"
  local plugin_summary="未检测到"
  local readiness_summary="未检测到"
  local capability_stats="未检测到"
  local capability_counts="skill 0 / plugin 0 / hook 0 / mcp 0 / agent 0"

  load_config_if_present
  readonly_manifest_scope_begin TOOL_PLUGIN_STATUS_PATH
  render_runtime_manifests
  opencode_path="$(opencode_binary_path)"
  write_plugin_status_snapshot

  if [[ -n "${opencode_path}" ]]; then
    install_state="已安装"
  fi

  if [[ -f "${GLOBAL_CONFIG_PATH}" ]]; then
    config_state="present"
    current_model="$(extract_json_string_value "model" "${GLOBAL_CONFIG_PATH}")"
    [[ -n "${current_model}" ]] || current_model="未检测到"
    current_provider="$(grep -A3 '"provider"' "${GLOBAL_CONFIG_PATH}" | tail -n +2 | grep -o '"[^"]*"[[:space:]]*:[[:space:]]*{' | head -n 1 | sed 's/^"//; s/"[[:space:]]*:[[:space:]]*{$//' || true)"
    [[ -n "${current_provider}" ]] || current_provider="未检测到"
  fi
  auth_state="$(opencode_auth_state)"

  install_state="$(opencode_runtime_state "${opencode_path}" "$([[ "${config_state}" == "present" ]] && printf yes || printf no)" "${auth_state}")"
  plugin_configured_count="$(plugin_status_count "已配置")"
  plugin_missing_count="$(plugin_status_count "缺失")"
  plugin_summary="$(plugin_status_summary)"
  readiness_summary="$(opencode_best_practice_readiness "${opencode_path}" "$([[ "${config_state}" == "present" ]] && printf yes || printf no)" "${auth_state}")"
  capability_stats="$(capability_stats_summary "${TOOL_SKILLS_MANIFEST_PATH}" "${TOOL_PLUGINS_MANIFEST_PATH}" "${TOOL_HOOKS_MANIFEST_PATH}" "${TOOL_MCP_MANIFEST_PATH}" "${TOOL_AGENTS_MANIFEST_PATH}" "plugin")"
  capability_counts="skill $(manifest_item_count "${TOOL_SKILLS_MANIFEST_PATH}") / plugin $(manifest_item_count "${TOOL_PLUGINS_MANIFEST_PATH}") / hook $(manifest_item_count "${TOOL_HOOKS_MANIFEST_PATH}") / mcp $(manifest_item_count "${TOOL_MCP_MANIFEST_PATH}") / agent $(manifest_item_count "${TOOL_AGENTS_MANIFEST_PATH}")"
  readonly_manifest_scope_end

  case "${install_state}" in
    未安装)
      not_ready_reason="$(append_reason_text "${not_ready_reason}" "未检测到 opencode 命令")"
      ;;
    未配置)
      not_ready_reason="$(append_reason_text "${not_ready_reason}" "缺少 opencode.json")"
      ;;
    需人工登录或授权)
      not_ready_reason="$(append_reason_text "${not_ready_reason}" "当前鉴权信息未配置")"
      ;;
  esac

  if [[ -n "${CONFIG_FILE}" ]]; then
    [[ "$(setting_compare_state "${current_model}" "${DEFAULT_MODEL}")" == "不一致" ]] && not_ready_reason="$(append_reason_text "${not_ready_reason}" "模型与目标不一致")"
    [[ "$(setting_compare_state "${current_model}" "${DEFAULT_MODEL}")" == "缺失" && "${install_state}" != "未安装" ]] && not_ready_reason="$(append_reason_text "${not_ready_reason}" "当前模型未配置")"
    [[ "$(setting_compare_state "${current_provider}" "${PROVIDER_DEFAULT}")" == "不一致" ]] && not_ready_reason="$(append_reason_text "${not_ready_reason}" "provider 与目标不一致")"
    [[ "$(setting_compare_state "${current_provider}" "${PROVIDER_DEFAULT}")" == "缺失" && "${install_state}" != "未安装" ]] && not_ready_reason="$(append_reason_text "${not_ready_reason}" "当前 provider 未配置")"
  fi

  [[ "${plugin_configured_count}" != "0" ]] && not_ready_reason="$(append_reason_text "${not_ready_reason}" "插件已写入配置但尚未生效 ${plugin_configured_count} 项")"
  [[ "${plugin_missing_count}" != "0" ]] && not_ready_reason="$(append_reason_text "${not_ready_reason}" "默认 plugin 缺失 ${plugin_missing_count} 项")"

  print_section "OpenCode 概览"
  print_report_line "安装状态" "${install_state}"
  print_report_line "建议动作" "$(recommended_service_action "opencode" "${install_state}" "${CONFIG_FILE:-}")"
  [[ -n "${not_ready_reason}" ]] && print_report_line "未就绪原因" "${not_ready_reason}"
  print_report_line "OpenCode 命令" "${opencode_path:-未安装}"
  print_report_line "当前模型" "${current_model}"
  print_report_line "当前 provider" "${current_provider}"
  print_report_line "当前鉴权" "${auth_state}"
  print_report_line "opencode.json" "${GLOBAL_CONFIG_PATH} (${config_state})"
  print_report_line "工具目录" "${TOOL_RUNTIME_ROOT}"
  print_report_line "最佳实践就绪度" "${readiness_summary}"
  print_report_line "能力包策略" "$(pack_strategy_summary "${COMMON_DEFAULT_PACKS}" "${TOOL_DEFAULT_PACKS}" "${ENHANCED_PACKS}" "${ENABLE_ENHANCED_PACKS}" "${EXPERIMENTAL_PACKS}" "${ENABLE_EXPERIMENTAL_PACKS}")"
  print_report_line "插件状态" "${plugin_summary}"
  print_report_line "核心能力统计" "${capability_stats}"
  print_report_line "能力项统计" "${capability_counts}"
  print_report_line "能力包清单" "${TOOL_PACKS_MANIFEST_PATH} ($(path_state "${TOOL_PACKS_MANIFEST_PATH}"))"
  print_report_line "插件状态文件" "${TOOL_PLUGIN_STATUS_PATH} ($(path_state "${TOOL_PLUGIN_STATUS_PATH}"))"
  print_report_line "Agent 清单" "${TOOL_AGENTS_MANIFEST_PATH} ($(path_state "${TOOL_AGENTS_MANIFEST_PATH}"))"

  if [[ -n "${CONFIG_FILE}" ]]; then
    print_report_line "目标模型" "${DEFAULT_MODEL}"
    print_report_line "目标 provider" "${PROVIDER_DEFAULT}"
    print_report_line "模型比对" "$(setting_compare_state "${current_model}" "${DEFAULT_MODEL}")"
    print_report_line "Provider 比对" "$(setting_compare_state "${current_provider}" "${PROVIDER_DEFAULT}")"
  fi
}

cmd_config_show() {
  local section="${TARGET_SECTION:-summary}"

  require_config

  print_section "OpenCode 配置"

  case "${section}" in
    summary)
      print_report_line "目标配置文件" "${CONFIG_FILE}"
      print_report_line "安装方式" "${INSTALL_METHOD}"
      print_report_line "模型" "${DEFAULT_MODEL}"
      print_report_line "默认 provider" "${PROVIDER_DEFAULT}"
      print_report_line "Ollama Base URL" "${OLLAMA_BASE_URL}"
      ;;
    paths)
      print_report_line "全局目录" "${GLOBAL_OPENCODE_DIR}"
      print_report_line "opencode.json" "${GLOBAL_CONFIG_PATH}"
      print_report_line "全局 AGENTS" "${GLOBAL_AGENTS_PATH}"
      print_report_line "Agents 目录" "${GLOBAL_AGENTS_DIR}"
      print_report_line "插件目录" "${GLOBAL_PLUGINS_DIR}"
      print_report_line "插件缓存目录" "${GLOBAL_PLUGIN_CACHE_DIR}"
      print_report_line "共享 skills" "${GLOBAL_SKILLS_DIR}"
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
      render_global_config
      render_global_agents_if_missing
      render_runtime_env_file
      render_wrapper_script
      render_runtime_manifests
      render_support_notes_if_missing
      write_plugin_status_snapshot
      log_info "已初始化 OpenCode 工具目录：${TOOL_RUNTIME_ROOT}"
      log_info "已生成工具目录 opencode.json：${TOOL_GLOBAL_CONFIG_PATH}"
      log_info "已准备工具目录 AGENTS.md 模板：${TOOL_GLOBAL_AGENTS_PATH}"
      log_info "已生成工具目录 provider.env：${TOOL_ENV_PATH}"
      log_info "已生成工具目录包装命令：${TOOL_WRAPPER_PATH}"
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
      log_info "已生成：${TARGET_PATH}/AGENTS.md"
      log_info "已生成：${TARGET_PATH}/.agents/project-context.md"
      log_info "已生成：${TARGET_PATH}/.agents/architecture.md"
      log_info "已生成：${TARGET_PATH}/.agents/workflow.md"
      log_info "已生成：${TARGET_PATH}/.agents/checklist.md"
      log_info "已生成：${TARGET_PATH}/opencode.json"
      log_info "已生成：${TARGET_PATH}/.opencode/skills/"
      log_info "已生成：${TARGET_PATH}/.opencode/plugins/"
      log_info "已生成：${TARGET_PATH}/.opencode/agents/"
      ;;
    *)
      die "仅支持 --scope global 或 --scope project，收到：${TARGET_SCOPE:-<空>}"
      ;;
  esac
}

cmd_service_configure() {
  require_config
  if ! confirm_action "将按配置重写全局 OpenCode opencode.json，是否继续？" "${ASSUME_YES}"; then
    log_warn "已取消执行。"
    exit 0
  fi
  sync_global_config
}

cmd_extension_commands_not_exposed() {
  die "OpenCode 当前不单独提供 ${COMMAND_GROUP} ${COMMAND_ACTION} 命令，请使用 service install 或 config init 自动准备相关目录与运行清单。"
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
