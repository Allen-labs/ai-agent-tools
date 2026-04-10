#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/common.sh"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/reporting.sh"

PROGRAM_NAME="$(basename "$0")"
COMMAND_GROUP="${1:-help}"
COMMAND_ACTION="${2:-}"
if [[ $# -gt 0 ]]; then
  shift
fi
if [[ $# -gt 0 && "${COMMAND_GROUP}" =~ ^(config|service|skill|plugin|feishu)$ ]]; then
  shift
fi

CONFIG_FILE=""
ASSUME_YES=0
KEEP_DATA=1
SHOW_GUIDE_ONLY=0
TARGET_NAMES=""
TARGET_PATH=""
TARGET_LEVEL=""
TARGET_WORKSPACE=""
TARGET_SCOPE=""
TARGET_SECTION=""

usage() {
  help_init_colors
  help_print_title "OpenClaw" "服务型工具，优先记 install / configure / report / check / logs"
  help_print_strong_rule
  help_print_context "主入口" "${PROGRAM_NAME}"
  help_print_context "访问模型" "standard + public-ip/public-domain，或 tailscale-private/tailscale-public"

  help_print_section "主命令"
  help_print_rule
  help_print_entry "service install" "首次安装"
  help_print_entry "service configure" "增强 / 重放配置"
  help_print_entry "service report" "状态概览"
  help_print_entry "service check" "详细排查"
  help_print_entry "service logs" "查看日志"

  help_print_section "常用参数"
  help_print_rule
  help_print_entry "--config PATH" "配置文件"
  help_print_entry "--yes" "跳过确认"
  help_print_entry "--name NAMES" "skill / plugin 名称"
  help_print_entry "--path PATH" "工作目录"
  help_print_entry "--help" "显示帮助"

  help_print_section "快速上手"
  help_print_rule
  help_print_step "1" "manage.sh guide start --tool-name openclaw"
  help_print_step "2" "编辑 ./general-agents/openclaw/local.conf"
  help_print_step "3" "${PROGRAM_NAME} service install --config /path/to/config.conf --yes"
  help_print_step "4" "${PROGRAM_NAME} service check --config /path/to/config.conf"

  help_print_section "常见场景"
  help_print_rule
  help_print_case "首次安装" "${PROGRAM_NAME} service install --config /path/to/config.conf --yes"
  help_print_case "已装增强" "${PROGRAM_NAME} service configure --config /path/to/config.conf --yes"
  help_print_case "查看状态" "${PROGRAM_NAME} service report --config /path/to/config.conf"
  help_print_case "详细排查" "${PROGRAM_NAME} service check --config /path/to/config.conf"

  help_print_section "按需能力"
  help_print_rule
  help_print_entry "service update" "升级服务"
  help_print_entry "service cert" "证书处理"
  help_print_entry "config backup / restore" "备份 / 恢复"
  help_print_entry "config apply / show" "配置分区"
  help_print_entry "skill / plugin / feishu" "扩展能力"
}

apt_install() {
  export DEBIAN_FRONTEND=noninteractive
  apt-get update
  apt-get install -y curl ca-certificates gnupg jq ufw
  if [[ "${ENABLE_NGINX:-0}" == "1" ]]; then
    apt-get install -y nginx
  fi
  if [[ "${ENABLE_CERTBOT:-0}" == "1" ]]; then
    apt-get install -y certbot
  fi
}

install_tailscale_if_needed() {
  if [[ "${ACCESS_MODE:-standard}" != tailscale-* ]]; then
    return
  fi
  if command -v tailscale >/dev/null 2>&1; then
    return
  fi
  curl -fsSL https://tailscale.com/install.sh | sh
}

setup_tailscale() {
  if [[ "${ACCESS_MODE:-standard}" != tailscale-* ]]; then
    return
  fi

  install_tailscale_if_needed
  systemctl enable --now tailscaled

  tailscale up \
    --auth-key="${TAILSCALE_AUTH_KEY}" \
    --hostname="${TAILSCALE_HOSTNAME}" \
    --accept-routes=false \
    --accept-dns=true \
    --reset
}

configure_tailscale_access() {
  if [[ "${ACCESS_MODE:-standard}" != tailscale-* ]]; then
    return
  fi

  case "${ACCESS_MODE}" in
    tailscale-private)
      tailscale funnel reset || true
      tailscale serve --bg "${TAILSCALE_SERVE_TARGET}"
      ;;
    tailscale-public)
      tailscale serve --bg "${TAILSCALE_SERVE_TARGET}"
      tailscale funnel --bg 443 on
      ;;
  esac
}

install_node_if_missing() {
  if command -v node >/dev/null 2>&1; then
    return
  fi
  curl -fsSL https://deb.nodesource.com/setup_24.x | bash -
  apt-get install -y nodejs
}

install_openclaw() {
  npm install -g openclaw@latest
}

install_skill_from_clawhub() {
  local skill_name="$1"
  local attempt=1
  local max_attempts=3
  local wait_seconds=5
  local output=""

  while (( attempt <= max_attempts )); do
    output="$(openclaw skills install "${skill_name}" 2>&1)" && {
      [[ -n "${output}" ]] && printf '%s\n' "${output}"
      return 0
    }

    printf '%s\n' "${output}" >&2
    if grep -q "429" <<< "${output}" && (( attempt < max_attempts )); then
      log warn "安装 skill 触发限流，${wait_seconds} 秒后重试：${skill_name} (${attempt}/${max_attempts})"
      sleep "${wait_seconds}"
      attempt=$((attempt + 1))
      wait_seconds=$((wait_seconds * 2))
      continue
    fi
    return 1
  done

  return 1
}

apt_install_if_missing() {
  local package="$1"
  if dpkg -s "${package}" >/dev/null 2>&1; then
    log info "系统包已存在，跳过：${package}"
    return
  fi
  apt-get install -y "${package}"
}

npm_install_if_missing() {
  local package="$1"
  local bin_name="${2:-$1}"
  if command -v "${bin_name}" >/dev/null 2>&1; then
    log info "命令已存在，跳过：${bin_name}"
    return
  fi
  npm install -g "${package}"
}

init_tool_layout_vars() {
  OPENCLAW_TOOL_ROOT="${SCRIPT_DIR}"
  OPENCLAW_TOOL_BIN_DIR="${OPENCLAW_TOOL_ROOT}/bin"
  BACKUP_ROOT="${BACKUP_ROOT:-${OPENCLAW_TOOL_ROOT}/backups}"
}

ensure_tool_layout() {
  init_tool_layout_vars
  mkdir -p "${BACKUP_ROOT}"
  mkdir -p "${OPENCLAW_STATE_DIR}" "${OPENCLAW_STATE_DIR}/skills" "${OPENCLAW_STATE_DIR}/extensions"
  openclaw_render_governance_files_if_missing
}

apply_project_layout() {
  local workspace_path="${TARGET_WORKSPACE:-${TARGET_PATH:-}}"
  [[ -n "${workspace_path}" ]] || die "必须通过 --path 或 --workspace 指定项目目录"
  [[ -d "${workspace_path}" ]] || die "项目目录不存在：${workspace_path}"

  mkdir -p "${workspace_path}/skills" "${workspace_path}/.openclaw/config" "${workspace_path}/.openclaw/data" "${workspace_path}/.openclaw/logs"
}

resolve_binary_patterns() {
  local cmd
  for cmd in "$@"; do
    type -P "${cmd}" 2>/dev/null || true
  done | awk 'NF && !seen[$0]++'
}

resolve_access_patterns() {
  local level="$1"
  init_tool_layout_vars
  case "${level}" in
    safe)
      {
        resolve_binary_patterns ls pwd cat head tail find rg sed awk grep jq stat du df ps ss free uname whoami id date sort uniq cut wc basename dirname readlink realpath
        printf '%s\n' "${OPENCLAW_TOOL_BIN_DIR}/oc-openclaw-health"
      } | awk 'NF && !seen[$0]++'
      ;;
    ops)
      {
        resolve_access_patterns safe
        printf '%s\n' \
          "${OPENCLAW_TOOL_BIN_DIR}/oc-service-status" \
          "${OPENCLAW_TOOL_BIN_DIR}/oc-service-active" \
          "${OPENCLAW_TOOL_BIN_DIR}/oc-gateway-logs" \
          "${OPENCLAW_TOOL_BIN_DIR}/oc-nginx-test"
      } | awk 'NF && !seen[$0]++'
      ;;
    admin)
      {
        resolve_access_patterns ops
        printf '%s\n' \
          "${OPENCLAW_TOOL_BIN_DIR}/oc-service-restart" \
          "${OPENCLAW_TOOL_BIN_DIR}/oc-service-reload" \
          "/usr/bin/openclaw"
      } | awk 'NF && !seen[$0]++'
      ;;
    *)
      die "未知权限档位：${level}，仅支持 safe / ops / admin"
      ;;
  esac
}

