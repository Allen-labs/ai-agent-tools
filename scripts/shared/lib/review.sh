#!/usr/bin/env bash

review_run_command() {
  local review_failures_ref="$1"
  local title="$2"
  shift 2
  local output=""

  if output="$("$@" 2>&1)"; then
    log_info "通过：${title}"
    if [[ -n "${output}" ]]; then
      printf '%s\n' "${output}"
    fi
    return 0
  fi

  log_error "失败：${title}"
  [[ -n "${output}" ]] && printf '%s\n' "${output}" >&2
  printf -v "${review_failures_ref}" '%s' "$(( ${!review_failures_ref} + 1 ))"
  return 1
}

review_require_pattern() {
  local review_failures_ref="$1"
  local title="$2"
  local pattern="$3"
  shift 3

  if rg -n --fixed-strings "${pattern}" "$@" >/dev/null 2>&1; then
    log_info "通过：${title}"
    return 0
  fi

  log_error "失败：${title}"
  log_error "未找到关键内容：${pattern}"
  printf -v "${review_failures_ref}" '%s' "$(( ${!review_failures_ref} + 1 ))"
  return 1
}

review_reject_pattern() {
  local review_failures_ref="$1"
  local title="$2"
  local pattern="$3"
  shift 3
  local output=""

  if output="$(rg -n -e "${pattern}" "$@" 2>&1)"; then
    log_error "失败：${title}"
    printf '%s\n' "${output}" >&2
    printf -v "${review_failures_ref}" '%s' "$(( ${!review_failures_ref} + 1 ))"
    return 1
  fi

  log_info "通过：${title}"
  return 0
}

