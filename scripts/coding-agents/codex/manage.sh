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
  help_print_title "Codex"
  help_print_strong_rule
  help_print_context "最短入口" "manage.sh guide start --tool-name codex"
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
  help_print_step "1" "manage.sh guide start --tool-name codex"
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
  help_print_entry "project trust" "可信项目"
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

toml_escape() {
  printf '%s' "${1}" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

bool_to_toml() {
  case "${1:-0}" in
    1|true|TRUE|yes|YES|on|ON)
      printf 'true'
      ;;
    *)
      printf 'false'
      ;;
  esac
}

split_csv_lines() {
  local input="${1:-}"
  [[ -n "${input}" ]] || return 0
  printf '%s' "${input}" | tr ',' '\n' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' | sed '/^$/d'
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
  local normalized="${1:-}"
  normalized="${normalized#github:}"

  case "${normalized}" in
    */*)
      if [[ "${normalized}" == *" "* || "${normalized}" == *"://"* ]]; then
        return 1
      fi
      return 0
      ;;
  esac
  return 1
}

resolve_local_skill_spec_path() {
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

normalize_config() {
  INSTALL_METHOD="${INSTALL_METHOD:-npm}"
  CODEX_PACKAGE="${CODEX_PACKAGE:-@openai/codex@latest}"
  AUTH_METHOD="${AUTH_METHOD:-chatgpt}"
  AUTH_METHOD="${AUTH_METHOD//api-key/apikey}"
  DEFAULT_MODEL="${DEFAULT_MODEL:-gpt-5.4}"
  MODEL_REASONING_EFFORT="${MODEL_REASONING_EFFORT:-xhigh}"
  MODEL_PROVIDER="${MODEL_PROVIDER:-openai}"
  PROVIDER_NAME="${PROVIDER_NAME:-${MODEL_PROVIDER}}"
  PROVIDER_ENV_KEY="${PROVIDER_ENV_KEY:-OPENAI_API_KEY}"
  PROVIDER_API_VALUE="${PROVIDER_API_VALUE:-}"
  PROVIDER_WIRE_API="${PROVIDER_WIRE_API:-responses}"
  API_BASE_URL="${API_BASE_URL:-}"
  DISABLE_RESPONSE_STORAGE="${DISABLE_RESPONSE_STORAGE:-1}"
  SANDBOX_MODE="${SANDBOX_MODE:-workspace-write}"
  APPROVAL_POLICY="${APPROVAL_POLICY:-on-request}"
  ENABLE_DEFAULT_SKILLS="${ENABLE_DEFAULT_SKILLS:-1}"
  ENABLE_DEFAULT_PLUGINS="${ENABLE_DEFAULT_PLUGINS:-1}"
  ENABLE_DEFAULT_HOOKS="${ENABLE_DEFAULT_HOOKS:-1}"
  ENABLE_DEFAULT_MCP="${ENABLE_DEFAULT_MCP:-1}"
  ENABLE_DEFAULT_AGENTS="${ENABLE_DEFAULT_AGENTS:-1}"
  MODE="${MODE:-}"
  COMMON_DEFAULT_PACKS="${COMMON_DEFAULT_PACKS:-common-core,common-docs-architecture,common-quality,common-backend,common-frontend}"
  TOOL_DEFAULT_PACKS="${TOOL_DEFAULT_PACKS:-codex-core,codex-review}"
  ENHANCED_PACKS="${ENHANCED_PACKS:-codex-ecosystem,codex-frontend,codex-research,enhanced-browser-deep,enhanced-long-memory,enhanced-observability}"
  ENABLE_ENHANCED_PACKS="${ENABLE_ENHANCED_PACKS:-0}"
  EXPERIMENTAL_PACKS="${EXPERIMENTAL_PACKS:-experimental-bleeding-edge}"
  ENABLE_EXPERIMENTAL_PACKS="${ENABLE_EXPERIMENTAL_PACKS:-0}"
  SKILL_SPECS="${SKILL_SPECS:-}"
  PLUGIN_SPECS="${PLUGIN_SPECS:-}"
  HOOK_SPECS="${HOOK_SPECS:-}"
  MCP_SPECS="${MCP_SPECS:-}"
  AGENT_SPECS="${AGENT_SPECS:-}"
  TRUST_PATHS="${TRUST_PATHS:-}"
  normalize_mode_profile

  GLOBAL_CODEX_DIR="${GLOBAL_CODEX_DIR:-/root/.codex}"
  GLOBAL_AGENTS_DIR="${GLOBAL_AGENTS_DIR:-/root/.agents}"
  GLOBAL_CONFIG_PATH="${GLOBAL_CONFIG_PATH:-${GLOBAL_CODEX_DIR}/config.toml}"
  GLOBAL_HOOKS_PATH="${GLOBAL_HOOKS_PATH:-${GLOBAL_CODEX_DIR}/hooks.json}"
  GLOBAL_AGENTS_DOC_PATH="${GLOBAL_AGENTS_DOC_PATH:-${GLOBAL_CODEX_DIR}/AGENTS.md}"
  GLOBAL_USER_SKILLS_DIR="${GLOBAL_USER_SKILLS_DIR:-${GLOBAL_AGENTS_DIR}/skills}"
  GLOBAL_CODEX_AGENTS_DIR="${GLOBAL_CODEX_AGENTS_DIR:-${GLOBAL_CODEX_DIR}/agents}"
  GLOBAL_SKILLS_NOTE_PATH="${GLOBAL_USER_SKILLS_DIR}/README.managed.md"
  GLOBAL_AGENTS_NOTE_PATH="${GLOBAL_CODEX_AGENTS_DIR}/README.managed.md"

  TOOL_RUNTIME_ROOT="${TOOL_RUNTIME_ROOT:-${SCRIPT_DIR}}"
  BACKUP_ROOT="${BACKUP_ROOT:-${TOOL_RUNTIME_ROOT}/backups}"
  TOOL_BIN_DIR="${TOOL_RUNTIME_ROOT}/bin"
  TOOL_CONFIG_DIR="${TOOL_RUNTIME_ROOT}/config"
  TOOL_GLOBAL_DIR="${TOOL_CONFIG_DIR}/global"
  TOOL_MANIFESTS_DIR="${TOOL_RUNTIME_ROOT}/manifests"
  TOOL_GLOBAL_CONFIG_PATH="${TOOL_GLOBAL_DIR}/config.toml"
  TOOL_GLOBAL_AGENTS_PATH="${TOOL_GLOBAL_DIR}/AGENTS.md"
  TOOL_GLOBAL_HOOKS_PATH="${TOOL_GLOBAL_DIR}/hooks.json"
  TOOL_ENV_PATH="${TOOL_GLOBAL_DIR}/provider.env"
  TOOL_WRAPPER_PATH="${TOOL_BIN_DIR}/codex-managed"
  TOOL_TRUSTED_PROJECTS_PATH="${TOOL_MANIFESTS_DIR}/trusted-projects.list"
  TOOL_PACKS_MANIFEST_PATH="${TOOL_MANIFESTS_DIR}/packs.manifest"
  TOOL_SKILLS_MANIFEST_PATH="${TOOL_MANIFESTS_DIR}/skills.manifest"
  TOOL_SKILL_STATUS_PATH="${TOOL_MANIFESTS_DIR}/skills.status"
  TOOL_PLUGINS_MANIFEST_PATH="${TOOL_MANIFESTS_DIR}/plugins.manifest"
  TOOL_HOOKS_MANIFEST_PATH="${TOOL_MANIFESTS_DIR}/hooks.manifest"
  TOOL_MCP_MANIFEST_PATH="${TOOL_MANIFESTS_DIR}/mcp.manifest"
  TOOL_AGENTS_MANIFEST_PATH="${TOOL_MANIFESTS_DIR}/agents.manifest"
}

refresh_skill_plan() {
  if [[ "${ENABLE_DEFAULT_SKILLS}" == "1" ]]; then
    RESOLVED_SKILL_SPECS="$(resolve_installable_capability_items_csv "codex" "skill" "skill-installer" "${COMMON_DEFAULT_PACKS}" "${TOOL_DEFAULT_PACKS}" "${ENHANCED_PACKS}" "${ENABLE_ENHANCED_PACKS}" "${EXPERIMENTAL_PACKS}" "${ENABLE_EXPERIMENTAL_PACKS}" "${SKILL_SPECS}")"
  else
    RESOLVED_SKILL_SPECS="${SKILL_SPECS}"
  fi
}

require_config() {
  [[ -n "${CONFIG_FILE}" ]] || die "必须提供 --config"
  [[ -f "${CONFIG_FILE}" ]] || die "配置文件不存在：${CONFIG_FILE}"
  load_key_value_config "${CONFIG_FILE}" || die "配置文件解析失败：${CONFIG_FILE}"
  normalize_config
  refresh_skill_plan
}

load_config_if_present() {
  if [[ -n "${CONFIG_FILE}" ]]; then
    require_config
  else
    normalize_config
    refresh_skill_plan
  fi
}

ensure_runtime_layout() {
  mkdir -p \
    "${TOOL_RUNTIME_ROOT}" \
    "${TOOL_BIN_DIR}" \
    "${TOOL_GLOBAL_DIR}" \
    "${TOOL_MANIFESTS_DIR}" \
    "${BACKUP_ROOT}" \
    "${GLOBAL_CODEX_DIR}" \
    "${GLOBAL_AGENTS_DIR}" \
    "${GLOBAL_USER_SKILLS_DIR}" \
    "${GLOBAL_CODEX_AGENTS_DIR}"
}

ensure_runtime_workspace() {
  mkdir -p \
    "${TOOL_RUNTIME_ROOT}" \
    "${TOOL_BIN_DIR}" \
    "${TOOL_GLOBAL_DIR}" \
    "${TOOL_MANIFESTS_DIR}" \
    "${BACKUP_ROOT}"
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

codex_binary_path() {
  command -v codex 2>/dev/null || true
}

codex_version_value() {
  if command -v codex >/dev/null 2>&1; then
    codex --version 2>&1 | tail -n 1
  else
    printf '未安装'
  fi
}

codex_official_skill_repo_path() {
  case "${1:-}" in
    gh-fix-ci|gh-address-comments|security-best-practices|doc|security-threat-model|frontend-skill|figma|figma-use|figma-implement-design|notion-spec-to-implementation|notion-research-documentation)
      printf 'skills/.curated/%s' "${1}"
      return 0
      ;;
  esac
  return 1
}

codex_skill_name_from_spec() {
  local spec="${1:-}"
  local repo_spec=""
  local path_part=""
  local name=""
  local parsed=""

  if path_like_spec "${spec}"; then
    printf '%s' "$(basename "$(resolve_local_skill_spec_path "${spec}")")"
    return 0
  fi

  if codex_official_skill_repo_path "${spec}" >/dev/null 2>&1; then
    printf '%s' "${spec}"
    return 0
  fi

  if url_like_spec "${spec}"; then
    if parsed="$(printf '%s' "${spec}" | sed -n 's#^https://github\.com/\([^/]\+/\([^/]\+\)\)/tree/\([^/]\+\)/\(.*\)$#\1|\3|\4#p')"; then
      :
    fi
    if [[ -n "${parsed}" ]]; then
      IFS='|' read -r repo_spec _ path_part <<< "${parsed}"
      [[ -n "${path_part}" ]] || path_part="${repo_spec##*/}"
      printf '%s' "$(basename "${path_part}")"
      return 0
    fi
    name="${spec%%\?*}"
    name="${name%/}"
    name="${name##*/}"
    name="${name%.git}"
    printf '%s' "${name}"
    return 0
  fi

  if github_repo_like_spec "${spec}"; then
    repo_spec="${spec}"
    path_part=""
    if [[ "${repo_spec}" == *":"* ]]; then
      path_part="${repo_spec#*:}"
      repo_spec="${repo_spec%%:*}"
    fi
    if [[ -n "${path_part}" ]]; then
      printf '%s' "$(basename "${path_part}")"
    else
      printf '%s' "${repo_spec##*/}"
    fi
    return 0
  fi

  printf '%s' "${spec}"
}