write_access_policy() {
  local level="$1"
  local policy_file="$2"
  local existing_file="${OPENCLAW_STATE_DIR}/exec-approvals.json"
  local socket_path="${OPENCLAW_STATE_DIR}/exec-approvals.sock"
  local socket_token=""
  local patterns_json

  if [[ -f "${existing_file}" ]]; then
    socket_path="$(jq -r '.socket.path // empty' "${existing_file}" 2>/dev/null || echo "${socket_path}")"
    socket_token="$(jq -r '.socket.token // empty' "${existing_file}" 2>/dev/null || true)"
  fi

  patterns_json="$(
    while IFS= read -r pattern; do
      [[ -n "${pattern}" ]] || continue
      jq -n --arg id "$(cat /proc/sys/kernel/random/uuid)" --arg pattern "${pattern}" '{id: $id, pattern: $pattern}'
    done < <(resolve_access_patterns "${level}") | jq -s .
  )"

  jq -n \
    --arg socket_path "${socket_path}" \
    --arg socket_token "${socket_token}" \
    --argjson allowlist "${patterns_json}" \
    '{
      version: 1,
      socket: {
        path: $socket_path,
        token: $socket_token
      },
      defaults: {},
      agents: {
        main: {
          allowlist: $allowlist
        }
      }
    }' > "${policy_file}"
}

warn_env_missing_for_skill() {
  local skill_name="$1"
  local env_name="$2"
  local env_value="${3:-}"
  if [[ -n "${env_value}" ]]; then
    log info "${skill_name} 所需环境变量已填写：${env_name}"
  else
    log warn "${skill_name} 依赖环境变量 ${env_name}，当前未填写。"
  fi
}

trim_csv_item() {
  printf '%s' "${1:-}" | xargs
}

detect_clawhub_login_state() {
  if ! command -v clawhub >/dev/null 2>&1; then
    printf '%s\n' "missing"
    return
  fi

  local output=""
  output="$(clawhub whoami 2>&1 || true)"
  if grep -qiE "not logged in|unauthorized|login required|anonymous" <<< "${output}"; then
    printf '%s\n' "anonymous"
    return
  fi
  if [[ -n "$(printf '%s' "${output}" | tr -d '[:space:]')" ]]; then
    printf '%s\n' "logged-in"
    return
  fi
  printf '%s\n' "unknown"
}

default_skill_specs_csv() {
  printf '%s\n' "clawhub:find-skill,clawhub:github,clawhub:gh-issues,clawhub:session-logs,clawhub:video-frames"
}

default_skill_specs_ready() {
  [[ "${ENABLE_DEFAULT_SKILLS:-1}" == "1" ]] || return 1
  [[ "$(detect_clawhub_login_state)" == "logged-in" ]]
}

resolve_configured_skill_specs_csv() {
  if [[ -n "${SKILL_SPECS:-}" ]]; then
    printf '%s\n' "${SKILL_SPECS}"
    return
  fi
  if default_skill_specs_ready; then
    default_skill_specs_csv
    return
  fi
  printf '%s\n' ""
}

resolve_skill_spec_source() {
  local spec="$1"
  case "${spec}" in
    clawhub:*) printf '%s\n' "clawhub" ;;
    git:*) printf '%s\n' "git" ;;
    dir:*) printf '%s\n' "dir" ;;
    archive:*) printf '%s\n' "archive" ;;
    *) printf '%s\n' "clawhub" ;;
  esac
}

resolve_skill_spec_value() {
  local spec="$1"
  case "${spec}" in
    clawhub:*|git:*|dir:*|archive:*)
      printf '%s\n' "${spec#*:}"
      ;;
    *)
      printf '%s\n' "${spec}"
      ;;
  esac
}

resolve_plugin_spec_value() {
  local spec="$1"
  case "${spec}" in
    npm:*|clawhub:*|file:*)
      printf '%s\n' "${spec}"
      ;;
    *)
      printf '%s\n' "${spec}"
      ;;
  esac
}

resolve_skill_target_name() {
  local spec="$1"
  local source=""
  local value=""
  local repo_part=""
  local subdir=""

  source="$(resolve_skill_spec_source "${spec}")"
  value="$(resolve_skill_spec_value "${spec}")"
  case "${source}" in
    clawhub)
      printf '%s\n' "${value}"
      ;;
    git)
      repo_part="${value%%::*}"
      if [[ "${value}" == *"::"* ]]; then
        subdir="${value#*::}"
      fi
      if [[ -n "${subdir}" ]]; then
        printf '%s\n' "$(basename "${subdir}")"
        return
      fi
      repo_part="${repo_part%%#*}"
      repo_part="${repo_part%/}"
      repo_part="${repo_part##*/}"
      printf '%s\n' "${repo_part%.git}"
      ;;
    dir|archive)
      value="${value%/}"
      value="$(basename "${value}")"
      value="${value%.tar.gz}"
      value="${value%.tgz}"
      value="${value%.zip}"
      value="${value%.tar}"
      printf '%s\n' "${value}"
      ;;
    *)
      printf '%s\n' "${value}"
      ;;
  esac
}

install_skill_from_dir_copy() {
  local source_dir="$1"
  local target_name="$2"
  local target_dir="${OPENCLAW_STATE_DIR}/skills/${target_name}"

  [[ -d "${source_dir}" ]] || die "skill 目录不存在：${source_dir}"
  [[ -f "${source_dir}/SKILL.md" ]] || die "skill 目录缺少 SKILL.md：${source_dir}"

  mkdir -p "${OPENCLAW_STATE_DIR}/skills"
  rm -rf "${target_dir}"
  mkdir -p "$(dirname "${target_dir}")"
  cp -a "${source_dir}" "${target_dir}"
  log ok "已安装 skill：${target_name} -> ${target_dir}"
}

install_skill_from_git_spec() {
  local spec_value="$1"
  local repo_part="${spec_value%%::*}"
  local subdir=""
  local repo_url=""
  local repo_ref=""
  local clone_dir=""
  local source_dir=""
  local target_name=""

  if [[ "${spec_value}" == *"::"* ]]; then
    subdir="${spec_value#*::}"
  fi
  if [[ "${repo_part}" == *"#"* ]]; then
    repo_url="${repo_part%%#*}"
    repo_ref="${repo_part#*#}"
  else
    repo_url="${repo_part}"
  fi

  apt_install_if_missing git
  clone_dir="$(mktemp -d)"
  if [[ -n "${repo_ref}" ]]; then
    git clone --depth 1 --branch "${repo_ref}" "${repo_url}" "${clone_dir}/repo"
  else
    git clone --depth 1 "${repo_url}" "${clone_dir}/repo"
  fi

  source_dir="${clone_dir}/repo"
  if [[ -n "${subdir}" ]]; then
    source_dir="${source_dir}/${subdir}"
  fi
  target_name="$(resolve_skill_target_name "git:${spec_value}")"
  install_skill_from_dir_copy "${source_dir}" "${target_name}"
  rm -rf "${clone_dir}"
}

install_skill_from_archive_spec() {
  local archive_path="$1"
  local extract_dir=""
  local source_dir=""
  local target_name=""

  [[ -f "${archive_path}" ]] || die "skill 压缩包不存在：${archive_path}"
  extract_dir="$(mktemp -d)"
  case "${archive_path}" in
    *.tar.gz|*.tgz|*.tar)
      tar -xf "${archive_path}" -C "${extract_dir}"
      ;;
    *.zip)
      apt_install_if_missing unzip
      unzip -q "${archive_path}" -d "${extract_dir}"
      ;;
    *)
      rm -rf "${extract_dir}"
      die "暂不支持的 skill 压缩包格式：${archive_path}"
      ;;
  esac

  source_dir="$(find "${extract_dir}" -mindepth 1 -maxdepth 3 -type f -name SKILL.md -printf '%h\n' | head -n 1)"
  [[ -n "${source_dir}" ]] || {
    rm -rf "${extract_dir}"
    die "压缩包中未找到 SKILL.md：${archive_path}"
  }
  target_name="$(resolve_skill_target_name "archive:${archive_path}")"
  install_skill_from_dir_copy "${source_dir}" "${target_name}"
  rm -rf "${extract_dir}"
}

build_plugin_allow_json() {
  local allow_csv="${PLUGINS_ALLOW:-openclaw-lark}"
  local memory_slot="${MEMORY_PLUGIN:-}"
  local context_slot="${CONTEXT_ENGINE:-}"
  local items=()
  IFS=',' read -r -a raw_items <<< "${allow_csv}"
  for item in "${raw_items[@]}"; do
    [[ -n "${item}" ]] && items+=("${item}")
  done
  if [[ "${ENABLE_MEMORY_PLUGIN:-0}" == "1" && -n "${memory_slot}" ]]; then
    items+=("${memory_slot}")
  fi
  if [[ "${ENABLE_CONTEXT_ENGINE:-0}" == "1" && -n "${context_slot}" ]]; then
    items+=("${context_slot}")
  fi
  printf '%s\n' "${items[@]}" | awk 'NF && !seen[$0]++' | jq -R . | jq -s .
}