run_repo_review() {
  local repo_root="$1"
  local scripts_root="${repo_root}/scripts"
  local failures=0
  local shell_files=()
  local probe_root="/tmp/ai-agent-tools-review"
  local global_conf_root="${probe_root}/conf"
  local codex_global_conf="${global_conf_root}/codex.conf"
  local claude_global_conf="${global_conf_root}/claude-code.conf"
  local gemini_global_conf="${global_conf_root}/gemini-cli.conf"
  local opencode_global_conf="${global_conf_root}/opencode.conf"
  local review_targets=(
    "${scripts_root}/manage.sh"
    "${scripts_root}/README.md"
    "${scripts_root}/ARCHITECTURE.md"
    "${scripts_root}/TASKS.md"
    "${scripts_root}/shared/lib/common.sh"
    "${scripts_root}/coding-agents/manage.sh"
    "${scripts_root}/coding-agents/README.md"
    "${scripts_root}/coding-agents/codex/manage.sh"
    "${scripts_root}/coding-agents/codex/README.md"
    "${scripts_root}/coding-agents/codex/conf.example"
    "${scripts_root}/coding-agents/claude-code/manage.sh"
    "${scripts_root}/coding-agents/claude-code/README.md"
    "${scripts_root}/coding-agents/claude-code/conf.example"
    "${scripts_root}/coding-agents/gemini-cli/manage.sh"
    "${scripts_root}/coding-agents/gemini-cli/README.md"
    "${scripts_root}/coding-agents/gemini-cli/conf.example"
    "${scripts_root}/coding-agents/opencode/manage.sh"
    "${scripts_root}/coding-agents/opencode/README.md"
    "${scripts_root}/coding-agents/opencode/conf.example"
    "${scripts_root}/general-agents/README.md"
    "${scripts_root}/general-agents/openclaw/manage.sh"
    "${scripts_root}/general-agents/openclaw/README.md"
    "${scripts_root}/general-agents/openclaw/conf.example"
    "${scripts_root}/general-agents/openclaw/lib"
    "${scripts_root}/general-agents/openclaw/bin"
  )

  mapfile -t shell_files < <(find "${scripts_root}" -type f -name '*.sh' | sort)

  print_section "脚本自检"
  log_info "仓库根目录：${repo_root}"

  rm -rf "${probe_root}"
  mkdir -p "${global_conf_root}"
  review_write_isolated_global_conf "${scripts_root}/coding-agents/codex/conf.example" "codex" "${probe_root}" "${codex_global_conf}"
  review_write_isolated_global_conf "${scripts_root}/coding-agents/claude-code/conf.example" "claude-code" "${probe_root}" "${claude_global_conf}"
  review_write_isolated_global_conf "${scripts_root}/coding-agents/gemini-cli/conf.example" "gemini-cli" "${probe_root}" "${gemini_global_conf}"
  review_write_isolated_global_conf "${scripts_root}/coding-agents/opencode/conf.example" "opencode" "${probe_root}" "${opencode_global_conf}"

  review_run_command failures "脚本语法检查" bash -n "${shell_files[@]}"
  review_run_command failures "diff 空白检查" git -C "${repo_root}" diff --check -- README.md scripts general-agents/README.md general-agents/openclaw.md
  review_run_command failures "能力项元信息完整性" bash -lc "source '${scripts_root}/shared/lib/common.sh'; validate_capability_catalog"
  review_run_command failures "根文档结构检查" test -f "${scripts_root}/README.md" -a -f "${scripts_root}/ARCHITECTURE.md" -a -f "${scripts_root}/TASKS.md"
  review_run_command failures "顶层工具列表" bash "${scripts_root}/manage.sh" tool list
  review_run_command failures "顶层快速开始可读性" bash "${scripts_root}/manage.sh" guide start --tool-name codex
  review_run_command failures "OpenClaw 帮助可读性" bash "${scripts_root}/manage.sh" service report --tool-name openclaw --help
  review_run_command failures "Codex 帮助可读性" bash "${scripts_root}/manage.sh" service check --tool-name codex --help
  review_run_command failures "Codex 全局初始化回归" bash -lc "rm -rf '${probe_root}/tool-state/codex' '${probe_root}/global/codex' && bash '${scripts_root}/manage.sh' config init --tool-name codex --config '${codex_global_conf}' --scope global --yes >/dev/null && test -f '${probe_root}/tool-state/codex/config/global/config.toml' && test -f '${probe_root}/tool-state/codex/config/global/AGENTS.md' && test -f '${probe_root}/tool-state/codex/bin/codex-managed' && test -f '${probe_root}/tool-state/codex/manifests/packs.manifest' && test -d '${probe_root}/global/codex/.codex' && test -d '${probe_root}/global/codex/.codex/agents' && test -d '${probe_root}/global/codex/.agents/skills' && test -f '${probe_root}/global/codex/.agents/skills/README.managed.md'"
  review_run_command failures "Claude Code 全局初始化回归" bash -lc "rm -rf '${probe_root}/tool-state/claude-code' '${probe_root}/global/claude-code' && bash '${scripts_root}/manage.sh' config init --tool-name claude-code --config '${claude_global_conf}' --scope global --yes >/dev/null && test -f '${probe_root}/tool-state/claude-code/config/global/settings.json' && test -f '${probe_root}/tool-state/claude-code/config/global/settings.local.json' && test -f '${probe_root}/tool-state/claude-code/config/global/CLAUDE.md' && test -f '${probe_root}/tool-state/claude-code/manifests/plugins.manifest' && test -d '${probe_root}/global/claude-code/.claude' && test -d '${probe_root}/global/claude-code/.claude/plugins' && test -d '${probe_root}/global/claude-code/.claude/skills' && test -d '${probe_root}/global/claude-code/.claude/agents' && test -f '${probe_root}/global/claude-code/.claude/plugins/README.managed.md'"
  review_run_command failures "Gemini CLI 全局初始化回归" bash -lc "rm -rf '${probe_root}/tool-state/gemini-cli' '${probe_root}/global/gemini-cli' && bash '${scripts_root}/manage.sh' config init --tool-name gemini-cli --config '${gemini_global_conf}' --scope global --yes >/dev/null && test -f '${probe_root}/tool-state/gemini-cli/config/global/settings.json' && test -f '${probe_root}/tool-state/gemini-cli/config/global/.env' && test -f '${probe_root}/tool-state/gemini-cli/config/global/GEMINI.md' && test -f '${probe_root}/tool-state/gemini-cli/manifests/plugins.manifest' && test -d '${probe_root}/global/gemini-cli/.gemini' && test -d '${probe_root}/global/gemini-cli/.gemini/skills' && test -d '${probe_root}/global/gemini-cli/.gemini/extensions' && test -d '${probe_root}/global/gemini-cli/.gemini/policies' && test -d '${probe_root}/global/gemini-cli/.gemini/agents' && test -f '${probe_root}/global/gemini-cli/.gemini/extensions/README.managed.md'"
  review_run_command failures "OpenCode 全局初始化回归" bash -lc "rm -rf '${probe_root}/tool-state/opencode' '${probe_root}/global/opencode' && bash '${scripts_root}/manage.sh' config init --tool-name opencode --config '${opencode_global_conf}' --scope global --yes >/dev/null && test -f '${probe_root}/tool-state/opencode/config/global/opencode.json' && test -f '${probe_root}/tool-state/opencode/config/global/AGENTS.md' && test -f '${probe_root}/tool-state/opencode/bin/opencode-managed' && test -f '${probe_root}/tool-state/opencode/manifests/plugins.manifest' && test -d '${probe_root}/global/opencode/.config/opencode' && test -d '${probe_root}/global/opencode/.config/opencode/plugins' && test -d '${probe_root}/global/opencode/.config/opencode/agents' && test -d '${probe_root}/global/opencode/.agents/skills' && test -f '${probe_root}/global/opencode/.config/opencode/plugins/README.managed.md'"
  review_run_command failures "Codex 项目初始化回归" bash -lc "rm -rf '${probe_root}/codex' && bash '${scripts_root}/manage.sh' config init --tool-name codex --config '${scripts_root}/coding-agents/codex/conf.example' --scope project --path '${probe_root}/codex' --yes >/dev/null && test -f '${probe_root}/codex/.agents/project-context.md' && test -f '${probe_root}/codex/.codex/agents/planner.md' && test -f '${probe_root}/codex/.codex/agents/reviewer.md'"
  review_run_command failures "Claude Code 项目初始化回归" bash -lc "rm -rf '${probe_root}/claude-code' && bash '${scripts_root}/manage.sh' config init --tool-name claude-code --config '${scripts_root}/coding-agents/claude-code/conf.example' --scope project --path '${probe_root}/claude-code' --yes >/dev/null && test -f '${probe_root}/claude-code/.agents/checklist.md' && test -f '${probe_root}/claude-code/.claude/agents/planner.md' && test -f '${probe_root}/claude-code/.claude/agents/tester.md'"
  review_run_command failures "Gemini CLI 项目初始化回归" bash -lc "rm -rf '${probe_root}/gemini-cli' && bash '${scripts_root}/manage.sh' config init --tool-name gemini-cli --config '${scripts_root}/coding-agents/gemini-cli/conf.example' --scope project --path '${probe_root}/gemini-cli' --yes >/dev/null && test -f '${probe_root}/gemini-cli/.agents/workflow.md' && test -f '${probe_root}/gemini-cli/.gemini/agents/implementer.md' && test -f '${probe_root}/gemini-cli/.gemini/agents/reviewer.md'"
  review_run_command failures "OpenCode 项目初始化回归" bash -lc "rm -rf '${probe_root}/opencode' && bash '${scripts_root}/manage.sh' config init --tool-name opencode --config '${scripts_root}/coding-agents/opencode/conf.example' --scope project --path '${probe_root}/opencode' --yes >/dev/null && test -f '${probe_root}/opencode/opencode.json' && test -f '${probe_root}/opencode/.opencode/agents/planner.md' && test -f '${probe_root}/opencode/.opencode/agents/tester.md'"
  review_run_command failures "Codex 默认报告回归" bash -lc "output=\"\$(bash '${scripts_root}/manage.sh' service report --tool-name codex --config '${scripts_root}/coding-agents/codex/conf.example')\" && printf '%s\n' \"\${output}\" | rg -q '最佳实践就绪度' && printf '%s\n' \"\${output}\" | rg -q '技能状态' && printf '%s\n' \"\${output}\" | rg -q '核心能力统计' && printf '%s\n' \"\${output}\" | rg -q '能力项统计'"
  review_run_command failures "Claude Code 默认报告回归" bash -lc "output=\"\$(bash '${scripts_root}/manage.sh' service report --tool-name claude-code --config '${scripts_root}/coding-agents/claude-code/conf.example')\" && printf '%s\n' \"\${output}\" | rg -q '最佳实践就绪度' && printf '%s\n' \"\${output}\" | rg -q '插件状态' && printf '%s\n' \"\${output}\" | rg -q '核心能力统计' && printf '%s\n' \"\${output}\" | rg -q '能力项统计'"
  review_run_command failures "Gemini CLI 默认报告回归" bash -lc "output=\"\$(bash '${scripts_root}/manage.sh' service report --tool-name gemini-cli --config '${scripts_root}/coding-agents/gemini-cli/conf.example')\" && printf '%s\n' \"\${output}\" | rg -q '最佳实践就绪度' && printf '%s\n' \"\${output}\" | rg -q '扩展状态' && printf '%s\n' \"\${output}\" | rg -q '核心能力统计' && printf '%s\n' \"\${output}\" | rg -q '能力项统计'"
  review_run_command failures "OpenCode 默认报告回归" bash -lc "output=\"\$(bash '${scripts_root}/manage.sh' service report --tool-name opencode --config '${scripts_root}/coding-agents/opencode/conf.example')\" && printf '%s\n' \"\${output}\" | rg -q '最佳实践就绪度' && printf '%s\n' \"\${output}\" | rg -q '插件状态' && printf '%s\n' \"\${output}\" | rg -q '核心能力统计' && printf '%s\n' \"\${output}\" | rg -q '能力项统计'"
  review_run_command failures "OpenCode 项目配置包含 checklist 指令" rg -n --fixed-strings "./.agents/checklist.md" "${probe_root}/opencode/opencode.json"
  review_run_command failures "Coding Agents 默认基线说明" rg -n --fixed-strings "common-core + common-docs-architecture + common-quality + common-backend + common-frontend" "${scripts_root}/README.md" "${scripts_root}/coding-agents/README.md" "${scripts_root}/ARCHITECTURE.md"

  review_require_pattern failures "顶层入口暴露 review 命令" "tool review" "${scripts_root}/manage.sh" "${scripts_root}/README.md"
  review_require_pattern failures "README 声明三份主文档" "根目录主文档只保留三份" "${scripts_root}/README.md"
  review_require_pattern failures "Coding Agents 文档声明工具目录模型" "工具侧生成的备份、清单、包装命令统一落在各自工具目录" "${scripts_root}/coding-agents/README.md"
  review_require_pattern failures "OpenClaw 文档声明官方目录模型" "全局层遵循 OpenClaw 官方目录" "${scripts_root}/general-agents/openclaw/README.md"

  review_reject_pattern failures "禁止旧的受管目录概念" '受管目录|受管 env|受管 wrapper|MANAGED_ROOT|PROJECTS_ROOT|MANAGED_' "${review_targets[@]}" "${repo_root}/README.md"
  review_reject_pattern failures "禁止旧的 sync 命令残留" 'skill sync|plugin sync' "${review_targets[@]}" "${repo_root}/README.md"
  review_reject_pattern failures "禁止错误的 tool run 命令风格" 'tool run' "${review_targets[@]}" "${repo_root}/README.md"
  review_reject_pattern failures "禁止旧的顶层运行目录路径" '/root/codex|/root/claude-code|/root/gemini-cli|/root/opencode' "${review_targets[@]}" "${repo_root}/README.md"
  review_reject_pattern failures "禁止旧的 doctor 命名" 'service doctor|skill doctor' "${review_targets[@]}" "${repo_root}/README.md"
  review_reject_pattern failures "禁止旧的 .runtime 路径概念" '\.runtime/coding-agents' "${scripts_root}/README.md" "${scripts_root}/ARCHITECTURE.md" "${scripts_root}/TASKS.md" "${scripts_root}/coding-agents/README.md" "${scripts_root}/coding-agents/codex/README.md" "${scripts_root}/coding-agents/claude-code/README.md" "${scripts_root}/coding-agents/gemini-cli/README.md" "${scripts_root}/coding-agents/opencode/README.md"

  if [[ "${failures}" -ne 0 ]]; then
    log_error "脚本自检失败，共 ${failures} 项。"
    return 1
  fi

  log_info "脚本自检通过。"
}