codex_skill_target_dir_from_spec() {
  local spec="${1:-}"
  printf '%s/%s' "${GLOBAL_USER_SKILLS_DIR}" "$(codex_skill_name_from_spec "${spec}")"
}

codex_skill_source_hint_from_spec() {
  local spec="${1:-}"
  local official_path=""

  if path_like_spec "${spec}"; then
    printf '%s' "$(resolve_local_skill_spec_path "${spec}")"
    return 0
  fi

  if official_path="$(codex_official_skill_repo_path "${spec}" 2>/dev/null)"; then
    printf 'openai/skills:%s' "${official_path}"
    return 0
  fi

  if url_like_spec "${spec}" || github_repo_like_spec "${spec}"; then
    printf '%s' "${spec}"
    return 0
  fi

  return 1
}

parse_github_skill_spec() {
  local spec="${1:-}"
  local repo=""
  local ref="main"
  local path_part=""
  local normalized="${spec#github:}"

  if url_like_spec "${spec}"; then
    if [[ "${spec}" =~ ^https://github\.com/([^/]+/[^/]+)/tree/([^/]+)/(.*)$ ]]; then
      repo="${BASH_REMATCH[1]}"
      ref="${BASH_REMATCH[2]}"
      path_part="${BASH_REMATCH[3]}"
      printf '%s|%s|%s\n' "${repo}" "${ref}" "${path_part}"
      return 0
    fi
    if [[ "${spec}" =~ ^https://github\.com/([^/]+/[^/]+)(\.git)?/?$ ]]; then
      repo="${BASH_REMATCH[1]}"
      printf '%s|%s|%s\n' "${repo}" "${ref}" "${path_part}"
      return 0
    fi
    return 1
  fi

  if github_repo_like_spec "${spec}"; then
    repo="${normalized}"
    if [[ "${repo}" == *":"* ]]; then
      path_part="${repo#*:}"
      repo="${repo%%:*}"
    fi
    printf '%s|%s|%s\n' "${repo}" "${ref}" "${path_part}"
    return 0
  fi

  return 1
}

copy_skill_directory() {
  local source_dir="$1"
  local target_dir="$2"

  [[ -d "${source_dir}" ]] || return 1
  [[ -f "${source_dir}/SKILL.md" ]] || return 1

  mkdir -p "${target_dir}"
  cp -a "${source_dir}/." "${target_dir}/"
  rm -rf "${target_dir}/.git" "${target_dir}/.github"
}

find_single_skill_directory() {
  local search_root="$1"
  local -a matches=()

  if [[ -f "${search_root}/SKILL.md" ]]; then
    printf '%s' "${search_root}"
    return 0
  fi

  mapfile -t matches < <(find "${search_root}" \
    -path '*/.git' -prune -o \
    -type f -name 'SKILL.md' -print | sed 's#/SKILL.md$##')

  if [[ "${#matches[@]}" -eq 1 ]]; then
    printf '%s' "${matches[0]}"
    return 0
  fi

  return 1
}

install_skill_from_github() {
  local spec="$1"
  local target_dir="$2"
  local parsed=""
  local repo=""
  local ref=""
  local repo_path=""
  local remote_url=""
  local temp_dir=""
  local source_dir=""
  local detected_dir=""

  parsed="$(parse_github_skill_spec "${spec}")" || return 1
  IFS='|' read -r repo ref repo_path <<< "${parsed}"
  remote_url="https://github.com/${repo}.git"
  temp_dir="$(mktemp -d)"
  trap 'rm -rf "${temp_dir}"' RETURN

  if [[ -n "${repo_path}" ]]; then
    git clone --depth 1 --filter=blob:none --sparse --branch "${ref}" "${remote_url}" "${temp_dir}" >/dev/null 2>&1 || return 1
    (
      cd "${temp_dir}" &&
      git sparse-checkout set "${repo_path}"
    ) >/dev/null 2>&1 || return 1
    source_dir="${temp_dir}/${repo_path}"
  else
    git clone --depth 1 --branch "${ref}" "${remote_url}" "${temp_dir}" >/dev/null 2>&1 || return 1
    source_dir="${temp_dir}"
  fi

  detected_dir="$(find_single_skill_directory "${source_dir}" || true)"
  [[ -n "${detected_dir}" ]] || return 1
  copy_skill_directory "${detected_dir}" "${target_dir}"
}

install_skill_from_spec() {
  local spec="$1"
  local target_dir="$2"
  local source_dir=""
  local official_path=""
  local detected_dir=""

  if path_like_spec "${spec}"; then
    source_dir="$(resolve_local_skill_spec_path "${spec}")"
    detected_dir="$(find_single_skill_directory "${source_dir}" || true)"
    [[ -n "${detected_dir}" ]] || return 1
    copy_skill_directory "${detected_dir}" "${target_dir}"
    return $?
  fi

  if official_path="$(codex_official_skill_repo_path "${spec}" 2>/dev/null)"; then
    install_skill_from_github "github:openai/skills:${official_path}" "${target_dir}"
    return $?
  fi

  if url_like_spec "${spec}" || github_repo_like_spec "${spec}"; then
    install_skill_from_github "${spec}" "${target_dir}"
    return $?
  fi

  return 1
}

write_skill_status_snapshot() {
  local spec=""
  local name=""
  local source=""
  local target_dir=""
  local status=""
  local detail=""
  local -a skill_specs=()

  mkdir -p "$(dirname "${TOOL_SKILL_STATUS_PATH}")"

  {
    printf '# Codex skill 状态\n'
    printf 'name|status|source|detail\n'
  } > "${TOOL_SKILL_STATUS_PATH}"

  mapfile -t skill_specs < <(csv_clean_lines "${RESOLVED_SKILL_SPECS}")
  for spec in "${skill_specs[@]}"; do
    [[ -n "${spec}" ]] || continue
    name="$(codex_skill_name_from_spec "${spec}")"
    source="$(codex_skill_source_hint_from_spec "${spec}" || true)"
    [[ -n "${source}" ]] || continue
    target_dir="$(codex_skill_target_dir_from_spec "${spec}")"

    if [[ -f "${target_dir}/SKILL.md" ]]; then
      status="已安装"
      detail="${target_dir}"
    elif [[ -d "${target_dir}" ]]; then
      status="未生效"
      detail="目录存在，但缺少 SKILL.md"
    elif [[ -n "${source}" ]]; then
      status="缺失"
      detail="${source}"
    else
      status="需人工处理"
      detail="未识别来源，请使用官方 skill 名、本地路径或 GitHub 路径"
    fi

    printf '%s|%s|%s|%s\n' "${name}" "${status}" "${source:-<空>}" "${detail}" >> "${TOOL_SKILL_STATUS_PATH}"
  done
}

skill_status_count() {
  local target_status="${1:-}"

  [[ -f "${TOOL_SKILL_STATUS_PATH}" ]] || {
    printf '0'
    return 0
  }

  awk -F'|' -v target="${target_status}" 'NR > 2 && $2 == target { count++ } END { print count + 0 }' "${TOOL_SKILL_STATUS_PATH}"
}

skill_status_summary() {
  printf '已安装 %s / 缺失 %s / 未生效 %s / 需人工处理 %s' \
    "$(skill_status_count "已安装")" \
    "$(skill_status_count "缺失")" \
    "$(skill_status_count "未生效")" \
    "$(skill_status_count "需人工处理")"
}

sync_skills() {
  local mode="${1:-安装}"
  local spec=""
  local source=""
  local target_dir=""
  local target_name=""
  local -a skill_specs=()

  ensure_runtime_layout

  if [[ -z "${RESOLVED_SKILL_SPECS}" ]]; then
    write_skill_status_snapshot
    return 0
  fi

  ensure_command git

  mapfile -t skill_specs < <(csv_clean_lines "${RESOLVED_SKILL_SPECS}")
  for spec in "${skill_specs[@]}"; do
    [[ -n "${spec}" ]] || continue
    source="$(codex_skill_source_hint_from_spec "${spec}" || true)"
    [[ -n "${source}" ]] || continue
    target_dir="$(codex_skill_target_dir_from_spec "${spec}")"
    target_name="$(basename "${target_dir}")"

    if [[ -f "${target_dir}/SKILL.md" ]]; then
      if [[ "${mode}" == "更新" ]]; then
        backup_path_if_exists "${target_dir}" "Codex skill ${target_name}"
        rm -rf "${target_dir}"
        if install_skill_from_spec "${spec}" "${target_dir}"; then
          log_info "已更新 skill：${target_name}"
        else
          log_warn "更新 skill 失败，保留为空目录前已自动清理：${spec}"
          rm -rf "${target_dir}"
        fi
      else
        log_info "skill 已存在，跳过：${target_name}"
      fi
      continue
    fi

    if install_skill_from_spec "${spec}" "${target_dir}"; then
      log_info "已安装 skill：${target_name}"
    else
      log_warn "安装 skill 失败：${spec}"
      rm -rf "${target_dir}"
    fi
  done

  write_skill_status_snapshot
}

codex_auth_mode_value() {
  if [[ -f "${GLOBAL_CONFIG_PATH}" ]]; then
    awk -F'=' '/^preferred_auth_method[[:space:]]*=/{gsub(/[ "]/,"",$2); print $2; exit}' "${GLOBAL_CONFIG_PATH}"
    return 0
  fi
  printf '未检测到'
}

codex_current_env_key_value() {
  local provider="${1:-}"

  [[ -f "${GLOBAL_CONFIG_PATH}" ]] || {
    printf '%s' "${PROVIDER_ENV_KEY:-OPENAI_API_KEY}"
    return 0
  }

  if [[ -n "${provider}" ]]; then
    awk -F'=' -v provider="${provider}" '
      $0 ~ "^\\[model_providers\\." provider "\\]$" { in_section=1; next }
      /^\[/ { in_section=0 }
      in_section && /^env_key[[:space:]]*=/ {
        gsub(/[ "]/, "", $2)
        print $2
        exit
      }
    ' "${GLOBAL_CONFIG_PATH}"
    return 0
  fi

  printf '%s' "${PROVIDER_ENV_KEY:-OPENAI_API_KEY}"
}

codex_auth_state() {
  local auth_mode="${1:-未检测到}"
  local env_key="${2:-${PROVIDER_ENV_KEY:-OPENAI_API_KEY}}"

  case "${auth_mode}" in
    apikey)
      if [[ -n "${PROVIDER_API_VALUE:-}" ]] || printenv "${env_key}" >/dev/null 2>&1 || [[ -f "${TOOL_ENV_PATH}" && "$(grep -c "^export ${env_key}=" "${TOOL_ENV_PATH}" 2>/dev/null)" != "0" ]]; then
        printf '已配置'
      else
        printf '未配置'
      fi
      ;;
    chatgpt)
      printf '需登录'
      ;;
    *)
      printf '未检测到'
      ;;
  esac
}

codex_runtime_state() {
  local codex_path="${1:-}"
  local config_exists="${2:-no}"
  local auth_state="${3:-未检测到}"

  if [[ -z "${codex_path}" ]]; then
    printf '未安装'
  elif [[ "${config_exists}" != "yes" ]]; then
    printf '未配置'
  elif [[ "${auth_state}" == "未配置" || "${auth_state}" == "需登录" ]]; then
    printf '需人工登录或授权'
  elif [[ "$(skill_status_count "需人工处理")" != "0" ]]; then
    printf '需人工处理'
  elif [[ "$(skill_status_count "缺失")" != "0" || "$(skill_status_count "未生效")" != "0" ]]; then
    printf '未生效'
  else
    printf '已安装'
  fi
}

codex_best_practice_readiness() {
  local codex_path="${1:-}"
  local config_exists="${2:-no}"
  local auth_state="${3:-未检测到}"

  if [[ -z "${codex_path}" ]]; then
    printf '未安装'
  elif [[ "${config_exists}" != "yes" ]]; then
    printf '未配置'
  elif [[ "${auth_state}" == "未配置" || "${auth_state}" == "需登录" ]]; then
    printf '待授权'
  elif [[ ! -f "${TOOL_PACKS_MANIFEST_PATH}" || ! -f "${TOOL_SKILLS_MANIFEST_PATH}" || ! -f "${TOOL_SKILL_STATUS_PATH}" ]]; then
    printf '工具清单缺失'
  elif [[ "$(skill_status_count "需人工处理")" != "0" ]]; then
    printf '需人工处理'
  elif [[ "$(skill_status_count "缺失")" != "0" || "$(skill_status_count "未生效")" != "0" ]]; then
    printf '推荐基线待补齐'
  elif [[ "${ENABLE_ENHANCED_PACKS}" == "1" || "${ENABLE_EXPERIMENTAL_PACKS}" == "1" ]]; then
    printf '增强基线已启用'
  else
    printf '推荐基线已就绪'
  fi
}

render_global_config() {
  local escaped_model=""
  local escaped_effort=""
  local escaped_auth=""
  local escaped_sandbox=""
  local escaped_approval=""
  local escaped_provider=""
  local rendered=""
  local trust_paths=()
  local persisted_paths=()
  local path=""

  escaped_model="$(toml_escape "${DEFAULT_MODEL}")"
  escaped_effort="$(toml_escape "${MODEL_REASONING_EFFORT}")"
  escaped_auth="$(toml_escape "${AUTH_METHOD}")"
  escaped_sandbox="$(toml_escape "${SANDBOX_MODE}")"
  escaped_approval="$(toml_escape "${APPROVAL_POLICY}")"
  escaped_provider="$(toml_escape "${MODEL_PROVIDER}")"

  cat > "${TOOL_GLOBAL_CONFIG_PATH}" <<EOF
model = "${escaped_model}"
model_reasoning_effort = "${escaped_effort}"
preferred_auth_method = "${escaped_auth}"
approval_policy = "${escaped_approval}"
sandbox_mode = "${escaped_sandbox}"
disable_response_storage = $(bool_to_toml "${DISABLE_RESPONSE_STORAGE}")
model_provider = "${escaped_provider}"
EOF

  if [[ -n "${API_BASE_URL}" || -n "${PROVIDER_ENV_KEY}" || "${MODEL_PROVIDER}" != "openai" ]]; then
    rendered="$(toml_escape "${MODEL_PROVIDER}")"
    {
      printf '\n[model_providers.%s]\n' "${rendered}"
      printf 'name = "%s"\n' "$(toml_escape "${PROVIDER_NAME}")"
      if [[ -n "${API_BASE_URL}" ]]; then
        printf 'base_url = "%s"\n' "$(toml_escape "${API_BASE_URL}")"
      fi
      if [[ -n "${PROVIDER_WIRE_API}" ]]; then
        printf 'wire_api = "%s"\n' "$(toml_escape "${PROVIDER_WIRE_API}")"
      fi
      if [[ -n "${PROVIDER_ENV_KEY}" ]]; then
        printf 'env_key = "%s"\n' "$(toml_escape "${PROVIDER_ENV_KEY}")"
      fi
    } >> "${TOOL_GLOBAL_CONFIG_PATH}"
  fi

  if [[ -n "${TRUST_PATHS}" ]]; then
    IFS=',' read -r -a trust_paths <<< "${TRUST_PATHS}"
  fi

  for path in "${trust_paths[@]}"; do
    path="$(printf '%s' "${path}" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
    [[ -n "${path}" ]] || continue
    {
      printf '\n[projects."%s"]\n' "$(toml_escape "${path}")"
      printf 'trust_level = "trusted"\n'
    } >> "${TOOL_GLOBAL_CONFIG_PATH}"
  done

  if [[ -f "${TOOL_TRUSTED_PROJECTS_PATH}" ]]; then
    while IFS= read -r path; do
      path="$(printf '%s' "${path}" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
      [[ -n "${path}" ]] || continue
      if grep -Fqx "[projects.\"${path}\"]" "${TOOL_GLOBAL_CONFIG_PATH}"; then
        continue
      fi
      {
        printf '\n[projects."%s"]\n' "$(toml_escape "${path}")"
        printf 'trust_level = "trusted"\n'
      } >> "${TOOL_GLOBAL_CONFIG_PATH}"
    done < "${TOOL_TRUSTED_PROJECTS_PATH}"
  fi
}

render_global_agents_template_if_missing() {
  if [[ -f "${TOOL_GLOBAL_AGENTS_PATH}" ]]; then
    return 0
  fi

  cat > "${TOOL_GLOBAL_AGENTS_PATH}" <<'EOF'
# Codex 全局工作习惯

## 偏好
- 回复使用中文
- 先给结论，再补原因
- 不改无关代码

## 常用约束
- 优先用 `rg` 搜索
- 变更前先理解目录结构和已有实现
- 高风险操作前要明确提示
EOF
}

render_global_hooks_template() {
  cat > "${TOOL_GLOBAL_HOOKS_PATH}" <<'EOF'
{
  "hooks": {}
}
EOF
}

render_runtime_manifests() {
  write_pack_manifest "${TOOL_PACKS_MANIFEST_PATH}" "codex" "${COMMON_DEFAULT_PACKS}" "${TOOL_DEFAULT_PACKS}" "${ENHANCED_PACKS}" "${ENABLE_ENHANCED_PACKS}" "${EXPERIMENTAL_PACKS}" "${ENABLE_EXPERIMENTAL_PACKS}"
  write_capability_manifest "${TOOL_SKILLS_MANIFEST_PATH}" "Codex skill 初始化清单" "${ENABLE_DEFAULT_SKILLS}" "${SKILL_SPECS}" "默认仅初始化 ~/.agents/skills 目录结构" "codex" "skill" "${COMMON_DEFAULT_PACKS}" "${TOOL_DEFAULT_PACKS}" "${ENHANCED_PACKS}" "${ENABLE_ENHANCED_PACKS}" "${EXPERIMENTAL_PACKS}" "${ENABLE_EXPERIMENTAL_PACKS}"
  write_capability_manifest "${TOOL_PLUGINS_MANIFEST_PATH}" "Codex plugin 初始化清单" "${ENABLE_DEFAULT_PLUGINS}" "${PLUGIN_SPECS}" "Codex 当前主要通过 AGENTS / skills / hooks 扩展" "codex" "plugin" "${COMMON_DEFAULT_PACKS}" "${TOOL_DEFAULT_PACKS}" "${ENHANCED_PACKS}" "${ENABLE_ENHANCED_PACKS}" "${EXPERIMENTAL_PACKS}" "${ENABLE_EXPERIMENTAL_PACKS}"
  write_capability_manifest "${TOOL_HOOKS_MANIFEST_PATH}" "Codex hook 初始化清单" "${ENABLE_DEFAULT_HOOKS}" "${HOOK_SPECS}" "默认初始化 hooks.json 骨架" "codex" "hook" "${COMMON_DEFAULT_PACKS}" "${TOOL_DEFAULT_PACKS}" "${ENHANCED_PACKS}" "${ENABLE_ENHANCED_PACKS}" "${EXPERIMENTAL_PACKS}" "${ENABLE_EXPERIMENTAL_PACKS}"
  write_capability_manifest "${TOOL_MCP_MANIFEST_PATH}" "Codex MCP 初始化清单" "${ENABLE_DEFAULT_MCP}" "${MCP_SPECS}" "默认保留为空，按实际服务器再接入" "codex" "mcp" "${COMMON_DEFAULT_PACKS}" "${TOOL_DEFAULT_PACKS}" "${ENHANCED_PACKS}" "${ENABLE_ENHANCED_PACKS}" "${EXPERIMENTAL_PACKS}" "${ENABLE_EXPERIMENTAL_PACKS}"
  write_capability_manifest "${TOOL_AGENTS_MANIFEST_PATH}" "Codex agent 初始化清单" "${ENABLE_DEFAULT_AGENTS}" "${AGENT_SPECS}" "默认初始化 ~/.codex/agents 目录结构" "codex" "agent" "${COMMON_DEFAULT_PACKS}" "${TOOL_DEFAULT_PACKS}" "${ENHANCED_PACKS}" "${ENABLE_ENHANCED_PACKS}" "${EXPERIMENTAL_PACKS}" "${ENABLE_EXPERIMENTAL_PACKS}"
}

render_support_notes_if_missing() {
  if [[ ! -f "${GLOBAL_SKILLS_NOTE_PATH}" ]]; then
    cat > "${GLOBAL_SKILLS_NOTE_PATH}" <<'EOF'
# Codex Skills 目录说明

- 这里放全局共享 skills
- 建议一个 skill 一个目录
- 通用规范、SOP、检查单优先放这里
EOF
  fi

  if [[ ! -f "${GLOBAL_AGENTS_NOTE_PATH}" ]]; then
    cat > "${GLOBAL_AGENTS_NOTE_PATH}" <<'EOF'
# Codex Agents 目录说明

- 这里放 Codex 相关的全局 agents / role 提示词
- 与项目绑定的内容优先写到项目目录，不要都堆到全局
EOF
  fi
}

render_runtime_env_file() {
  : > "${TOOL_ENV_PATH}"
  if [[ -n "${PROVIDER_ENV_KEY}" && -n "${PROVIDER_API_VALUE}" ]]; then
    printf 'export %s=%q\n' "${PROVIDER_ENV_KEY}" "${PROVIDER_API_VALUE}" >> "${TOOL_ENV_PATH}"
  fi
}

render_wrapper_script() {
  cat > "${TOOL_WRAPPER_PATH}" <<EOF
#!/usr/bin/env bash
set -Eeuo pipefail

if [[ -f "${TOOL_ENV_PATH}" ]]; then
  # shellcheck disable=SC1090
  source "${TOOL_ENV_PATH}"
fi

exec codex "\$@"
EOF
  chmod 755 "${TOOL_WRAPPER_PATH}"
}

render_project_template_if_missing() {
  local project_root="$1"
  local project_codex_dir="${project_root}/.codex"
  local project_agents_dir="${project_root}/.agents/skills"
  local project_agents_doc="${project_root}/AGENTS.md"
  local project_config="${project_codex_dir}/config.toml"
  local project_hooks="${project_codex_dir}/hooks.json"
  local project_agents_note="${project_agents_dir}/README.managed.md"
  local project_codex_agents_dir="${project_codex_dir}/agents"
  local project_codex_agents_note="${project_codex_dir}/agents/README.managed.md"

  mkdir -p "${project_codex_dir}" "${project_agents_dir}" "${project_codex_agents_dir}"
  render_shared_project_bundle_if_missing "${project_root}"
  render_shared_role_templates_if_missing "${project_codex_agents_dir}"

  if [[ ! -f "${project_agents_doc}" ]]; then
    cat > "${project_agents_doc}" <<'EOF'
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
- 规划与边界：看 `.agents/project-context.md`
- 架构与依赖：看 `.agents/architecture.md`
- 执行节奏：看 `.agents/workflow.md`
- 测试与发布：看 `.agents/checklist.md`

## Codex 项目要求
- 需要新增技能、角色模板或项目固定流程时，优先写到 `.agents/skills` 或 `.codex/agents`
- 涉及命令权限、sandbox、审批策略时，先核对 `.codex/config.toml`
- 交付前明确写出验证结果、风险和回滚方式
EOF
  fi

  if [[ ! -f "${project_config}" ]]; then
    cat > "${project_config}" <<EOF
approval_policy = "$(toml_escape "${APPROVAL_POLICY}")"
sandbox_mode = "$(toml_escape "${SANDBOX_MODE}")"
EOF
  fi

  if [[ ! -f "${project_hooks}" ]]; then
    cat > "${project_hooks}" <<'EOF'
{
  "hooks": {}
}
EOF
  fi

  if [[ ! -f "${project_agents_note}" ]]; then
    cat > "${project_agents_note}" <<'EOF'
# 项目 Skills 目录

- 放当前项目专用 skills
- 项目规则、交付检查单、常用命令模板优先写这里
- 适合沉淀重复执行的实现步骤、评审检查单、测试脚本说明
EOF
  fi

  if [[ ! -f "${project_codex_agents_note}" ]]; then
    cat > "${project_codex_agents_note}" <<'EOF'
# 项目 Agents 目录

- 放当前项目专用 agents / role 模板
- 与项目无关的公共内容请回收到全局目录
- 建议至少拆分：规划、实现、评审、测试、发布观察
- 默认已生成：`planner.md`、`implementer.md`、`reviewer.md`、`tester.md`
EOF
  fi
}

sync_global_config() {
  local skill_mode="${1:-安装}"

  ensure_runtime_layout
  render_global_config
  render_global_agents_template_if_missing
  render_global_hooks_template
  render_runtime_env_file
  render_wrapper_script
  render_runtime_manifests
  render_support_notes_if_missing

  backup_path_if_exists "${GLOBAL_CONFIG_PATH}" "Codex 全局配置"
  install -m 600 "${TOOL_GLOBAL_CONFIG_PATH}" "${GLOBAL_CONFIG_PATH}"
  log_info "已同步全局配置：${GLOBAL_CONFIG_PATH}"

  if [[ ! -f "${GLOBAL_AGENTS_DOC_PATH}" ]]; then
    install -m 644 "${TOOL_GLOBAL_AGENTS_PATH}" "${GLOBAL_AGENTS_DOC_PATH}"
    log_info "已初始化全局 AGENTS.md：${GLOBAL_AGENTS_DOC_PATH}"
  else
    log_info "保留现有全局 AGENTS.md：${GLOBAL_AGENTS_DOC_PATH}"
  fi

  if [[ ! -f "${GLOBAL_HOOKS_PATH}" ]]; then
    install -m 600 "${TOOL_GLOBAL_HOOKS_PATH}" "${GLOBAL_HOOKS_PATH}"
    log_info "已初始化全局 hooks.json：${GLOBAL_HOOKS_PATH}"
  else
    log_info "保留现有全局 hooks.json：${GLOBAL_HOOKS_PATH}"
  fi

  if [[ -s "${TOOL_ENV_PATH}" ]]; then
    log_info "已生成工具目录 provider 环境文件：${TOOL_ENV_PATH}"
  fi
  sync_skills "${skill_mode}"
  log_info "已生成工具目录包装命令：${TOOL_WRAPPER_PATH}"
  log_info "已生成初始化清单：${TOOL_PACKS_MANIFEST_PATH}、${TOOL_SKILLS_MANIFEST_PATH}、${TOOL_PLUGINS_MANIFEST_PATH}、${TOOL_HOOKS_MANIFEST_PATH}、${TOOL_MCP_MANIFEST_PATH}、${TOOL_AGENTS_MANIFEST_PATH}"
}

upsert_project_trust_in_file() {
  local file_path="$1"
  local project_path="$2"
  local header=""

  mkdir -p "$(dirname "${file_path}")"
  [[ -f "${file_path}" ]] || touch "${file_path}"

  header="[projects.\"${project_path}\"]"

  if grep -Fqx "${header}" "${file_path}"; then
    return 0
  fi

  if [[ -s "${file_path}" ]]; then
    printf '\n' >> "${file_path}"
  fi
  {
    printf '%s\n' "${header}"
    printf 'trust_level = "trusted"\n'
  } >> "${file_path}"
}

print_summary() {
  print_section "Codex 配置摘要"
  log_info "安装方式：${INSTALL_METHOD}"
  log_info "模型：${DEFAULT_MODEL}"
  log_info "推理强度：${MODEL_REASONING_EFFORT}"
  log_info "认证方式：${AUTH_METHOD}"
  log_info "模型提供方：${MODEL_PROVIDER}"
  if [[ -n "${API_BASE_URL}" ]]; then
    log_info "自定义 Base URL：${API_BASE_URL}"
  fi
  log_info "官方配置：${GLOBAL_CONFIG_PATH}"
  log_info "工具目录：${TOOL_RUNTIME_ROOT}"
}

cmd_service_install_like() {
  local mode="$1"
  require_config
  require_root
  ensure_command install
  print_summary

  if ! confirm_action "将${mode} Codex 并同步全局配置，是否继续？" "${ASSUME_YES}"; then
    log_warn "已取消执行。"
    exit 0
  fi

  ensure_node_runtime
  log_info "开始通过 npm 安装 Codex：${CODEX_PACKAGE}"
  case "${INSTALL_METHOD}" in
    npm)
      npm install -g "${CODEX_PACKAGE}"
      ;;
    *)
      die "当前仅实现 INSTALL_METHOD=npm，收到：${INSTALL_METHOD}"
      ;;
  esac

  sync_global_config "${mode}"
  log_info "Codex 当前版本：$(codex_version_value)"
}

cmd_service_uninstall() {
  require_config
  require_root

  if ! confirm_action "将卸载 Codex CLI，但默认保留 ~/.codex 和工具目录下的管理文件，是否继续？" "${ASSUME_YES}"; then
    log_warn "已取消执行。"
    exit 0
  fi

  case "${INSTALL_METHOD}" in
    npm)
      if npm list -g @openai/codex --depth=0 >/dev/null 2>&1; then
        npm uninstall -g @openai/codex
        log_info "已卸载 npm 全局包：@openai/codex"
      else
        log_warn "未发现 npm 全局包 @openai/codex，跳过卸载。"
      fi
      ;;
    *)
      die "当前仅实现 INSTALL_METHOD=npm，收到：${INSTALL_METHOD}"
      ;;
  esac
}