build_allowed_origins_json() {
  local domain="${DOMAIN:-}"
  local extra="${CONTROL_UI_ALLOWED_ORIGINS:-}"
  local origins=()
  if [[ -n "${domain}" ]]; then
    origins+=("https://${domain}")
    if [[ "${domain}" != www.* ]]; then
      origins+=("https://www.${domain}")
    fi
  fi
  if [[ -n "${extra}" ]]; then
    IFS=',' read -r -a extra_origins <<< "${extra}"
    for origin in "${extra_origins[@]}"; do
      [[ -n "${origin}" ]] && origins+=("${origin}")
    done
  fi
  printf '%s\n' "${origins[@]}" | jq -R . | jq -s .
}

write_openclaw_config() {
  mkdir -p "${OPENCLAW_STATE_DIR}"
  local allowed_origins_json
  allowed_origins_json="$(build_allowed_origins_json)"
  local plugin_allow_json
  plugin_allow_json="$(build_plugin_allow_json)"

  jq -n \
    --arg gateway_token "${GATEWAY_TOKEN}" \
    --argjson gateway_port "${GATEWAY_PORT}" \
    --arg gateway_auth_mode "${GATEWAY_AUTH_MODE}" \
    --arg model_base_url "${MODEL_BASE_URL}" \
    --arg model_provider_api "${MODEL_PROVIDER_API}" \
    --arg model_primary "${MODEL_PRIMARY}" \
    --arg model_fast "${MODEL_FAST}" \
    --arg model_alt_1 "${MODEL_ALT_1}" \
    --arg model_alt_2 "${MODEL_ALT_2}" \
    --argjson allowed_origins "${allowed_origins_json}" \
    --argjson plugins_allow "${plugin_allow_json}" \
    --arg enable_feishu "${ENABLE_FEISHU:-0}" \
    --arg feishu_app_id "${FEISHU_APP_ID:-}" \
    --arg feishu_app_secret "${FEISHU_APP_SECRET:-}" \
    --arg feishu_verification_token "${FEISHU_VERIFICATION_TOKEN:-}" \
    --arg feishu_encrypt_key "${FEISHU_ENCRYPT_KEY:-}" \
    --arg feishu_dm_policy "${FEISHU_DM_POLICY:-open}" \
    --argjson feishu_streaming "$(bool_to_json "${FEISHU_STREAMING:-1}")" \
    --arg enable_tavily_tool "${ENABLE_TAVILY_TOOL:-0}" \
    --arg tavily_api_key "${TAVILY_API_KEY:-}" \
    --arg tavily_base_url "${TAVILY_BASE_URL:-https://api.tavily.com}" \
    --arg enable_firecrawl_tool "${ENABLE_FIRECRAWL_TOOL:-0}" \
    --arg firecrawl_api_key "${FIRECRAWL_API_KEY:-}" \
    --arg firecrawl_base_url "${FIRECRAWL_BASE_URL:-https://api.firecrawl.dev}" \
    --argjson firecrawl_only_main_content "$(bool_to_json "${FIRECRAWL_ONLY_MAIN_CONTENT:-1}")" \
    --argjson firecrawl_max_age_ms "${FIRECRAWL_MAX_AGE_MS:-172800000}" \
    --argjson firecrawl_timeout_seconds "${FIRECRAWL_TIMEOUT_SECONDS:-60}" \
    --arg enable_memory_plugin "${ENABLE_MEMORY_PLUGIN:-0}" \
    --arg memory_plugin "${MEMORY_PLUGIN:-}" \
    --arg enable_context_engine "${ENABLE_CONTEXT_ENGINE:-0}" \
    --arg context_engine "${CONTEXT_ENGINE:-}" \
    --arg memory_embedding_api_key "${MEMORY_EMBEDDING_API_KEY:-}" \
    --arg memory_embedding_base_url "${MEMORY_EMBEDDING_BASE_URL:-}" \
    --arg memory_embedding_model "${MEMORY_EMBEDDING_MODEL:-text-embedding-3-small}" \
    --arg memory_db_path "${MEMORY_DB_PATH:-}" \
    --argjson memory_auto_capture "$(bool_to_json "${MEMORY_AUTO_CAPTURE:-0}")" \
    --argjson memory_auto_recall "$(bool_to_json "${MEMORY_AUTO_RECALL:-1}")" \
    --argjson memory_capture_max_chars "${MEMORY_CAPTURE_MAX_CHARS:-500}" \
    --argjson memory_smart_extraction "$(bool_to_json "${MEMORY_SMART_EXTRACTION:-1}")" \
    --argjson memory_extract_min_messages "${MEMORY_EXTRACT_MIN_MESSAGES:-2}" \
    --argjson memory_extract_max_chars "${MEMORY_EXTRACT_MAX_CHARS:-8000}" \
    --argjson memory_session_memory_enabled "$(bool_to_json "${MEMORY_SESSION_MEMORY_ENABLED:-0}")" \
    --arg lossless_database_path "${LOSSLESS_DATABASE_PATH:-}" \
    --argjson lossless_fresh_tail_count "${LOSSLESS_FRESH_TAIL_COUNT:-64}" \
    --argjson lossless_leaf_chunk_tokens "${LOSSLESS_LEAF_CHUNK_TOKENS:-20000}" \
    --argjson lossless_new_session_retain_depth "${LOSSLESS_NEW_SESSION_RETAIN_DEPTH:-2}" \
    --argjson lossless_context_threshold "${LOSSLESS_CONTEXT_THRESHOLD:-0.75}" \
    --argjson lossless_incremental_max_depth "${LOSSLESS_INCREMENTAL_MAX_DEPTH:-1}" \
    --arg lossless_ignore_session_patterns "${LOSSLESS_IGNORE_SESSION_PATTERNS:-agent:*:cron:**}" \
    --arg lossless_summary_model "${LOSSLESS_SUMMARY_MODEL:-}" \
    --arg lossless_summary_provider "${LOSSLESS_SUMMARY_PROVIDER:-}" \
    --arg lossless_expansion_model "${LOSSLESS_EXPANSION_MODEL:-}" \
    --arg lossless_expansion_provider "${LOSSLESS_EXPANSION_PROVIDER:-}" \
    --argjson lossless_delegation_timeout_ms "${LOSSLESS_DELEGATION_TIMEOUT_MS:-300000}" \
    --argjson feishu_require_mention "$(bool_to_json "${FEISHU_REQUIRE_MENTION:-0}")" \
    '
    {
      gateway: {
        mode: "local",
        auth: {
          mode: $gateway_auth_mode,
          token: $gateway_token
        },
        port: $gateway_port,
        controlUi: {
          allowedOrigins: $allowed_origins
        },
        trustedProxies: ["127.0.0.1", "::1"]
      },
      plugins: {
        allow: $plugins_allow,
        slots: (
          (
            if $enable_memory_plugin == "1" and ($memory_plugin | length) > 0 then
              { memory: $memory_plugin }
            else
              {}
            end
          ) + (
            if $enable_context_engine == "1" and ($context_engine | length) > 0 then
              { contextEngine: $context_engine }
            else
              {}
            end
          )
        ),
        entries: {
          feishu: { enabled: false },
          "openclaw-lark": { enabled: ($enable_feishu == "1") },
          "memory-lancedb": (
            if $enable_memory_plugin == "1" and $memory_plugin == "memory-lancedb" then
              {
                enabled: true,
                config: (
                  {
                    embedding: {
                      apiKey: $memory_embedding_api_key,
                      model: $memory_embedding_model
                    },
                    autoCapture: $memory_auto_capture,
                    autoRecall: $memory_auto_recall,
                    captureMaxChars: $memory_capture_max_chars
                  }
                  + (
                    if ($memory_embedding_base_url | length) > 0 then
                      {
                        embedding: {
                          apiKey: $memory_embedding_api_key,
                          model: $memory_embedding_model,
                          baseUrl: $memory_embedding_base_url
                        }
                      }
                    else
                      {}
                    end
                  )
                  + (
                    if ($memory_db_path | length) > 0 then
                      { dbPath: $memory_db_path }
                    else
                      {}
                    end
                  )
                )
              }
            else
              null
            end
          ),
          "memory-lancedb-pro": (
            if $enable_memory_plugin == "1" and $memory_plugin == "memory-lancedb-pro" then
              {
                enabled: true,
                config: (
                  {
                    embedding: {
                      provider: "openai-compatible",
                      apiKey: $memory_embedding_api_key,
                      model: $memory_embedding_model
                    },
                    autoCapture: $memory_auto_capture,
                    autoRecall: $memory_auto_recall,
                    smartExtraction: $memory_smart_extraction,
                    extractMinMessages: $memory_extract_min_messages,
                    extractMaxChars: $memory_extract_max_chars,
                    sessionMemory: {
                      enabled: $memory_session_memory_enabled
                    }
                  }
                  + (
                    if ($memory_embedding_base_url | length) > 0 then
                      {
                        embedding: {
                          provider: "openai-compatible",
                          apiKey: $memory_embedding_api_key,
                          model: $memory_embedding_model,
                          baseUrl: $memory_embedding_base_url
                        }
                      }
                    else
                      {}
                    end
                  )
                  + (
                    if ($memory_db_path | length) > 0 then
                      { dbPath: $memory_db_path }
                    else
                      {}
                    end
                  )
                )
              }
            else
              null
            end
          ),
          "lossless-claw": (
            if $enable_context_engine == "1" and $context_engine == "lossless-claw" then
              {
                enabled: true,
                config: (
                  {
                    freshTailCount: $lossless_fresh_tail_count,
                    leafChunkTokens: $lossless_leaf_chunk_tokens,
                    newSessionRetainDepth: $lossless_new_session_retain_depth,
                    contextThreshold: $lossless_context_threshold,
                    incrementalMaxDepth: $lossless_incremental_max_depth,
                    ignoreSessionPatterns: ($lossless_ignore_session_patterns | split(",") | map(select(length > 0))),
                    delegationTimeoutMs: $lossless_delegation_timeout_ms
                  }
                  + (
                    if ($lossless_database_path | length) > 0 then
                      { databasePath: $lossless_database_path }
                    else
                      {}
                    end
                  )
                  + (
                    if ($lossless_summary_model | length) > 0 then
                      { summaryModel: $lossless_summary_model }
                    else
                      {}
                    end
                  )
                  + (
                    if ($lossless_summary_provider | length) > 0 then
                      { summaryProvider: $lossless_summary_provider }
                    else
                      {}
                    end
                  )
                  + (
                    if ($lossless_expansion_model | length) > 0 then
                      { expansionModel: $lossless_expansion_model }
                    else
                      {}
                    end
                  )
                  + (
                    if ($lossless_expansion_provider | length) > 0 then
                      { expansionProvider: $lossless_expansion_provider }
                    else
                      {}
                    end
                  )
                )
              }
            else
              null
            end
          ),
          tavily: (
            if $enable_tavily_tool == "1" or ($tavily_api_key | length) > 0 then
              {
                enabled: true,
                config: {
                  webSearch: (
                    {
                      apiKey: $tavily_api_key
                    }
                    + (
                      if ($tavily_base_url | length) > 0 then
                        { baseUrl: $tavily_base_url }
                      else
                        {}
                      end
                    )
                  )
                }
              }
            else
              null
            end
          )
        } | with_entries(select(.value != null))
      },
      tools: (
        if $enable_firecrawl_tool == "1" or ($firecrawl_api_key | length) > 0 then
          {
            web: {
              fetch: {
                firecrawl: {
                  apiKey: $firecrawl_api_key,
                  baseUrl: $firecrawl_base_url,
                  onlyMainContent: $firecrawl_only_main_content,
                  maxAgeMs: $firecrawl_max_age_ms,
                  timeoutSeconds: $firecrawl_timeout_seconds
                }
              }
            }
          }
        else
          {}
        end
      ),
      models: {
        mode: "merge",
        providers: {
          openai: {
            baseUrl: $model_base_url,
            api: $model_provider_api,
            models: []
          }
        }
      },
      agents: {
        defaults: {
          compaction: { mode: "safeguard" },
          model: { primary: $model_primary },
          models: {
            ($model_fast): {},
            ($model_primary): {},
            ($model_alt_1): {},
            ($model_alt_2): {}
          }
        }
      }
    }
    + (
      if $enable_feishu == "1" then
        {
          channels: {
            feishu: {
              enabled: true,
              appId: $feishu_app_id,
              appSecret: $feishu_app_secret,
              verificationToken: $feishu_verification_token,
              encryptKey: $feishu_encrypt_key,
              requireMention: $feishu_require_mention,
              dmPolicy: $feishu_dm_policy,
              streaming: $feishu_streaming
            }
          }
        }
      else
        {}
      end
    )
    ' > "${OPENCLAW_CONFIG_PATH}"
}

