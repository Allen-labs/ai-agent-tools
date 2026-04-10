#!/usr/bin/env bash

run_preflight_checks() {
  local errors=0

  if [[ "${ACCESS_MODE:-standard}" == "standard" && "${ENABLE_NGINX:-0}" == "1" && -z "${DOMAIN:-}" && "${PUBLIC_MODE:-public-domain}" == "public-domain" ]]; then
    log err "已开启 Nginx，但未填写 DOMAIN"
    errors=1
  fi
  if [[ "${ACCESS_MODE:-standard}" == "standard" && "${ENABLE_CERTBOT:-0}" == "1" && -z "${LETSENCRYPT_EMAIL:-}" ]]; then
    log err "已开启 Certbot，但未填写 LETSENCRYPT_EMAIL"
    errors=1
  fi
  if [[ "${ACCESS_MODE:-standard}" =~ ^tailscale- ]]; then
    [[ -n "${TAILSCALE_AUTH_KEY:-}" ]] || { log err "已启用 Tailscale 模式，但未填写 TAILSCALE_AUTH_KEY"; errors=1; }
    [[ -n "${TAILSCALE_HOSTNAME:-}" ]] || { log err "已启用 Tailscale 模式，但未填写 TAILSCALE_HOSTNAME"; errors=1; }
  fi
  if [[ "${ENABLE_FEISHU:-0}" == "1" ]]; then
    [[ -n "${FEISHU_APP_ID:-}" ]] || { log err "已开启飞书，但未填写 FEISHU_APP_ID"; errors=1; }
    [[ -n "${FEISHU_APP_SECRET:-}" ]] || { log err "已开启飞书，但未填写 FEISHU_APP_SECRET"; errors=1; }
    [[ -n "${FEISHU_VERIFICATION_TOKEN:-}" ]] || { log err "已开启飞书，但未填写 FEISHU_VERIFICATION_TOKEN"; errors=1; }
    [[ -n "${FEISHU_ENCRYPT_KEY:-}" ]] || { log err "已开启飞书，但未填写 FEISHU_ENCRYPT_KEY"; errors=1; }
  fi
  if [[ "${ENABLE_MEMORY_PLUGIN:-0}" == "1" ]]; then
    [[ -n "${MEMORY_PLUGIN:-}" ]] || { log err "已开启长期记忆插件，但未填写 MEMORY_PLUGIN"; errors=1; }
    [[ -n "${MEMORY_EMBEDDING_API_KEY:-}" ]] || { log err "已开启长期记忆插件，但未填写 MEMORY_EMBEDDING_API_KEY"; errors=1; }
  fi
  if [[ "${ENABLE_CONTEXT_ENGINE:-0}" == "1" ]]; then
    [[ -n "${CONTEXT_ENGINE:-}" ]] || { log err "已开启上下文引擎，但未填写 CONTEXT_ENGINE"; errors=1; }
  fi
  if [[ "${errors}" != "0" ]]; then
    die "前置检查失败，请先补齐缺失配置。"
  fi
}

sandbox_network_restricted() {
  case "${OPENCLAW_LOCAL_PROBE_MODE:-auto}" in
    force)
      return 1
      ;;
    skip)
      return 0
      ;;
  esac
  [[ "${CODEX_SANDBOX_NETWORK_DISABLED:-0}" == "1" ]]
}

sandbox_system_restricted() {
  [[ "${CODEX_CI:-0}" == "1" ]]
}

display_toggle_state() {
  local enabled="${1:-0}"
  local enabled_label="${2:-开启}"
  local disabled_label="${3:-关闭}"

  if [[ "${enabled}" == "1" ]]; then
    printf '%s' "${enabled_label}"
  else
    printf '%s' "${disabled_label}"
  fi
}

display_named_toggle_state() {
  local enabled="${1:-0}"
  local name="${2:-}"
  local enabled_prefix="${3:-开启}"
  local disabled_prefix="${4:-关闭}"

  if [[ "${enabled}" == "1" ]]; then
    if [[ -n "${name}" && "${name}" != "none" ]]; then
      printf '%s（%s）' "${enabled_prefix}" "${name}"
    else
      printf '%s' "${enabled_prefix}"
    fi
  else
    if [[ -n "${name}" && "${name}" != "none" ]]; then
      printf '%s（目标：%s）' "${disabled_prefix}" "${name}"
    else
      printf '%s' "${disabled_prefix}"
    fi
  fi
}