cmd_service_check() {
  local codex_path=""
  local runtime_state=""
  local not_ready_reason=""
  local config_exists="no"
  local agents_doc_exists="no"
  local user_skills_exists="no"
  local hooks_exists="no"
  local current_provider="未检测到"
  local current_model="未检测到"
  local current_auth_mode="未检测到"
  local current_auth_state="未检测到"
  local current_env_key="OPENAI_API_KEY"
  local skill_missing_count="0"
  local skill_inactive_count="0"
  local skill_summary="未检测到"
  local readiness_summary="未检测到"
  local capability_stats="未检测到"
  local capability_counts="skill 0 / plugin 0 / hook 0 / mcp 0 / agent 0"

  load_config_if_present
  readonly_manifest_scope_begin TOOL_SKILL_STATUS_PATH
  render_runtime_manifests
  codex_path="$(codex_binary_path)"

  print_section "Codex 检查"
  print_report_line "Codex 命令" "${codex_path:-未安装}"
  print_report_line "Codex 版本" "$(codex_version_value)"

  if npm list -g @openai/codex --depth=0 >/dev/null 2>&1; then
    print_report_line "npm 全局包" "@openai/codex 已安装"
  else
    print_report_line "npm 全局包" "未检测到"
  fi

  [[ -f "${GLOBAL_CONFIG_PATH}" ]] && config_exists="yes"
  [[ -f "${GLOBAL_AGENTS_DOC_PATH}" ]] && agents_doc_exists="yes"
  [[ -d "${GLOBAL_USER_SKILLS_DIR}" ]] && user_skills_exists="yes"
  [[ -f "${GLOBAL_HOOKS_PATH}" ]] && hooks_exists="yes"

  if [[ -f "${GLOBAL_CONFIG_PATH}" ]]; then
    current_model="$(awk -F'=' '/^model[[:space:]]*=/{gsub(/[ "]/,"",$2); print $2; exit}' "${GLOBAL_CONFIG_PATH}")"
    current_provider="$(awk -F'=' '/^model_provider[[:space:]]*=/{gsub(/[ "]/,"",$2); print $2; exit}' "${GLOBAL_CONFIG_PATH}")"
    current_auth_mode="$(codex_auth_mode_value)"
    current_env_key="$(codex_current_env_key_value "${current_provider}")"
    [[ -n "${current_env_key}" ]] || current_env_key="OPENAI_API_KEY"
  fi

  write_skill_status_snapshot
  current_auth_state="$(codex_auth_state "${current_auth_mode}" "${current_env_key}")"
  runtime_state="$(codex_runtime_state "${codex_path}" "${config_exists}" "${current_auth_state}")"
  skill_missing_count="$(skill_status_count "缺失")"
  skill_inactive_count="$(skill_status_count "未生效")"
  skill_summary="$(skill_status_summary)"
  readiness_summary="$(codex_best_practice_readiness "${codex_path}" "${config_exists}" "${current_auth_state}")"
  capability_stats="$(capability_stats_summary "${TOOL_SKILLS_MANIFEST_PATH}" "${TOOL_PLUGINS_MANIFEST_PATH}" "${TOOL_HOOKS_MANIFEST_PATH}" "${TOOL_MCP_MANIFEST_PATH}" "${TOOL_AGENTS_MANIFEST_PATH}" "plugin")"
  capability_counts="skill $(manifest_item_count "${TOOL_SKILLS_MANIFEST_PATH}") / plugin $(manifest_item_count "${TOOL_PLUGINS_MANIFEST_PATH}") / hook $(manifest_item_count "${TOOL_HOOKS_MANIFEST_PATH}") / mcp $(manifest_item_count "${TOOL_MCP_MANIFEST_PATH}") / agent $(manifest_item_count "${TOOL_AGENTS_MANIFEST_PATH}")"
  readonly_manifest_scope_end

  case "${runtime_state}" in
    未安装)
      not_ready_reason="$(append_reason_text "${not_ready_reason}" "未检测到 codex 命令")"
      ;;
    未配置)
      not_ready_reason="$(append_reason_text "${not_ready_reason}" "缺少全局配置")"
      ;;
    需人工登录或授权)
      if [[ "${current_auth_state}" == "需登录" ]]; then
        not_ready_reason="$(append_reason_text "${not_ready_reason}" "当前认证方式需要登录")"
      else
        not_ready_reason="$(append_reason_text "${not_ready_reason}" "当前 API Key 未配置")"
      fi
      ;;
  esac

  if [[ -n "${CONFIG_FILE}" ]]; then
    [[ "$(setting_compare_state "${current_model}" "${DEFAULT_MODEL}")" == "不一致" ]] && not_ready_reason="$(append_reason_text "${not_ready_reason}" "模型与目标不一致")"
    [[ "$(setting_compare_state "${current_provider}" "${MODEL_PROVIDER}")" == "不一致" ]] && not_ready_reason="$(append_reason_text "${not_ready_reason}" "provider 与目标不一致")"
  fi

  [[ "${skill_missing_count}" != "0" ]] && not_ready_reason="$(append_reason_text "${not_ready_reason}" "默认 skill 缺失 ${skill_missing_count} 项")"
  [[ "${skill_inactive_count}" != "0" ]] && not_ready_reason="$(append_reason_text "${not_ready_reason}" "默认 skill 未生效 ${skill_inactive_count} 项")"
  [[ "${hooks_exists}" != "yes" ]] && not_ready_reason="$(append_reason_text "${not_ready_reason}" "全局 hooks 未初始化")"

  print_report_line "全局配置" "${GLOBAL_CONFIG_PATH} (${config_exists})"
  print_report_line "全局 AGENTS" "${GLOBAL_AGENTS_DOC_PATH} (${agents_doc_exists})"
  print_report_line "用户技能目录" "${GLOBAL_USER_SKILLS_DIR} (${user_skills_exists})"
  print_report_line "全局 hooks" "${GLOBAL_HOOKS_PATH} (${hooks_exists})"
  print_report_line "运行状态" "${runtime_state}"
  print_report_line "建议动作" "$(recommended_service_action "codex" "${runtime_state}" "${CONFIG_FILE:-}")"
  [[ -n "${not_ready_reason}" ]] && print_report_line "未就绪原因" "${not_ready_reason}"
  print_report_line "最佳实践就绪度" "${readiness_summary}"
  print_report_line "当前模型" "${current_model}"
  print_report_line "当前 provider" "${current_provider}"
  print_report_line "认证方式" "${current_auth_mode}"
  print_report_line "认证状态" "${current_auth_state}"
  print_report_line "技能状态" "${skill_summary}"
  print_report_line "工具 env" "${TOOL_ENV_PATH}"
  print_report_line "工具包装命令" "${TOOL_WRAPPER_PATH}"
  print_report_line "工具目录" "${TOOL_RUNTIME_ROOT}"
  print_report_line "备份目录" "${BACKUP_ROOT}"
  print_report_line "能力包策略" "$(pack_strategy_summary "${COMMON_DEFAULT_PACKS}" "${TOOL_DEFAULT_PACKS}" "${ENHANCED_PACKS}" "${ENABLE_ENHANCED_PACKS}" "${EXPERIMENTAL_PACKS}" "${ENABLE_EXPERIMENTAL_PACKS}")"
  print_report_line "核心能力统计" "${capability_stats}"
  print_report_line "能力项统计" "${capability_counts}"
  print_report_line "能力包清单" "${TOOL_PACKS_MANIFEST_PATH} ($(path_state "${TOOL_PACKS_MANIFEST_PATH}"))"
  print_report_line "技能清单" "${TOOL_SKILLS_MANIFEST_PATH} ($(path_state "${TOOL_SKILLS_MANIFEST_PATH}"))"
  print_report_line "技能快照" "${TOOL_SKILL_STATUS_PATH} ($(path_state "${TOOL_SKILL_STATUS_PATH}"))"
  print_report_line "插件清单" "${TOOL_PLUGINS_MANIFEST_PATH} ($(path_state "${TOOL_PLUGINS_MANIFEST_PATH}"))"
  print_report_line "Hook 清单" "${TOOL_HOOKS_MANIFEST_PATH} ($(path_state "${TOOL_HOOKS_MANIFEST_PATH}"))"
  print_report_line "MCP 清单" "${TOOL_MCP_MANIFEST_PATH} ($(path_state "${TOOL_MCP_MANIFEST_PATH}"))"
  print_report_line "Agent 清单" "${TOOL_AGENTS_MANIFEST_PATH} ($(path_state "${TOOL_AGENTS_MANIFEST_PATH}"))"

  if [[ -n "${CONFIG_FILE}" ]]; then
    print_report_line "目标配置文件" "${CONFIG_FILE}"
    print_report_line "目标默认模型" "${DEFAULT_MODEL}"
    print_report_line "目标 provider" "${MODEL_PROVIDER}"
    print_report_line "模型比对" "$(setting_compare_state "${current_model}" "${DEFAULT_MODEL}")"
    print_report_line "Provider 比对" "$(setting_compare_state "${current_provider}" "${MODEL_PROVIDER}")"
  fi

  if command -v codex >/dev/null 2>&1; then
    print_report_line "MCP 状态" "$(codex mcp list 2>&1 | tail -n 1)"
  else
    print_report_line "MCP 状态" "Codex 未安装，跳过"
  fi
}