configure_memory_plugin() {
  if [[ "${ENABLE_MEMORY_PLUGIN:-0}" != "1" ]]; then
    return
  fi
  if [[ "${MEMORY_PLUGIN:-}" != "memory-lancedb" && "${MEMORY_PLUGIN:-}" != "memory-lancedb-pro" ]]; then
    return
  fi
  [[ -n "${MEMORY_EMBEDDING_API_KEY:-}" ]] || die "MEMORY_EMBEDDING_API_KEY is required when memory-lancedb is enabled"
  mkdir -p "${OPENCLAW_STATE_DIR}/memory"
}

configure_context_engine() {
  if [[ "${ENABLE_CONTEXT_ENGINE:-0}" != "1" ]]; then
    return
  fi
  if [[ "${CONTEXT_ENGINE:-}" != "lossless-claw" ]]; then
    return
  fi
  if [[ -z "${LOSSLESS_DATABASE_PATH:-}" ]]; then
    return
  fi
  mkdir -p "$(dirname "${LOSSLESS_DATABASE_PATH}")"
}

install_feishu_plugin_if_requested() {
  if [[ "${ENABLE_FEISHU:-0}" != "1" ]]; then
    return
  fi
  if [[ -n "${OPENCLAW_LARK_PACKAGE:-}" ]]; then
    safe_plugin_install "${OPENCLAW_LARK_PACKAGE}" "飞书插件"
  fi
}

install_memory_plugin_if_requested() {
  if [[ "${ENABLE_MEMORY_PLUGIN:-0}" != "1" ]]; then
    return
  fi
  if [[ -n "${MEMORY_PLUGIN_PACKAGE:-}" ]]; then
    safe_plugin_install "${MEMORY_PLUGIN_PACKAGE}" "长期记忆插件"
  fi
}

install_context_engine_if_requested() {
  if [[ "${ENABLE_CONTEXT_ENGINE:-0}" != "1" ]]; then
    return
  fi
  if [[ -n "${CONTEXT_ENGINE_PACKAGE:-}" ]]; then
    safe_plugin_install "${CONTEXT_ENGINE_PACKAGE}" "上下文引擎"
  fi
}

install_configured_plugins() {
  local specs_csv="${PLUGIN_SPECS:-}"
  local raw_spec=""
  local normalized=""
  [[ -n "${specs_csv}" ]] || return 0
  IFS=',' read -r -a specs <<< "${specs_csv}"
  for raw_spec in "${specs[@]}"; do
    normalized="$(trim_csv_item "${raw_spec}")"
    [[ -z "${normalized}" ]] && continue
    if ! openclaw plugins install "$(resolve_plugin_spec_value "${normalized}")"; then
      log warn "插件安装失败：${normalized}"
    else
      log ok "插件安装完成：${normalized}"
    fi
  done
}

install_skill_from_spec() {
  local spec="$1"
  local source=""
  local value=""
  local skill_name=""
  local skill_info=""
  local clawhub_state=""

  source="$(resolve_skill_spec_source "${spec}")"
  value="$(resolve_skill_spec_value "${spec}")"
  skill_name="$(resolve_skill_target_name "${spec}")"

  case "${source}" in
    clawhub)
      skill_info="$(openclaw skills info "${value}" 2>/dev/null || true)"
      if grep -q "Source: openclaw-bundled" <<< "${skill_info}"; then
        log info "skill 已随 OpenClaw 自带，跳过安装：${value}"
        return
      fi
      if install_skill_from_clawhub "${value}"; then
        log ok "skill 安装完成：${value}"
        return
      fi
      clawhub_state="$(detect_clawhub_login_state)"
      case "${clawhub_state}" in
        anonymous)
          log warn "ClawHub 当前未登录，匿名安装更容易触发 429。请先执行 clawhub login，或改用 git:/dir:/archive: 来源。"
          ;;
        logged-in)
          log warn "ClawHub 已登录，但仍可能被上游限流。建议稍后重试，或改用 git:/dir:/archive: 来源。"
          ;;
        missing)
          log warn "当前未安装 clawhub CLI，无法判断登录状态。若持续 429，建议先执行 npm install -g clawhub 并登录。"
          ;;
        *)
          log warn "无法确认 ClawHub 登录状态。若持续 429，建议先 clawhub login 或改用 git:/dir:/archive: 来源。"
          ;;
      esac
      log warn "skill 安装失败：${value}"
      ;;
    git)
      install_skill_from_git_spec "${value}"
      ;;
    dir)
      install_skill_from_dir_copy "${value}" "${skill_name}"
      ;;
    archive)
      install_skill_from_archive_spec "${value}"
      ;;
    *)
      die "未知 skill 来源：${spec}"
      ;;
  esac
}