normalize_report_state() {
  case "${1:-}" in
    ok)
      printf '正常'
      ;;
    missing)
      printf '缺失'
      ;;
    present)
      printf '已存在'
      ;;
    issued)
      printf '已签发'
      ;;
    disabled)
      printf '未启用'
      ;;
    "unknown(permission)")
      printf '当前环境无法检测（权限受限）'
      ;;
    "restricted(sandbox-network)")
      printf '当前环境无法探测（沙箱网络受限）'
      ;;
    *)
      printf '%s' "${1:-}"
      ;;
  esac
}

command_needs_gateway_socket() {
  local argv=("$@")

  [[ "${#argv[@]}" -gt 0 ]] || return 1
  [[ "${argv[0]}" == "openclaw" ]] || return 1

  case "${argv[1]:-} ${argv[2]:-} ${argv[3]:-}" in
    "gateway probe "|\
    "health  "|\
    "memory status "|\
    "approvals get --gateway")
      return 0
      ;;
  esac

  return 1
}

systemd_unit_state() {
  local unit_name="$1"
  local output=""

  output="$(systemctl is-active "${unit_name}" 2>&1 || true)"
  case "${output}" in
    active|activating|inactive|failed|deactivating)
      printf '%s\n' "${output}"
      ;;
    *"Failed to connect to bus"*|*"Operation not permitted"*)
      printf '%s\n' "unknown(permission)"
      ;;
    *"could not be found"*|*"not-found"*)
      printf '%s\n' "missing"
      ;;
    *)
      printf '%s\n' "unknown"
      ;;
  esac
}

probe_openclaw_command() {
  local timeout_seconds="$1"
  shift
  local output=""

  if sandbox_network_restricted && command_needs_gateway_socket "$@"; then
    printf '%s\n' "restricted(sandbox-network)"
    return
  fi

  if command -v timeout >/dev/null 2>&1; then
    output="$(timeout "${timeout_seconds}" "$@" 2>&1)" && {
      printf '%s\n' "ok"
      return
    }
    case "$?" in
      124|137)
        printf '%s\n' "timeout"
        ;;
      *)
        if grep -qiE "Failed to connect to bus|Operation not permitted" <<< "${output}"; then
          printf '%s\n' "unknown(permission)"
        elif grep -qiE "gateway closed|abnormal closure|1006" <<< "${output}"; then
          printf '%s\n' "gateway-closed"
        elif grep -qiE "ECONNREFUSED|connection refused|Reachable:[[:space:]]*no" <<< "${output}"; then
          printf '%s\n' "unreachable"
        elif grep -qiE "401|403|unauthorized|forbidden|auth failed" <<< "${output}"; then
          printf '%s\n' "unauthorized"
        elif grep -qiE "disabled|not enabled|memory plugin is off|memory is disabled" <<< "${output}"; then
          printf '%s\n' "disabled"
        else
          printf '%s\n' "check-failed"
        fi
        ;;
    esac
    return
  fi

  if "$@" >/dev/null 2>&1; then
    printf '%s\n' "ok"
  else
    printf '%s\n' "check-failed"
  fi
}

run_diagnostic_with_timeout() {
  local timeout_seconds="$1"
  shift

  if sandbox_network_restricted && command_needs_gateway_socket "$@"; then
    log warn "当前执行环境禁用了本机网络探测，跳过：$*"
    return 0
  fi

  if command -v timeout >/dev/null 2>&1; then
    timeout "${timeout_seconds}" "$@" || true
  else
    "$@" || true
  fi
}