cmd_service_report() {
  local codex_path=""
  local install_state="未安装"
  local not_ready_reason=""
  local current_provider="未检测到"
  local current_model="未检测到"
  local config_state="missing"
  local hooks_state="missing"
  local current_auth_mode="未检测到"
  local current_auth_state="未检测到"
  local current_env_key="OPENAI_API_KEY"
  local skill_missing_count="0"
  local skill_inactive_count="0"
  local skill_summary="未检测到"
  local readiness_summary="未检测到"
  local capability_stats="未检测到"
  local capability_counts="skill 0 / plugin 0 / hook 0 / mcp 0 / agent 0"

  load_config_if_present
  readonly_manifest_scope_begin TOOL_SKILL_STATUS_PATH
  render_runtime_manifests
  codex_path="$(codex_binary_path)"

  if [[ -n "${codex_path}" ]]; then
    install_state="已安装"
  fi

  if [[ -f "${GLOBAL_CONFIG_PATH}" ]]; then
    config_state="present"
    current_model="$(awk -F'=' '/^model[[:space:]]*=/{gsub(/[ "]/,"",$2); print $2; exit}' "${GLOBAL_CONFIG_PATH}")"
    current_provider="$(awk -F'=' '/^model_provider[[:space:]]*=/{gsub(/[ "]/,"",$2); print $2; exit}' "${GLOBAL_CONFIG_PATH}")"
    current_auth_mode="$(codex_auth_mode_value)"
    current_env_key="$(codex_current_env_key_value "${current_provider}")"
    [[ -n "${current_env_key}" ]] || current_env_key="OPENAI_API_KEY"
  fi

  [[ -f "${GLOBAL_HOOKS_PATH}" ]] && hooks_state="present"
  write_skill_status_snapshot
  current_auth_state="$(codex_auth_state "${current_auth_mode}" "${current_env_key}")"
  install_state="$(codex_runtime_state "${codex_path}" "$( [[ "${config_state}" == "present" ]] && printf 'yes' || printf 'no' )" "${current_auth_state}")"
  skill_missing_count="$(skill_status_count "缺失")"
  skill_inactive_count="$(skill_status_count "未生效")"
  skill_summary="$(skill_status_summary)"
  readiness_summary="$(codex_best_practice_readiness "${codex_path}" "$( [[ "${config_state}" == "present" ]] && printf 'yes' || printf 'no' )" "${current_auth_state}")"
  capability_stats="$(capability_stats_summary "${TOOL_SKILLS_MANIFEST_PATH}" "${TOOL_PLUGINS_MANIFEST_PATH}" "${TOOL_HOOKS_MANIFEST_PATH}" "${TOOL_MCP_MANIFEST_PATH}" "${TOOL_AGENTS_MANIFEST_PATH}" "plugin")"
  capability_counts="skill $(manifest_item_count "${TOOL_SKILLS_MANIFEST_PATH}") / plugin $(manifest_item_count "${TOOL_PLUGINS_MANIFEST_PATH}") / hook $(manifest_item_count "${TOOL_HOOKS_MANIFEST_PATH}") / mcp $(manifest_item_count "${TOOL_MCP_MANIFEST_PATH}") / agent $(manifest_item_count "${TOOL_AGENTS_MANIFEST_PATH}")"
  readonly_manifest_scope_end

  case "${install_state}" in
    未安装)
      not_ready_reason="$(append_reason_text "${not_ready_reason}" "未检测到 codex 命令")"
      ;;
    未配置)
      not_ready_reason="$(append_reason_text "${not_ready_reason}" "缺少全局配置")"
      ;;
    需人工登录或授权)
      if [[ "${current_auth_state}" == "需登录" ]]; then
        not_ready_reason="$(append_reason_text "${not_ready_reason}" "当前认证方式需要登录")"
      else
        not_ready_reason="$(append_reason_text "${not_ready_reason}" "当前 API Key 未配置")"
      fi
      ;;
  esac

  if [[ -n "${CONFIG_FILE}" ]]; then
    [[ "$(setting_compare_state "${current_model}" "${DEFAULT_MODEL}")" == "不一致" ]] && not_ready_reason="$(append_reason_text "${not_ready_reason}" "模型与目标不一致")"
    [[ "$(setting_compare_state "${current_provider}" "${MODEL_PROVIDER}")" == "不一致" ]] && not_ready_reason="$(append_reason_text "${not_ready_reason}" "provider 与目标不一致")"
  fi

  [[ "${skill_missing_count}" != "0" ]] && not_ready_reason="$(append_reason_text "${not_ready_reason}" "默认 skill 缺失 ${skill_missing_count} 项")"
  [[ "${skill_inactive_count}" != "0" ]] && not_ready_reason="$(append_reason_text "${not_ready_reason}" "默认 skill 未生效 ${skill_inactive_count} 项")"
  [[ "${hooks_state}" != "present" ]] && not_ready_reason="$(append_reason_text "${not_ready_reason}" "全局 hooks 未初始化")"

  print_section "Codex 概览"
  print_report_line "安装状态" "${install_state}"
  print_report_line "建议动作" "$(recommended_service_action "codex" "${install_state}" "${CONFIG_FILE:-}")"
  [[ -n "${not_ready_reason}" ]] && print_report_line "未就绪原因" "${not_ready_reason}"
  print_report_line "Codex 命令" "${codex_path:-未安装}"
  print_report_line "当前模型" "${current_model}"
  print_report_line "当前 provider" "${current_provider}"
  print_report_line "认证方式" "${current_auth_mode}"
  print_report_line "认证状态" "${current_auth_state}"
  print_report_line "全局配置" "${GLOBAL_CONFIG_PATH} (${config_state})"
  print_report_line "全局 hooks" "${GLOBAL_HOOKS_PATH} (${hooks_state})"
  print_report_line "工具目录" "${TOOL_RUNTIME_ROOT}"
  print_report_line "最佳实践就绪度" "${readiness_summary}"
  print_report_line "能力包策略" "$(pack_strategy_summary "${COMMON_DEFAULT_PACKS}" "${TOOL_DEFAULT_PACKS}" "${ENHANCED_PACKS}" "${ENABLE_ENHANCED_PACKS}" "${EXPERIMENTAL_PACKS}" "${ENABLE_EXPERIMENTAL_PACKS}")"
  print_report_line "技能状态" "${skill_summary}"
  print_report_line "核心能力统计" "${capability_stats}"
  print_report_line "能力项统计" "${capability_counts}"
  print_report_line "能力包清单" "${TOOL_PACKS_MANIFEST_PATH} ($(path_state "${TOOL_PACKS_MANIFEST_PATH}"))"
  print_report_line "技能快照" "${TOOL_SKILL_STATUS_PATH} ($(path_state "${TOOL_SKILL_STATUS_PATH}"))"
  print_report_line "Agent 清单" "${TOOL_AGENTS_MANIFEST_PATH} ($(path_state "${TOOL_AGENTS_MANIFEST_PATH}"))"

  if [[ -n "${CONFIG_FILE}" ]]; then
    print_report_line "目标默认模型" "${DEFAULT_MODEL}"
    print_report_line "目标 provider" "${MODEL_PROVIDER}"
    print_report_line "模型比对" "$(setting_compare_state "${current_model}" "${DEFAULT_MODEL}")"
    print_report_line "Provider 比对" "$(setting_compare_state "${current_provider}" "${MODEL_PROVIDER}")"
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
  [[ -f "${GLOBAL_CONFIG_PATH}" ]] && cp -a "${GLOBAL_CONFIG_PATH}" "${backup_dir}/config.toml"
  [[ -f "${GLOBAL_AGENTS_DOC_PATH}" ]] && cp -a "${GLOBAL_AGENTS_DOC_PATH}" "${backup_dir}/AGENTS.md"
  [[ -f "${GLOBAL_HOOKS_PATH}" ]] && cp -a "${GLOBAL_HOOKS_PATH}" "${backup_dir}/hooks.json"
  [[ -f "${TOOL_TRUSTED_PROJECTS_PATH}" ]] && cp -a "${TOOL_TRUSTED_PROJECTS_PATH}" "${backup_dir}/trusted-projects.list"
  [[ -d "${TOOL_MANIFESTS_DIR}" ]] && cp -a "${TOOL_MANIFESTS_DIR}" "${backup_dir}/manifests"

  log_info "已创建 Codex 配置备份：${backup_dir}"
}