install_configured_skills() {
  local specs_csv=""
  local raw_spec=""
  local normalized=""
  specs_csv="$(resolve_target_skill_specs_csv)"
  [[ -n "${specs_csv}" ]] || return 0
  IFS=',' read -r -a specs <<< "${specs_csv}"
  for raw_spec in "${specs[@]}"; do
    normalized="$(trim_csv_item "${raw_spec}")"
    [[ -z "${normalized}" ]] && continue
    install_skill_from_spec "${normalized}"
  done
}

resolve_target_skill_specs_csv() {
  if [[ -n "${TARGET_NAMES}" ]]; then
    echo "${TARGET_NAMES}"
  else
    resolve_configured_skill_specs_csv
  fi
}

install_skill_dependencies() {
  local skills_csv
  local skill
  local normalized
  local source
  local dependency_key
  skills_csv="$(resolve_target_skill_specs_csv)"
  [[ -n "${skills_csv}" ]] || {
    log warn "未指定 skill，且 SKILL_SPECS 为空，跳过依赖安装。"
    return
  }

  IFS=',' read -r -a skills <<< "${skills_csv}"
  for skill in "${skills[@]}"; do
    normalized="$(trim_csv_item "${skill}")"
    [[ -n "${normalized}" ]] || continue
    source="$(resolve_skill_spec_source "${normalized}")"
    dependency_key="$(resolve_skill_target_name "${normalized}")"
    if [[ "${source}" != "clawhub" ]]; then
      log info "skill 使用 ${source} 来源，依赖请按该 skill 自身文档核对：${normalized}"
      continue
    fi
    case "${dependency_key}" in
      clawhub)
        log info "为 skill 安装依赖：${dependency_key}"
        npm_install_if_missing clawhub clawhub
        ;;
      github|gh-issues)
        log info "为 skill 安装依赖：${dependency_key}"
        apt_install_if_missing gh
        ;;
      session-logs)
        log info "为 skill 安装依赖：${dependency_key}"
        apt_install_if_missing jq
        ;;
      video-frames)
        log info "为 skill 安装依赖：${dependency_key}"
        apt_install_if_missing ffmpeg
        ;;
      openclaw-tavily-search|tavily-web-search-for-openclaw|tavily-search-skill|tavily-skill|tavily-tool)
        log info "检查 skill 环境变量：${dependency_key}"
        warn_env_missing_for_skill "${dependency_key}" "TAVILY_API_KEY" "${TAVILY_API_KEY:-}"
        ;;
      firecrawl-search|firecrawl-api|firecrawl-cli|firecrawl-local|firecrawl-mcp|web-scraper-firecrawl)
        log info "检查 skill 环境变量：${dependency_key}"
        warn_env_missing_for_skill "${dependency_key}" "FIRECRAWL_API_KEY" "${FIRECRAWL_API_KEY:-}"
        ;;
      playwright-mcp|playwright-mcp-skill|playwright-browser-automation|playwright)
        log warn "${dependency_key} 通常需要额外浏览器运行时，建议在独立节点或确认资源后再启用。"
        ;;
      obsidian-cli|obsidian-cli-official|obsidian-official-cli|obsidian-official-cli-headless)
        log warn "${dependency_key} 更适合连接已有 Obsidian Vault；若是纯服务器环境，建议确认 Vault 路径与运行方式后再启用。"
        ;;
      *)
        log warn "当前脚本暂未内置 ${dependency_key} 的自动依赖安装，请按 skill 文档补齐依赖。"
        ;;
    esac
  done
}

write_systemd_service() {
  local service_path="/etc/systemd/system/${SYSTEMD_SERVICE_NAME}.service"
  cat > "${service_path}" <<EOF
[Unit]
Description=OpenClaw Gateway
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=${OPENCLAW_USER}
WorkingDirectory=${OPENCLAW_HOME}
Environment=HOME=${OPENCLAW_HOME}
Environment=PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
ExecStart=/usr/bin/openclaw gateway run
Restart=always
RestartSec=5
KillMode=mixed
TimeoutStopSec=30

[Install]
WantedBy=multi-user.target
EOF
  systemctl daemon-reload
  systemctl enable "${SYSTEMD_SERVICE_NAME}.service"
}

openclaw_domain_aliases() {
  local domain="${DOMAIN:-}"
  [[ -n "${domain}" ]] || return 0
  if [[ "${domain}" == www.* ]]; then
    printf '%s' "${domain}"
  else
    printf '%s %s' "${domain}" "www.${domain}"
  fi
}

write_nginx_global_fragment() {
  cat > /etc/nginx/conf.d/openclaw-global.conf <<'EOF'
limit_req_zone $binary_remote_addr zone=perip:10m rate=10r/s;
limit_conn_zone $binary_remote_addr zone=connperip:10m;
limit_req_status 429;
server_tokens off;
EOF
}

write_nginx_http_config() {
  cat > /etc/nginx/sites-available/openclaw <<EOF
server {
    listen 80;
    server_name $(openclaw_domain_aliases);

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
        default_type text/plain;
    }

    location / {
        return 301 https://${DOMAIN}\$request_uri;
    }
}
EOF
}

write_nginx_ip_config() {
  cat > /etc/nginx/sites-available/openclaw <<EOF
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;

    add_header X-Content-Type-Options "nosniff" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header Referrer-Policy "same-origin" always;

    client_max_body_size 10m;
    proxy_read_timeout 3600;
    proxy_send_timeout 3600;
    proxy_buffering off;
    limit_conn connperip 20;

    if (\$request_method ~ ^(TRACE|TRACK|CONNECT)$) {
        return 405;
    }

    location ~ /\.(?!well-known/) { deny all; }
    location ~* ^/(?:wp-admin|wp-login\.php|wordpress|geoserver|vendor/|phpunit|cgi-bin/|server-status|actuator/|mgmt/|boaform/|\.env(?:\..*)?) { return 404; }
    location ~* (?:^|/)\.(?:git|svn|hg|bzr) { return 404; }
    location ~* \.(?:bak|old|orig|save|swp|sql|log|ini|yaml|yml|toml|conf)$ { return 404; }

    location / {
        limit_req zone=perip burst=30 nodelay;
        proxy_pass http://127.0.0.1:${GATEWAY_PORT};
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF
}

write_nginx_https_config() {
  cat > /etc/nginx/sites-available/openclaw <<EOF
server {
    listen 80;
    server_name $(openclaw_domain_aliases);

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
        default_type text/plain;
    }

    location / {
        return 301 https://${DOMAIN}\$request_uri;
    }
}

server {
    listen 443 ssl http2;
    server_name $(openclaw_domain_aliases);

    ssl_certificate /etc/letsencrypt/live/${DOMAIN}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${DOMAIN}/privkey.pem;

    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header Referrer-Policy "same-origin" always;

    client_max_body_size 10m;
    proxy_read_timeout 3600;
    proxy_send_timeout 3600;
    proxy_buffering off;
    limit_conn connperip 20;

    if (\$request_method ~ ^(TRACE|TRACK|CONNECT)$) {
        return 405;
    }

    location ~ /\.(?!well-known/) { deny all; }
    location ~* ^/(?:wp-admin|wp-login\.php|wordpress|geoserver|vendor/|phpunit|cgi-bin/|server-status|actuator/|mgmt/|boaform/|\.env(?:\..*)?) { return 404; }
    location ~* (?:^|/)\.(?:git|svn|hg|bzr) { return 404; }
    location ~* \.(?:bak|old|orig|save|swp|sql|log|ini|yaml|yml|toml|conf)$ { return 404; }

    location / {
        limit_req zone=perip burst=30 nodelay;
        proxy_pass http://127.0.0.1:${GATEWAY_PORT};
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF
}

write_nginx_config() {
  if [[ "${ENABLE_NGINX:-0}" != "1" ]]; then
    log info "配置中未启用 Nginx，跳过。"
    return
  fi
  mkdir -p /var/www/certbot
  write_nginx_global_fragment
  case "${PUBLIC_MODE:-public-domain}" in
    public-ip)
      write_nginx_ip_config
      ;;
    public-domain)
      [[ -n "${DOMAIN:-}" ]] || die "PUBLIC_MODE=public-domain 时必须填写 DOMAIN"
      if [[ -f "/etc/letsencrypt/live/${DOMAIN}/fullchain.pem" && -f "/etc/letsencrypt/live/${DOMAIN}/privkey.pem" ]]; then
        write_nginx_https_config
      else
        write_nginx_http_config
      fi
      ;;
    *)
      die "未知 PUBLIC_MODE：${PUBLIC_MODE}"
      ;;
  esac
  ln -sf /etc/nginx/sites-available/openclaw /etc/nginx/sites-enabled/openclaw
  nginx -t
  systemctl enable nginx
  systemctl restart nginx
}