review_write_isolated_global_conf() {
  local base_conf="$1"
  local tool_name="$2"
  local probe_root="$3"
  local output_conf="$4"
  local tool_probe_root="${probe_root}/global/${tool_name}"

  mkdir -p "$(dirname "${output_conf}")" "${tool_probe_root}"
  cp "${base_conf}" "${output_conf}"

  case "${tool_name}" in
    codex)
      cat >> "${output_conf}" <<EOF

GLOBAL_CODEX_DIR=${tool_probe_root}/.codex
GLOBAL_AGENTS_DIR=${tool_probe_root}/.agents
GLOBAL_CONFIG_PATH=${tool_probe_root}/.codex/config.toml
GLOBAL_HOOKS_PATH=${tool_probe_root}/.codex/hooks.json
GLOBAL_AGENTS_DOC_PATH=${tool_probe_root}/.codex/AGENTS.md
GLOBAL_USER_SKILLS_DIR=${tool_probe_root}/.agents/skills
GLOBAL_CODEX_AGENTS_DIR=${tool_probe_root}/.codex/agents
TOOL_RUNTIME_ROOT=${probe_root}/tool-state/codex
EOF
      ;;
    claude-code)
      cat >> "${output_conf}" <<EOF

GLOBAL_CLAUDE_DIR=${tool_probe_root}/.claude
GLOBAL_SETTINGS_PATH=${tool_probe_root}/.claude/settings.json
GLOBAL_SETTINGS_LOCAL_PATH=${tool_probe_root}/.claude/settings.local.json
GLOBAL_CLAUDE_MD_PATH=${tool_probe_root}/.claude/CLAUDE.md
GLOBAL_PLUGINS_DIR=${tool_probe_root}/.claude/plugins
GLOBAL_SKILLS_DIR=${tool_probe_root}/.claude/skills
GLOBAL_AGENTS_DIR=${tool_probe_root}/.claude/agents
GLOBAL_SESSION_PATH=${tool_probe_root}/.claude.json
TOOL_RUNTIME_ROOT=${probe_root}/tool-state/claude-code
EOF
      ;;
    gemini-cli)
      cat >> "${output_conf}" <<EOF