cmd_config_restore() {
  local backup_dir="${TARGET_PATH:-}"

  require_config
  require_root
  ensure_runtime_layout
  [[ -n "${backup_dir}" ]] || die "config restore 必须通过 --path 指定备份目录"
  [[ -d "${backup_dir}" ]] || die "备份目录不存在：${backup_dir}"

  if ! confirm_action "将从 ${backup_dir} 恢复 Codex 配置，是否继续？" "${ASSUME_YES}"; then
    log_warn "已取消执行。"
    exit 0
  fi

  [[ -f "${backup_dir}/config.conf" ]] && cp -a "${backup_dir}/config.conf" "${CONFIG_FILE}"
  [[ -f "${backup_dir}/config.toml" ]] && cp -a "${backup_dir}/config.toml" "${GLOBAL_CONFIG_PATH}"
  [[ -f "${backup_dir}/AGENTS.md" ]] && cp -a "${backup_dir}/AGENTS.md" "${GLOBAL_AGENTS_DOC_PATH}"
  [[ -f "${backup_dir}/hooks.json" ]] && cp -a "${backup_dir}/hooks.json" "${GLOBAL_HOOKS_PATH}"
  [[ -f "${backup_dir}/trusted-projects.list" ]] && cp -a "${backup_dir}/trusted-projects.list" "${TOOL_TRUSTED_PROJECTS_PATH}"
  if [[ -d "${backup_dir}/manifests" ]]; then
    rm -rf "${TOOL_MANIFESTS_DIR}"
    cp -a "${backup_dir}/manifests" "${TOOL_MANIFESTS_DIR}"
  fi

  log_info "已恢复 Codex 配置：${backup_dir}"
}