setup_certbot() {
  local cert_domain=""
  local cert_domains=("${DOMAIN}")
  local certbot_args=()
  if [[ "${ENABLE_CERTBOT:-0}" != "1" ]]; then
    log info "配置中未启用 Certbot，跳过。"
    return
  fi
  [[ "${PUBLIC_MODE:-public-domain}" == "public-domain" ]] || die "仅 PUBLIC_MODE=public-domain 支持 Certbot"
  [[ -n "${DOMAIN:-}" && -n "${LETSENCRYPT_EMAIL:-}" ]] || die "已开启 Certbot，但 DOMAIN 或 LETSENCRYPT_EMAIL 缺失"
  if [[ "${DOMAIN}" != www.* ]]; then
    cert_domains+=("www.${DOMAIN}")
  fi
  for cert_domain in "${cert_domains[@]}"; do
    certbot_args+=(-d "${cert_domain}")
  done
  certbot certonly \
    --webroot \
    -w /var/www/certbot \
    "${certbot_args[@]}" \
    --non-interactive \
    --agree-tos \
    -m "${LETSENCRYPT_EMAIL}"
  write_nginx_https_config
  nginx -t
  systemctl reload nginx
}

setup_firewall() {
  if [[ "${ENABLE_UFW:-0}" != "1" ]]; then
    log info "配置中未启用 UFW，跳过。"
    return
  fi
  ufw default deny incoming
  ufw default allow outgoing
  ufw allow 22/tcp
  case "${ACCESS_MODE:-standard}" in
    standard)
      ufw allow 80/tcp
      if [[ "${PUBLIC_MODE:-public-domain}" == "public-domain" ]]; then
        ufw allow 443/tcp
      fi
      ;;
  esac
  ufw --force enable
}

service_tailscale_summary() {
  log info "Tailscale 访问说明"
  case "${ACCESS_MODE:-standard}" in
    tailscale-private)
      print_report_line "访问方式" "需要 Tailscale 客户端并登录同一 tailnet"
      print_report_line "主机名" "${TAILSCALE_HOSTNAME}"
      ;;
    tailscale-public)
      print_report_line "访问方式" "通过 Tailscale Funnel 公网访问"
      print_report_line "主机名" "${TAILSCALE_HOSTNAME}"
      ;;
  esac
}

restart_service() {
  systemctl restart "${SYSTEMD_SERVICE_NAME}.service"
  log ok "网关服务已重启。"
}

service_enable_action() {
  systemctl enable --now "${SYSTEMD_SERVICE_NAME}.service"
  log ok "网关服务已启用并启动。"
}

service_disable_action() {
  if ! confirm "将停止并禁用网关服务，是否继续？"; then
    die "已取消。"
  fi
  systemctl disable --now "${SYSTEMD_SERVICE_NAME}.service"
  log ok "网关服务已停止并禁用。"
}

service_reload_action() {
  systemctl daemon-reload
  if [[ "${ENABLE_NGINX:-0}" == "1" ]] && command -v nginx >/dev/null 2>&1; then
    nginx -t
    systemctl reload nginx
  fi
  restart_service
  log ok "服务重载完成。"
}

verify_install() {
  openclaw config validate
  systemctl is-active "${SYSTEMD_SERVICE_NAME}.service" >/dev/null
  openclaw health || true
}

service_diff_action() {
  local tmp_target
  local original_config_path
  tmp_target="$(mktemp)"
  original_config_path="${OPENCLAW_CONFIG_PATH}"
  trap 'rm -f "${tmp_target}"; OPENCLAW_CONFIG_PATH="${original_config_path}"' RETURN
  OPENCLAW_CONFIG_PATH="${tmp_target}"
  write_openclaw_config
  OPENCLAW_CONFIG_PATH="${original_config_path}"

  log info "对比目标配置与当前线上 OpenClaw 配置"
  if [[ -f "${OPENCLAW_CONFIG_PATH}" ]]; then
    if diff -u "${OPENCLAW_CONFIG_PATH}" "${tmp_target}"; then
      log ok "OpenClaw 配置无差异。"
    else
      log warn "上方显示的是 OpenClaw 配置差异。"
    fi
  else
    log warn "当前线上 OpenClaw 配置不存在：${OPENCLAW_CONFIG_PATH}"
  fi

  printf '\n'
  log info "系统接入文件状态"
  print_report_line "systemd unit" "$([[ -f "/etc/systemd/system/${SYSTEMD_SERVICE_NAME}.service" ]] && echo 存在 || echo 缺失)"
  print_report_line "nginx site" "$([[ -f "/etc/nginx/sites-available/openclaw" ]] && echo 存在 || echo 缺失)"
  print_report_line "nginx 全局片段" "$([[ -f "/etc/nginx/conf.d/openclaw-global.conf" ]] && echo 存在 || echo 缺失)"

  rm -f "${tmp_target}"
  trap - RETURN
}

config_backup_action() {
  local backup_dir
  local timestamp
  timestamp="$(date +%Y%m%d-%H%M%S)"
  init_tool_layout_vars
  backup_dir="${TARGET_PATH:-${BACKUP_ROOT}/${timestamp}}"
  mkdir -p "${backup_dir}"

  cp -a "${CONFIG_FILE}" "${backup_dir}/config.conf"
  if [[ -f "${OPENCLAW_CONFIG_PATH}" ]]; then
    cp -a "${OPENCLAW_CONFIG_PATH}" "${backup_dir}/openclaw.json"
  fi
  for governance_name in GOVERNANCE.md ENGINEERING.md DELIVERY.md MEMORY-RULES.md; do
    if [[ -f "${OPENCLAW_STATE_DIR}/${governance_name}" ]]; then
      cp -a "${OPENCLAW_STATE_DIR}/${governance_name}" "${backup_dir}/${governance_name}"
    fi
  done
  if [[ -f "${OPENCLAW_STATE_DIR}/exec-approvals.json" ]]; then
    cp -a "${OPENCLAW_STATE_DIR}/exec-approvals.json" "${backup_dir}/exec-approvals.json"
  fi
  if [[ -f "/etc/systemd/system/${SYSTEMD_SERVICE_NAME}.service" ]]; then
    cp -a "/etc/systemd/system/${SYSTEMD_SERVICE_NAME}.service" "${backup_dir}/${SYSTEMD_SERVICE_NAME}.service"
  fi
  if [[ -f "/etc/nginx/sites-available/openclaw" ]]; then
    cp -a "/etc/nginx/sites-available/openclaw" "${backup_dir}/nginx-openclaw-site.conf"
  fi
  if [[ -f "/etc/nginx/conf.d/openclaw-global.conf" ]]; then
    cp -a "/etc/nginx/conf.d/openclaw-global.conf" "${backup_dir}/nginx-openclaw-global.conf"
  fi
  log ok "备份已创建：${backup_dir}"
}

config_restore_action() {
  local backup_dir="${TARGET_PATH:-}"
  [[ -n "${backup_dir}" ]] || die "必须通过 --path 指定备份目录"
  [[ -d "${backup_dir}" ]] || die "备份目录不存在：${backup_dir}"
  init_tool_layout_vars

  if ! confirm "将从 ${backup_dir} 恢复配置文件，是否继续？"; then
    die "已取消。"
  fi

  if [[ -f "${backup_dir}/config.conf" ]]; then
    cp -a "${backup_dir}/config.conf" "${CONFIG_FILE}"
    # 恢复后重新加载配置，避免继续使用旧路径或旧服务名
    load_key_value_config "${CONFIG_FILE}" || die "配置文件解析失败：${CONFIG_FILE}"
    normalize_access_model
    init_tool_layout_vars
  fi
  if [[ -f "${backup_dir}/openclaw.json" ]]; then
    mkdir -p "$(dirname "${OPENCLAW_CONFIG_PATH}")"
    cp -a "${backup_dir}/openclaw.json" "${OPENCLAW_CONFIG_PATH}"
  fi
  for governance_name in GOVERNANCE.md ENGINEERING.md DELIVERY.md MEMORY-RULES.md; do
    if [[ -f "${backup_dir}/${governance_name}" ]]; then
      mkdir -p "${OPENCLAW_STATE_DIR}"
      cp -a "${backup_dir}/${governance_name}" "${OPENCLAW_STATE_DIR}/${governance_name}"
    fi
  done
  if [[ -f "${backup_dir}/exec-approvals.json" ]]; then
    mkdir -p "${OPENCLAW_STATE_DIR}"
    cp -a "${backup_dir}/exec-approvals.json" "${OPENCLAW_STATE_DIR}/exec-approvals.json"
  fi
  if [[ -f "${backup_dir}/${SYSTEMD_SERVICE_NAME}.service" ]]; then
    cp -a "${backup_dir}/${SYSTEMD_SERVICE_NAME}.service" "/etc/systemd/system/${SYSTEMD_SERVICE_NAME}.service"
  fi
  if [[ -f "${backup_dir}/nginx-openclaw-site.conf" ]]; then
    cp -a "${backup_dir}/nginx-openclaw-site.conf" "/etc/nginx/sites-available/openclaw"
    ln -sf /etc/nginx/sites-available/openclaw /etc/nginx/sites-enabled/openclaw
  fi
  if [[ -f "${backup_dir}/nginx-openclaw-global.conf" ]]; then
    cp -a "${backup_dir}/nginx-openclaw-global.conf" /etc/nginx/conf.d/openclaw-global.conf
  fi
  systemctl daemon-reload
  if [[ "${ENABLE_NGINX:-0}" == "1" ]] && command -v nginx >/dev/null 2>&1; then
    nginx -t
    systemctl reload nginx
  fi
  restart_service
  log ok "已从备份恢复：${backup_dir}"
}