render_deploy_report() {
  local service_state="unknown"
  local nginx_state="disabled"
  local cert_state="disabled"
  local gateway_probe_state="unknown"
  local health_state="unknown"
  local memory_state="unknown"
  local backup_root=""
  local permissions_level="${PERMISSIONS_LEVEL:-unknown}"
  local approvals_state="missing"
  local access_entry="${DOMAIN:-<无>}"
  local tailscale_state="disabled"
  local governance_state="0/4"
  local probe_timeout="${OPENCLAW_REPORT_PROBE_TIMEOUT:-15}"

  if declare -F init_tool_layout_vars >/dev/null 2>&1; then
    init_tool_layout_vars
    backup_root="${BACKUP_ROOT}"
  fi

  service_state="$(systemd_unit_state "${SYSTEMD_SERVICE_NAME}.service")"

  if [[ "${ENABLE_NGINX:-0}" == "1" ]]; then
    nginx_state="$(systemd_unit_state "nginx.service")"
  fi

  if [[ "${ENABLE_CERTBOT:-0}" == "1" ]]; then
    if [[ -n "${DOMAIN:-}" && -f "/etc/letsencrypt/live/${DOMAIN}/fullchain.pem" ]]; then
      cert_state="issued"
    else
      cert_state="missing"
    fi
  fi

  if [[ "${ACCESS_MODE:-standard}" =~ ^tailscale- ]]; then
    tailscale_state="$(check_path_command tailscale)"
    access_entry="${TAILSCALE_HOSTNAME:-<无>}"
  fi

  gateway_probe_state="$(probe_openclaw_command "${probe_timeout}" openclaw gateway probe)"
  health_state="$(probe_openclaw_command "${probe_timeout}" openclaw health)"
  if [[ "${ENABLE_MEMORY_PLUGIN:-0}" == "1" ]]; then
    memory_state="$(probe_openclaw_command "${probe_timeout}" openclaw memory status)"
  else
    memory_state="disabled"
  fi

  if [[ -f "${OPENCLAW_STATE_DIR}/exec-approvals.json" ]]; then
    approvals_state="present"
  fi
  if declare -F openclaw_governance_state >/dev/null 2>&1; then
    governance_state="$(openclaw_governance_state)"
  fi

  log info "部署健康报告"
  print_report_line "访问模式" "${ACCESS_MODE:-standard}"
  print_report_line "访问入口" "${access_entry}"
  print_report_line "网关服务" "$(normalize_report_state "${service_state}")"
  print_report_line "网关端口" "${GATEWAY_PORT}"
  print_report_line "UI 域名" "${DOMAIN:-<无>}"
  print_report_line "Tailscale" "$(normalize_report_state "${tailscale_state}")"
  print_report_line "Nginx" "$(normalize_report_state "${nginx_state}")"
  print_report_line "证书" "$(normalize_report_state "${cert_state}")"
  print_report_line "UFW 命令" "$(normalize_report_state "$(check_path_command ufw)")"
  print_report_line "Node 命令" "$(normalize_report_state "$(check_path_command node)")"
  print_report_line "OpenClaw 命令" "$(normalize_report_state "$(check_path_command openclaw)")"
  print_report_line "飞书接入" "$(display_toggle_state "${ENABLE_FEISHU:-0}")"
  print_report_line "飞书流式输出" "$(display_toggle_state "${FEISHU_STREAMING:-1}")"
  print_report_line "备份目录" "${backup_root:-${BACKUP_ROOT:-<未配置>}}"
  print_report_line "治理文件" "${OPENCLAW_STATE_DIR} (${governance_state})"
  print_report_line "权限档位" "${permissions_level}"
  print_report_line "审批文件" "$(normalize_report_state "${approvals_state}")"
  print_report_line "长期记忆插件" "$(display_named_toggle_state "${ENABLE_MEMORY_PLUGIN:-0}" "${MEMORY_PLUGIN:-none}")"
  print_report_line "上下文引擎" "$(display_named_toggle_state "${ENABLE_CONTEXT_ENGINE:-0}" "${CONTEXT_ENGINE:-none}")"
  if sandbox_network_restricted; then
    print_report_line "本机探测限制" "当前环境禁用本机网络，gateway/health 结果仅供参考"
  fi
  print_report_line "网关探测" "$(normalize_report_state "${gateway_probe_state}")"
  print_report_line "健康检查" "$(normalize_report_state "${health_state}")"
  print_report_line "记忆状态" "$(normalize_report_state "${memory_state}")"
}

status_action() {
  render_deploy_report
  printf '\n'
  log info "systemd 服务详情"
  systemctl status "${SYSTEMD_SERVICE_NAME}.service" --no-pager || true
}