cmd_config_show() {
  local section="${TARGET_SECTION:-summary}"

  require_config

  print_section "Codex 配置"

  case "${section}" in
    summary)
      print_report_line "目标配置文件" "${CONFIG_FILE}"
      print_report_line "安装方式" "${INSTALL_METHOD}"
      print_report_line "模型" "${DEFAULT_MODEL}"
      print_report_line "推理强度" "${MODEL_REASONING_EFFORT}"
      print_report_line "认证方式" "${AUTH_METHOD}"
      print_report_line "模型提供方" "${MODEL_PROVIDER}"
      print_report_line "Base URL" "${API_BASE_URL:-未声明}"
      print_report_line "沙箱模式" "${SANDBOX_MODE}"
      print_report_line "审批策略" "${APPROVAL_POLICY}"
      ;;
    paths)
      print_report_line "全局目录" "${GLOBAL_CODEX_DIR}"
      print_report_line "全局配置" "${GLOBAL_CONFIG_PATH}"
      print_report_line "全局 AGENTS" "${GLOBAL_AGENTS_DOC_PATH}"
      print_report_line "全局 hooks" "${GLOBAL_HOOKS_PATH}"
      print_report_line "共享 skills" "${GLOBAL_USER_SKILLS_DIR}"
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
      print_report_line "TRUST_PATHS" "${TRUST_PATHS:-<空>}"
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
      render_global_agents_template_if_missing
      render_global_hooks_template
      render_runtime_env_file
      render_wrapper_script
      render_runtime_manifests
      render_support_notes_if_missing
      write_skill_status_snapshot
      log_info "已初始化 Codex 工具目录：${TOOL_RUNTIME_ROOT}"
      log_info "已生成工具目录 config.toml：${TOOL_GLOBAL_CONFIG_PATH}"
      log_info "已准备工具目录 AGENTS 模板：${TOOL_GLOBAL_AGENTS_PATH}"
      log_info "已准备工具目录 hooks 模板：${TOOL_GLOBAL_HOOKS_PATH}"
      log_info "已生成工具目录 provider.env：${TOOL_ENV_PATH}"
      log_info "已生成工具目录包装命令：${TOOL_WRAPPER_PATH}"
      log_info "已生成初始化清单：${TOOL_PACKS_MANIFEST_PATH}、${TOOL_SKILLS_MANIFEST_PATH}、${TOOL_PLUGINS_MANIFEST_PATH}、${TOOL_HOOKS_MANIFEST_PATH}、${TOOL_MCP_MANIFEST_PATH}、${TOOL_AGENTS_MANIFEST_PATH}"
      log_info "官方目录已就绪：${GLOBAL_CODEX_DIR}、${GLOBAL_USER_SKILLS_DIR}"
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
      log_info "已生成：${TARGET_PATH}/.codex/config.toml"
      log_info "已生成：${TARGET_PATH}/.codex/hooks.json"
      log_info "已生成：${TARGET_PATH}/.agents/skills/"
      log_info "已生成：${TARGET_PATH}/.codex/agents/README.managed.md"
      ;;
    *)
      die "仅支持 --scope global 或 --scope project，收到：${TARGET_SCOPE:-<空>}"
      ;;
  esac
}