show_feishu_guide() {
  local service_name="${SYSTEMD_SERVICE_NAME:-openclaw-gateway}"
  cat <<EOF
飞书接入检查清单
================

1. 应用凭据
   - FEISHU_APP_ID
   - FEISHU_APP_SECRET
   - FEISHU_VERIFICATION_TOKEN
   - FEISHU_ENCRYPT_KEY

2. 推荐配置
   - ENABLE_FEISHU=1
   - FEISHU_STREAMING=1
   - FEISHU_DM_POLICY=open 或 pairing
   - FEISHU_REQUIRE_MENTION=0 或 1，按群聊触发策略调整

3. 机器人消息常用权限
   - im:message
   - im:message:readonly
   - im:message.group_msg
   - im:message.group_at_msg:readonly
   - im:message.p2p_msg:readonly
   - im:message:send_as_bot

4. 机器人需要更多联系人信息时，建议额外开启
   - contact:contact.base:readonly

5. 事件订阅需要确认
   - im.message.receive_v1

6. 投递排查
   - 已发布应用版本
   - 机器人已加入目标单聊或群聊
   - 第一次消息慢时，先排查权限、联系人解析和初始化日志

7. 访问模式
   - ACCESS_MODE=standard, PUBLIC_MODE=public-ip: 有公网 IP，无域名
   - ACCESS_MODE=standard, PUBLIC_MODE=public-domain: 有公网 IP，有域名，DOMAIN 和 LETSENCRYPT_EMAIL 必填

8. 流式输出
   - openclaw config set channels.feishu.streaming true
   - systemctl restart ${service_name}
EOF
}

install_action() {
  summarize_config
  run_preflight_checks
  if [[ "${SHOW_GUIDE_ONLY}" == "1" ]]; then
    show_feishu_guide
    return
  fi
  if ! confirm "将执行安装并应用全部配置，是否继续？"; then
    die "已取消。"
  fi
  log info "正在安装系统依赖包"
  apt_install
  log info "正在检查并安装 Node.js"
  install_node_if_missing
  log info "正在安装 OpenClaw"
  install_openclaw
  log info "正在写入 OpenClaw 配置"
  write_openclaw_config
  configure_memory_plugin
  configure_context_engine
  log info "正在安装配置中的插件"
  install_feishu_plugin_if_requested
  install_memory_plugin_if_requested
  install_context_engine_if_requested
  install_configured_plugins
  log info "正在安装配置中的 skills"
  install_skill_dependencies
  install_configured_skills
  log info "正在写入 systemd 服务"
  write_systemd_service
  log info "正在配置 Nginx"
  write_nginx_config
  log info "正在配置 Certbot"
  setup_certbot
  log info "正在配置防火墙"
  setup_firewall
  log info "正在配置 Tailscale"
  setup_tailscale
  configure_tailscale_access
  log info "正在重启网关服务"
  restart_service
  verify_install
  log ok "安装并应用配置完成。"
  if [[ "${ACCESS_MODE:-standard}" =~ ^tailscale- ]]; then
    service_tailscale_summary
  fi
  if [[ "${ENABLE_FEISHU:-0}" == "1" ]]; then
    show_feishu_guide
  fi
}

update_action() {
  summarize_config
  run_preflight_checks
  if ! confirm "将更新 OpenClaw 并重新应用配置，是否继续？"; then
    die "已取消。"
  fi
  apt_install
  install_node_if_missing
  install_openclaw
  write_openclaw_config
  configure_memory_plugin
  configure_context_engine
  install_memory_plugin_if_requested
  install_context_engine_if_requested
  install_feishu_plugin_if_requested
  install_configured_plugins
  install_skill_dependencies
  install_configured_skills
  write_systemd_service
  write_nginx_config
  if [[ "${ENABLE_CERTBOT:-0}" == "1" && -n "${DOMAIN:-}" && ! -f "/etc/letsencrypt/live/${DOMAIN}/fullchain.pem" ]]; then
    setup_certbot
  fi
  setup_firewall
  setup_tailscale
  configure_tailscale_access
  restart_service
  verify_install
  log ok "更新并重放配置完成。"
}

configure_action() {
  summarize_config
  run_preflight_checks
  if [[ "${SHOW_GUIDE_ONLY}" == "1" ]]; then
    show_feishu_guide
    return
  fi
  if ! confirm "将重写配置并重启服务，是否继续？"; then
    die "已取消。"
  fi
  write_openclaw_config
  configure_memory_plugin
  configure_context_engine
  write_systemd_service
  write_nginx_config
  setup_tailscale
  configure_tailscale_access
  restart_service
  verify_install
  log ok "配置已应用。"
}

uninstall_action() {
  init_tool_layout_vars
  log warn "此操作将停止网关服务并移除 systemd / nginx 等系统接入文件。"
  if [[ "${KEEP_DATA}" == "1" ]]; then
    log info "OpenClaw 数据目录将被保留。"
  else
    log warn "OpenClaw 数据目录将被删除：${OPENCLAW_STATE_DIR}"
  fi
  if ! confirm "确认执行卸载吗？"; then
    die "已取消。"
  fi
  systemctl disable --now "${SYSTEMD_SERVICE_NAME}.service" || true
  rm -f "/etc/systemd/system/${SYSTEMD_SERVICE_NAME}.service"
  systemctl daemon-reload
  if [[ "${ENABLE_NGINX:-0}" == "1" ]]; then
    rm -f /etc/nginx/sites-enabled/openclaw /etc/nginx/sites-available/openclaw /etc/nginx/conf.d/openclaw-global.conf
    nginx -t && systemctl reload nginx || true
  fi
  if [[ "${KEEP_DATA}" == "0" ]]; then
    rm -rf "${OPENCLAW_STATE_DIR}"
  fi
  log ok "卸载完成。"
}

skill_install_action() {
  if [[ -n "${TARGET_NAMES}" ]]; then
    log info "将安装指定 skill：${TARGET_NAMES}"
  else
    log info "将按配置安装 skill。"
  fi
  if ! confirm "将安装 skill 及其已知依赖，是否继续？"; then
    die "已取消。"
  fi
  install_skill_dependencies
  install_configured_skills
  log ok "Skill 安装完成。"
}

skill_check_action() {
  local login_state=""
  local specs_csv=""
  local default_status=""
  local clawhub_count="0"
  local git_count="0"
  local dir_count="0"
  local archive_count="0"
  local raw_spec=""
  local normalized=""
  local source=""

  specs_csv="$(resolve_configured_skill_specs_csv)"
  login_state="$(detect_clawhub_login_state)"
  if [[ -n "${SKILL_SPECS:-}" ]]; then
    default_status="已关闭，使用显式 SKILL_SPECS"
  elif [[ "${ENABLE_DEFAULT_SKILLS:-1}" != "1" ]]; then
    default_status="已关闭"
  elif [[ "${login_state}" == "logged-in" ]]; then
    default_status="已启用"
  else
    default_status="待登录后启用"
  fi

  if [[ -n "${specs_csv}" ]]; then
    IFS=',' read -r -a specs <<< "${specs_csv}"
    for raw_spec in "${specs[@]}"; do
      normalized="$(trim_csv_item "${raw_spec}")"
      [[ -z "${normalized}" ]] && continue
      source="$(resolve_skill_spec_source "${normalized}")"
      case "${source}" in
        clawhub) clawhub_count=$((clawhub_count + 1)) ;;
        git) git_count=$((git_count + 1)) ;;
        dir) dir_count=$((dir_count + 1)) ;;
        archive) archive_count=$((archive_count + 1)) ;;
      esac
    done
  fi

  log info "Skill 安装检查"
  print_report_line "默认技能集" "${default_status}"
  print_report_line "SKILL_SPECS" "${specs_csv:-<空>}"
  print_report_line "ClawHub 登录" "${login_state}"
  print_report_line "ClawHub 来源" "${clawhub_count}"
  print_report_line "Git 来源" "${git_count}"
  print_report_line "目录来源" "${dir_count}"
  print_report_line "压缩包来源" "${archive_count}"

  printf '\n'
  log info "建议"
  printf '  1. 如需注册与登录：先打开 https://clawhub.com 注册账号，再执行 `clawhub login`\n'
  printf '  2. 如已有 API token：执行 `clawhub login --token <token>`\n'
  printf '  3. 如持续遇到 429：减少 ClawHub 批量安装，优先改用 git:/dir:/archive:\n'
  printf '  4. 如只想要稳定搜索能力：优先使用官方 Tavily / Firecrawl 集成，而不是社区 skill\n'
}