GLOBAL_GEMINI_DIR=${tool_probe_root}/.gemini
GLOBAL_SETTINGS_PATH=${tool_probe_root}/.gemini/settings.json
GLOBAL_ENV_PATH=${tool_probe_root}/.gemini/.env
GLOBAL_MEMORY_PATH=${tool_probe_root}/.gemini/GEMINI.md
GLOBAL_SKILLS_DIR=${tool_probe_root}/.gemini/skills
GLOBAL_EXTENSIONS_DIR=${tool_probe_root}/.gemini/extensions
GLOBAL_POLICIES_DIR=${tool_probe_root}/.gemini/policies
GLOBAL_AGENTS_DIR=${tool_probe_root}/.gemini/agents
TOOL_RUNTIME_ROOT=${probe_root}/tool-state/gemini-cli
EOF
      ;;
    opencode)
      cat >> "${output_conf}" <<EOF

GLOBAL_OPENCODE_DIR=${tool_probe_root}/.config/opencode
GLOBAL_CONFIG_PATH=${tool_probe_root}/.config/opencode/opencode.json
GLOBAL_AGENTS_PATH=${tool_probe_root}/.config/opencode/AGENTS.md
GLOBAL_AGENTS_DIR=${tool_probe_root}/.config/opencode/agents
GLOBAL_PLUGINS_DIR=${tool_probe_root}/.config/opencode/plugins
GLOBAL_PLUGIN_CACHE_DIR=${tool_probe_root}/.cache/opencode/node_modules
GLOBAL_SKILLS_DIR=${tool_probe_root}/.agents/skills
TOOL_RUNTIME_ROOT=${probe_root}/tool-state/opencode
EOF
      ;;
    *)
      return 1
      ;;
  esac
}