cmd_service_configure() {
  require_config
  if ! confirm_action "将按配置重写全局 Codex config.toml，是否继续？" "${ASSUME_YES}"; then
    log_warn "已取消执行。"
    exit 0
  fi
  sync_global_config
}

cmd_project_trust() {
  require_config
  [[ -n "${TARGET_PATH}" ]] || die "project trust 必须提供 --path"

  ensure_runtime_layout

  if [[ -f "${TOOL_TRUSTED_PROJECTS_PATH}" ]]; then
    if ! grep -Fqx "${TARGET_PATH}" "${TOOL_TRUSTED_PROJECTS_PATH}"; then
      printf '%s\n' "${TARGET_PATH}" >> "${TOOL_TRUSTED_PROJECTS_PATH}"
    fi
  else
    printf '%s\n' "${TARGET_PATH}" > "${TOOL_TRUSTED_PROJECTS_PATH}"
  fi

  sync_global_config
  log_info "已将项目标记为 trusted：${TARGET_PATH}"
}

cmd_extension_commands_not_exposed() {
  die "Codex 当前不单独提供 ${COMMAND_GROUP} ${COMMAND_ACTION} 命令，请使用 service install 或 config init 自动准备相关目录与运行清单。"
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
    project:trust)
      cmd_project_trust
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