skill_recommend_action() {
  log info "推荐组合"
  printf '  推荐默认 skills: %s\n' "$(default_skill_specs_csv)"
  printf '  推荐默认 plugins: 飞书用 openclaw-lark；长期记忆用 memory-lancedb-pro；长上下文增强用 lossless-claw\n'
  printf '  推荐搜索能力: 有 Tavily Key 时优先启用官方 Tavily；有 Firecrawl Key 时优先启用官方 Firecrawl\n'
  printf '  推荐发现能力: 安装 `clawhub:find-skill` 后，在对话中让它帮助搜索和筛选技能\n'
  printf '  推荐第三方来源: 对质量较高的 GitHub 技能，优先使用 git: 规格固定仓库与版本\n'
  printf '  默认策略: 未显式设置 SKILL_SPECS 且已登录 ClawHub 时，才自动安装默认技能集\n'
}

config_init_action() {
  local scope="${TARGET_SCOPE:-global}"
  case "${scope}" in
    global)
      config_init_global_action
      ;;
    workspace)
      config_init_workspace_action
      ;;
    *)
      die "未知作用域：${scope}，仅支持 global / workspace"
      ;;
  esac
}

config_apply_action() {
  local section="${TARGET_SECTION:-}"
  case "${section}" in
    access)
      access_apply_action
      ;;
    *)
      die "未知配置分区：${section}，当前仅支持 access"
      ;;
  esac
}

config_show_action() {
  local section="${TARGET_SECTION:-}"
  case "${section}" in
    access)
      access_show_action
      ;;
    *)
      die "未知配置分区：${section}，当前仅支持 access"
      ;;
  esac
}

config_init_global_action() {
  log info "将初始化 OpenClaw 官方状态目录和工具备份目录。"
  if ! confirm "确认初始化 OpenClaw 官方状态目录和工具备份目录吗？"; then
    die "已取消。"
  fi
  ensure_tool_layout
  log info "已准备治理文件：${OPENCLAW_STATE_DIR}/GOVERNANCE.md"
  log info "已准备工程规范：${OPENCLAW_STATE_DIR}/ENGINEERING.md"
  log info "已准备交付检查单：${OPENCLAW_STATE_DIR}/DELIVERY.md"
  log info "已准备记忆规则：${OPENCLAW_STATE_DIR}/MEMORY-RULES.md"
  log ok "OpenClaw 官方状态目录和工具备份目录初始化完成。"
}

config_init_workspace_action() {
  log info "将初始化项目级目录结构。"
  if ! confirm "确认初始化项目级目录结构吗？"; then
    die "已取消。"
  fi
  ensure_tool_layout
  apply_project_layout
  log ok "项目级目录结构初始化完成。"
}

access_apply_action() {
  local level="${TARGET_LEVEL:-${PERMISSIONS_LEVEL:-safe}}"
  local tmp_policy=""
  init_tool_layout_vars
  ensure_tool_layout
  tmp_policy="$(mktemp)"
  trap 'rm -f "${tmp_policy}"' RETURN

  log info "将应用执行权限档位：${level}"
  if ! confirm "确认替换当前执行审批策略吗？"; then
    die "已取消。"
  fi

  write_access_policy "${level}" "${tmp_policy}"
  openclaw approvals set --gateway --file "${tmp_policy}"
  rm -f "${tmp_policy}"
  trap - RETURN
  log ok "执行权限档位已应用：${level}"
}

access_show_action() {
  init_tool_layout_vars
  print_report_line "当前档位" "${PERMISSIONS_LEVEL:-未配置}"
  print_report_line "工具目录" "${OPENCLAW_TOOL_ROOT}"
  print_report_line "备份目录" "${BACKUP_ROOT}"
  openclaw approvals get --gateway
}

plugin_install_action() {
  log info "将按配置安装插件。"
  install_feishu_plugin_if_requested
  install_memory_plugin_if_requested
  install_context_engine_if_requested
  install_configured_plugins
  log ok "插件安装完成。"
}

remove_by_name_list() {
  local mode="$1"
  local name
  local found=0
  local skill_paths=()
  [[ -n "${TARGET_NAMES}" ]] || die "必须通过 --name 指定要移除的名称"
  IFS=',' read -r -a names <<< "${TARGET_NAMES}"
  for name in "${names[@]}"; do
    [[ -z "${name}" ]] && continue
    if [[ "${mode}" == "skill" ]]; then
      skill_paths=(
        "${OPENCLAW_STATE_DIR}/skills/${name}"
        "${OPENCLAW_HOME}/.openclaw/skills/${name}"
        "${OPENCLAW_HOME}/.config/openclaw/skills/${name}"
      )
      found=0
      for skill_path in "${skill_paths[@]}"; do
        if [[ -d "${skill_path}" ]]; then
          rm -rf "${skill_path}"
          log ok "已移除 skill 目录：${skill_path}"
          found=1
        fi
      done
      if [[ "${found}" == "0" ]]; then
        log warn "未找到对应的 skill 目录：${name}"
      fi
    else
      if ! openclaw plugins uninstall "${name}"; then
        log warn "插件卸载失败：${name}"
      else
        log ok "已移除插件：${name}"
      fi
    fi
  done
}

skill_remove_action() {
  if ! confirm "将移除指定 skill，是否继续？"; then
    die "已取消。"
  fi
  remove_by_name_list skill
}

plugin_remove_action() {
  if ! confirm "将移除指定插件，是否继续？"; then
    die "已取消。"
  fi
  remove_by_name_list plugin
}

main() {
  parse_args "$@"
  local action_key
  case "${COMMAND_GROUP}" in
    help|--help|-h)
      action_key="help"
      ;;
    config)
      action_key="config-${COMMAND_ACTION:-}"
      ;;
    service)
      action_key="service-${COMMAND_ACTION:-}"
      ;;
    skill)
      action_key="skill-${COMMAND_ACTION:-}"
      ;;
    plugin)
      action_key="plugin-${COMMAND_ACTION:-}"
      ;;
    feishu)
      action_key="feishu-${COMMAND_ACTION:-}"
      ;;
    *)
      action_key="${COMMAND_GROUP}${COMMAND_ACTION:+-${COMMAND_ACTION}}"
      ;;
  esac

  case "${action_key}" in
    help)
      usage
      ;;
    feishu-guide)
      if [[ -n "${CONFIG_FILE}" ]]; then
        require_config
      fi
      show_feishu_guide
      ;;
    *)
      require_root
      require_config
      ensure_command bash
      case "${action_key}" in
        service-install) install_action ;;
        service-update) update_action ;;
        service-configure) configure_action ;;
        service-diff) service_diff_action ;;
        config-backup) config_backup_action ;;
        config-restore) config_restore_action ;;
        config-init) config_init_action ;;
        config-apply) config_apply_action ;;
        config-show) config_show_action ;;
        service-enable) service_enable_action ;;
        service-disable) service_disable_action ;;
        service-reload) service_reload_action ;;
        service-restart) restart_service ;;
        service-cert) cert_check_action ;;
        service-status) status_action ;;
        service-report) report_action ;;
        service-logs) logs_action ;;
        service-check) check_action ;;
        feishu-check) feishu_check_action ;;
        skill-install) skill_install_action ;;
        skill-remove) skill_remove_action ;;
        skill-check) skill_check_action ;;
        skill-recommend) skill_recommend_action ;;
        plugin-install) plugin_install_action ;;
        plugin-remove) plugin_remove_action ;;
        service-uninstall) uninstall_action ;;
        *) die "未知命令：${COMMAND_GROUP} ${COMMAND_ACTION}" ;;
      esac
      ;;
  esac
}

main "$@"
