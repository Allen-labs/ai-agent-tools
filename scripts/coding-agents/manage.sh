#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# coding-agents 总入口只做路由，日志和错误提示统一走公共库。
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../shared/lib/common.sh"
PROGRAM_NAME="$(basename "$0")"
COMMAND_GROUP="${1:-help}"
COMMAND_ACTION="${2:-}"
TARGET_TOOL=""
FORWARD_ARGS=()

usage() {
  help_init_colors
  help_print_title "Coding Agents 统一管理工具"
  help_print_strong_rule
  help_print_context "已接入" "claude-code | codex | gemini-cli | opencode"
  help_print_context "主入口" "${PROGRAM_NAME}"

  help_print_section "主命令"
  help_print_rule
  help_print_entry "service install" "首次安装"
  help_print_entry "service configure" "增强 / 接管"
  help_print_entry "config init" "初始化模板"
  help_print_entry "service report" "状态概览"
  help_print_entry "service check" "详细检查"
  help_print_entry "tool list" "工具列表"

  help_print_section "全局参数"
  help_print_rule
  help_print_entry "--tool-name <tool>" "工具名"
  help_print_entry "--config <config>" "配置文件"
  help_print_entry "--scope <scope>" "global|project"
  help_print_entry "--path <path>" "项目路径"
  help_print_entry "--yes" "跳过确认"

  help_print_section "快速上手"
  help_print_rule
  help_print_step "1" "${PROGRAM_NAME} service install --tool-name codex --config ./codex/local.conf --yes"
  help_print_step "2" "${PROGRAM_NAME} service check --tool-name codex --config ./codex/local.conf"

  help_print_section "常见场景"
  help_print_rule
  help_print_case "首次安装" "${PROGRAM_NAME} service install --tool-name codex --config ./codex/local.conf --yes"
  help_print_case "已装增强 / 接管" "${PROGRAM_NAME} service configure --tool-name codex --config ./codex/local.conf --yes"
  help_print_case "项目模板" "${PROGRAM_NAME} config init --tool-name codex --config ./codex/local.conf --scope project --path /workspace/project --yes"
  help_print_case "查看状态" "${PROGRAM_NAME} service report --tool-name codex --config ./codex/local.conf"

  help_print_section "按需能力"
  help_print_rule
  help_print_entry "tool list" "查看工具"
  help_print_entry "guide start" "最短路径"
  help_print_entry "详细帮助" "bash manage.sh service check --tool-name codex --help"
}

resolve_tool_entry() {
  case "${1}" in
    claude-code|codex|gemini-cli|opencode)
      printf '%s\n' "${SCRIPT_DIR}/${1}/manage.sh"
      ;;
    *)
      return 1
      ;;
  esac
}

list_tools() {
  cat <<EOF
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

if [[ "${COMMAND_GROUP}" == "tool" && "${COMMAND_ACTION}" == "list" ]]; then
  list_tools
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
  log_error "不支持的 coding agent 工具：${TARGET_TOOL}"
  print_section "可用工具"
  list_tools
  exit 1
}

log_info "转发到 coding agent 工具：${TARGET_TOOL}"
exec bash "${TARGET_ENTRY}" "${COMMAND_GROUP}" "${COMMAND_ACTION}" "${FORWARD_ARGS[@]}"