check_action() {
  render_deploy_report
  printf '\n'
  log info "开始执行检查"
  if declare -F openclaw_governance_ready >/dev/null 2>&1 && ! openclaw_governance_ready; then
    log warn "OpenClaw 官方目录治理文件未补齐，建议先执行 bash manage.sh config init --tool-name openclaw --config <config> --scope global"
  fi
  run_preflight_checks
  if sandbox_network_restricted; then
    log warn "检测到当前环境禁用了本机网络访问，gateway/health/approvals 检查将自动跳过。"
  fi
  run_diagnostic_with_timeout 15 openclaw config validate
  run_diagnostic_with_timeout 15 openclaw health
  run_diagnostic_with_timeout 15 openclaw gateway probe
  run_diagnostic_with_timeout 15 openclaw plugins doctor
  run_diagnostic_with_timeout 15 openclaw skills list
  if [[ "${ENABLE_MEMORY_PLUGIN:-0}" == "1" ]]; then
    run_diagnostic_with_timeout 15 openclaw memory status
  else
    log info "长期记忆插件未启用，跳过 memory status 检查"
  fi
  if [[ -f "${OPENCLAW_STATE_DIR}/exec-approvals.json" ]]; then
    run_diagnostic_with_timeout 15 openclaw approvals get --gateway
  fi
  if [[ "${ENABLE_NGINX:-0}" == "1" ]]; then
    if sandbox_system_restricted; then
      log warn "当前执行环境限制系统级校验，跳过：nginx -t"
    else
      nginx -t
    fi
  fi
  if [[ "${ACCESS_MODE:-standard}" =~ ^tailscale- ]] && command -v tailscale >/dev/null 2>&1; then
    run_diagnostic_with_timeout 15 tailscale status
    run_diagnostic_with_timeout 15 tailscale serve status
  fi
}

report_action() {
  run_preflight_checks
  render_deploy_report
}

logs_action() {
  journalctl -u "${SYSTEMD_SERVICE_NAME}.service" -n 100 --no-pager
}

cert_check_action() {
  local cert_path=""
  local key_path=""
  local end_date=""

  log info "证书检查"
  if [[ "${ACCESS_MODE:-standard}" != "standard" ]]; then
    print_report_line "证书" "当前访问模式不使用公网证书"
    return
  fi
  if [[ "${ENABLE_CERTBOT:-0}" != "1" ]]; then
    print_report_line "Certbot" "未启用"
    return
  fi
  [[ -n "${DOMAIN:-}" ]] || die "证书检查失败：未填写 DOMAIN"

  cert_path="/etc/letsencrypt/live/${DOMAIN}/fullchain.pem"
  key_path="/etc/letsencrypt/live/${DOMAIN}/privkey.pem"
  print_report_line "域名" "${DOMAIN:-<无>}"
  print_report_line "证书文件" "$([[ -f "${cert_path}" ]] && echo 存在 || echo 缺失)"
  print_report_line "私钥文件" "$([[ -f "${key_path}" ]] && echo 存在 || echo 缺失)"
  print_report_line "certbot 命令" "$(check_path_command certbot)"

  if [[ -f "${cert_path}" ]] && command -v openssl >/dev/null 2>&1; then
    end_date="$(openssl x509 -enddate -noout -in "${cert_path}" 2>/dev/null | cut -d= -f2- || true)"
    print_report_line "证书到期时间" "${end_date:-未知}"
  fi
}

feishu_check_action() {
  log info "飞书接入检查"
  print_report_line "飞书启用" "${ENABLE_FEISHU:-0}"
  print_report_line "App ID" "$(sensitive_presence_display_value "${FEISHU_APP_ID:-}")"
  print_report_line "App Secret" "$(sensitive_presence_display_value "${FEISHU_APP_SECRET:-}")"
  print_report_line "Verification Token" "$(sensitive_presence_display_value "${FEISHU_VERIFICATION_TOKEN:-}")"
  print_report_line "Encrypt Key" "$(sensitive_presence_display_value "${FEISHU_ENCRYPT_KEY:-}")"
  print_report_line "Require Mention" "${FEISHU_REQUIRE_MENTION:-0}"
  print_report_line "DM Policy" "${FEISHU_DM_POLICY:-open}"
  print_report_line "Streaming" "${FEISHU_STREAMING:-1}"
  print_report_line "飞书插件包" "${OPENCLAW_LARK_PACKAGE:-<未指定>}"

  if [[ -f "${OPENCLAW_CONFIG_PATH}" ]]; then
    print_report_line "线上 channels.feishu" "$(jq -r '.channels.feishu.enabled // "未配置"' "${OPENCLAW_CONFIG_PATH}" 2>/dev/null || echo 未知)"
    print_report_line "线上 streaming" "$(jq -r '.channels.feishu.streaming // "未配置"' "${OPENCLAW_CONFIG_PATH}" 2>/dev/null || echo 未知)"
  fi

  printf '\n'
  log info "建议核对的飞书平台项"
  echo "  1. 已发布应用版本"
  echo "  2. 已订阅事件：im.message.receive_v1"
  echo "  3. 已开权限：im:message / im:message:readonly / im:message:send_as_bot / im:message.group_msg / im:message.group_at_msg:readonly / im:message.p2p_msg:readonly"
  echo "  4. 如需联系人解析，已开：contact:contact.base:readonly"
}
