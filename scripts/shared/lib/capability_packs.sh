#!/usr/bin/env bash

capability_pack_catalog() {
  cat <<'EOF'
coding|common-core|skill|plan-task
coding|common-core|skill|implement-task
coding|common-core|skill|code-review
coding|common-core|skill|refactor-safely
coding|common-core|hook|dangerous-command-guard
coding|common-core|hook|format-after-edit
coding|common-core|mcp|github
coding|common-core|mcp|context7
coding|common-core|agent|planner
coding|common-core|agent|reviewer
coding|common-docs-architecture|skill|architecture-review
coding|common-docs-architecture|skill|write-docs
coding|common-docs-architecture|skill|release-notes
coding|common-docs-architecture|hook|session-summary-memory
coding|common-docs-architecture|mcp|filesystem
coding|common-docs-architecture|mcp|fetch
coding|common-docs-architecture|agent|docs
coding|common-frontend|skill|frontend-design
coding|common-frontend|hook|targeted-test-after-edit
coding|common-frontend|mcp|playwright
coding|common-frontend|agent|frontend
coding|common-backend|skill|api-design
coding|common-backend|skill|regression-triage
coding|common-backend|agent|backend
coding|common-quality|skill|security-review
coding|common-quality|skill|test-generation
coding|common-quality|hook|test-after-edit
coding|common-quality|agent|tester
coding|common-quality|agent|security
claude-code|claude-workflow|plugin|hookify
claude-code|claude-review|plugin|code-review
claude-code|claude-review|plugin|github
claude-code|claude-review|plugin|context7
claude-code|claude-ecosystem|plugin|superpowers
claude-code|claude-ecosystem|plugin|claude-code-setup
claude-code|claude-ecosystem|plugin|security-guidance
claude-code|claude-ui|plugin|frontend-design
claude-code|claude-ui|plugin|figma
claude-code|claude-ui|plugin|playwright
claude-code|claude-memory|plugin|claude-mem
claude-code|claude-memory|plugin|code-simplifier
claude-code|claude-memory|agent|memory-curator
codex|codex-core|skill|gh-fix-ci
codex|codex-core|skill|gh-address-comments
codex|codex-review|skill|security-threat-model
codex|codex-review|agent|reviewer
codex|codex-review|agent|tester
codex|codex-ecosystem|skill|security-best-practices
codex|codex-ecosystem|skill|doc
codex|codex-frontend|skill|frontend-skill
codex|codex-frontend|skill|figma
codex|codex-frontend|skill|figma-use
codex|codex-frontend|skill|figma-implement-design
codex|codex-research|skill|notion-spec-to-implementation
codex|codex-research|skill|notion-research-documentation
gemini-cli|gemini-core|plugin|conductor
gemini-cli|gemini-core|plugin|code-review
gemini-cli|gemini-core|plugin|security
gemini-cli|gemini-collaboration|plugin|jules
gemini-cli|gemini-collaboration|plugin|workspace
gemini-cli|gemini-collaboration|agent|planner
gemini-cli|gemini-collaboration|agent|reviewer
gemini-cli|gemini-ui|plugin|stitch
gemini-cli|gemini-ui|plugin|flutter
gemini-cli|gemini-data|plugin|cloud-sql-postgresql
gemini-cli|gemini-data|plugin|bigquery-data-analytics
opencode|opencode-core|plugin|opencode-skillful
opencode|opencode-core|plugin|opencode-shell-strategy
opencode|opencode-core|plugin|opencode-vibeguard
opencode|opencode-workspace|plugin|opencode-workspace
opencode|opencode-workspace|plugin|opencode-worktree
opencode|opencode-workspace|agent|planner
opencode|opencode-workspace|agent|reviewer
opencode|opencode-automation|plugin|opencode-background-agents
opencode|opencode-memory|plugin|opencode-supermemory
opencode|opencode-memory|plugin|opencode-dynamic-context-pruning
opencode|opencode-memory|plugin|opencode-websearch-cited
opencode|opencode-safety|plugin|opencode-firecrawl
opencode|opencode-safety|plugin|opencode-devcontainers
opencode|opencode-safety|agent|security
coding|enhanced-browser-deep|plugin|browser-use
coding|enhanced-browser-deep|plugin|firecrawl
coding|enhanced-browser-deep|mcp|chrome-devtools
coding|enhanced-browser-deep|mcp|firecrawl
coding|enhanced-long-memory|plugin|long-memory
coding|enhanced-long-memory|plugin|memory-sync
coding|enhanced-long-memory|agent|memory-curator
coding|enhanced-data-platform|mcp|postgres
coding|enhanced-data-platform|mcp|redis
coding|enhanced-data-platform|mcp|sqlite
coding|enhanced-background-agents|plugin|proactive-agent
coding|enhanced-background-agents|agent|background-orchestrator
coding|enhanced-background-agents|agent|cron-automation
coding|enhanced-observability|skill|incident-triage
coding|enhanced-observability|mcp|sentry
coding|enhanced-observability|mcp|grafana
coding|experimental-bleeding-edge|plugin|bleeding-edge-labs
coding|experimental-bleeding-edge|agent|speculative-worker
EOF
}

capability_item_catalog() {
  cat <<'EOF'
coding|skill|plan-task|tool-ecosystem|skill-dir|low
coding|skill|implement-task|tool-ecosystem|skill-dir|low
coding|skill|code-review|tool-ecosystem|skill-dir|medium
coding|skill|refactor-safely|tool-ecosystem|skill-dir|medium
coding|skill|architecture-review|tool-ecosystem|skill-dir|low
coding|skill|write-docs|tool-ecosystem|skill-dir|low
coding|skill|release-notes|tool-ecosystem|skill-dir|low
coding|skill|frontend-design|tool-ecosystem|skill-dir|low
coding|skill|ui-ux-pro-max|third-party|skill-dir|medium
coding|skill|api-design|tool-ecosystem|skill-dir|low
coding|skill|regression-triage|tool-ecosystem|skill-dir|medium
coding|skill|security-review|tool-ecosystem|skill-dir|medium
coding|skill|test-generation|tool-ecosystem|skill-dir|medium
coding|skill|incident-triage|tool-ecosystem|skill-dir|medium
coding|hook|dangerous-command-guard|managed-template|hook-template|low
coding|hook|format-after-edit|managed-template|hook-template|low
coding|hook|session-summary-memory|managed-template|hook-template|low
coding|hook|targeted-test-after-edit|managed-template|hook-template|low
coding|hook|test-after-edit|managed-template|hook-template|medium
coding|mcp|github|external-service|mcp-config|medium
coding|mcp|context7|external-service|mcp-config|medium
coding|mcp|filesystem|external-service|mcp-config|low
coding|mcp|fetch|external-service|mcp-config|low
coding|mcp|figma|external-service|mcp-config|medium
coding|mcp|playwright|external-service|mcp-config|medium
coding|mcp|chrome-devtools|external-service|mcp-config|medium
coding|mcp|firecrawl|external-service|mcp-config|medium
coding|mcp|postgres|external-service|mcp-config|high
coding|mcp|redis|external-service|mcp-config|high
coding|mcp|sqlite|external-service|mcp-config|medium
coding|mcp|sentry|external-service|mcp-config|medium
coding|mcp|grafana|external-service|mcp-config|medium
coding|agent|planner|managed-template|agent-template|low
coding|agent|reviewer|managed-template|agent-template|low
coding|agent|docs|managed-template|agent-template|low
coding|agent|frontend|managed-template|agent-template|low
coding|agent|backend|managed-template|agent-template|low
coding|agent|tester|managed-template|agent-template|low
coding|agent|security|managed-template|agent-template|medium
coding|agent|memory-curator|managed-template|agent-template|medium
coding|agent|background-orchestrator|managed-template|agent-template|medium
coding|agent|cron-automation|managed-template|agent-template|medium
coding|agent|speculative-worker|managed-template|agent-template|high
claude-code|plugin|superpowers|third-party|repl-plugin|medium
claude-code|plugin|hookify|tool-ecosystem|repl-plugin|low
claude-code|plugin|claude-code-setup|third-party|repl-plugin|low
claude-code|plugin|code-review|tool-ecosystem|repl-plugin|medium
claude-code|plugin|security-guidance|third-party|repl-plugin|medium
claude-code|plugin|github|tool-ecosystem|repl-plugin|medium
claude-code|plugin|context7|tool-ecosystem|repl-plugin|medium
claude-code|plugin|frontend-design|third-party|repl-plugin|low
claude-code|plugin|figma|tool-ecosystem|repl-plugin|medium
claude-code|plugin|playwright|tool-ecosystem|repl-plugin|medium
claude-code|plugin|claude-mem|third-party|repl-plugin|medium
claude-code|plugin|code-simplifier|third-party|repl-plugin|low
codex|skill|gh-fix-ci|tool-ecosystem|skill-installer|medium
codex|skill|gh-address-comments|tool-ecosystem|skill-installer|medium
codex|skill|security-best-practices|tool-ecosystem|skill-installer|medium
codex|skill|doc|tool-ecosystem|skill-installer|low
codex|skill|security-threat-model|tool-ecosystem|skill-installer|medium
codex|skill|frontend-skill|tool-ecosystem|skill-installer|low
codex|skill|figma|tool-ecosystem|skill-installer|low
codex|skill|figma-use|tool-ecosystem|skill-installer|low
codex|skill|figma-implement-design|tool-ecosystem|skill-installer|medium
codex|skill|notion-spec-to-implementation|tool-ecosystem|skill-installer|medium
codex|skill|notion-research-documentation|tool-ecosystem|skill-installer|low
gemini-cli|plugin|conductor|tool-ecosystem|extensions-install|medium
gemini-cli|plugin|code-review|tool-ecosystem|extensions-install|medium
gemini-cli|plugin|security|tool-ecosystem|extensions-install|medium
gemini-cli|plugin|jules|tool-ecosystem|extensions-install|medium
gemini-cli|plugin|workspace|tool-ecosystem|extensions-install|low
gemini-cli|plugin|stitch|tool-ecosystem|extensions-install|medium
gemini-cli|plugin|flutter|tool-ecosystem|extensions-install|medium
gemini-cli|plugin|cloud-sql-postgresql|external-service|extensions-install|high
gemini-cli|plugin|bigquery-data-analytics|external-service|extensions-install|high
opencode|plugin|opencode-skillful|tool-ecosystem|config-plugin|medium
opencode|plugin|opencode-shell-strategy|tool-ecosystem|config-plugin|medium
opencode|plugin|opencode-vibeguard|tool-ecosystem|config-plugin|medium
opencode|plugin|opencode-workspace|tool-ecosystem|config-plugin|low
opencode|plugin|opencode-worktree|tool-ecosystem|config-plugin|low
opencode|plugin|opencode-background-agents|tool-ecosystem|config-plugin|medium
opencode|plugin|opencode-supermemory|third-party|config-plugin|medium
opencode|plugin|opencode-dynamic-context-pruning|third-party|config-plugin|medium
opencode|plugin|opencode-websearch-cited|third-party|config-plugin|medium
opencode|plugin|opencode-firecrawl|third-party|config-plugin|medium
opencode|plugin|opencode-devcontainers|tool-ecosystem|config-plugin|medium
coding|plugin|browser-use|third-party|tool-specific|high
coding|plugin|firecrawl|third-party|tool-specific|medium
coding|plugin|long-memory|third-party|tool-specific|medium
coding|plugin|memory-sync|third-party|tool-specific|medium
coding|plugin|proactive-agent|third-party|tool-specific|medium
coding|plugin|bleeding-edge-labs|third-party|tool-specific|high
EOF
}

capability_pack_matches_tool() {
  local scope="${1:-}"
  local tool_name="${2:-}"

  case "${scope}" in
    all)
      return 0
      ;;
    coding)
      case "${tool_name}" in
        claude-code|codex|gemini-cli|opencode)
          return 0
          ;;
      esac
      ;;
    "${tool_name}")
      return 0
      ;;
  esac

  return 1
}

capability_pack_entries() {
  local tool_name="${1:-}"
  local pack_name="${2:-}"
  local scope=""
  local entry_pack=""
  local entry_type=""
  local entry_item=""

  capability_pack_catalog | while IFS='|' read -r scope entry_pack entry_type entry_item; do
    [[ "${entry_pack}" == "${pack_name}" ]] || continue
    capability_pack_matches_tool "${scope}" "${tool_name}" || continue
    printf '%s|%s\n' "${entry_type}" "${entry_item}"
  done
}

capability_item_metadata() {
  local tool_name="${1:-}"
  local entry_type="${2:-}"
  local entry_item="${3:-}"
  local scope=""
  local catalog_type=""
  local catalog_item=""
  local source_class=""
  local install_mode=""
  local risk_level=""

  capability_item_catalog | while IFS='|' read -r scope catalog_type catalog_item source_class install_mode risk_level; do
    [[ "${catalog_type}" == "${entry_type}" ]] || continue
    [[ "${catalog_item}" == "${entry_item}" ]] || continue
    capability_pack_matches_tool "${scope}" "${tool_name}" || continue
    printf '%s|%s|%s\n' "${source_class}" "${install_mode}" "${risk_level}"
    break
  done
}

capability_item_manifest_line() {
  local tool_name="${1:-}"
  local entry_type="${2:-}"
  local entry_item="${3:-}"
  local metadata=""
  local source_class=""
  local install_mode=""
  local risk_level=""

  metadata="$(capability_item_metadata "${tool_name}" "${entry_type}" "${entry_item}")"
  if [[ -z "${metadata}" ]]; then
    printf -- '- %s\n' "${entry_item}"
    return 0
  fi

  IFS='|' read -r source_class install_mode risk_level <<< "${metadata}"
  printf -- '- %s [source=%s install=%s risk=%s]\n' "${entry_item}" "${source_class}" "${install_mode}" "${risk_level}"
}

validate_capability_catalog() {
  local tool_name=""
  local entry_type=""
  local entry_item=""
  local metadata=""
  local failures=0

  for tool_name in claude-code codex gemini-cli opencode; do
    while IFS='|' read -r entry_type entry_item; do
      [[ -n "${entry_type}" && -n "${entry_item}" ]] || continue
      metadata="$(capability_item_metadata "${tool_name}" "${entry_type}" "${entry_item}")"
      if [[ -z "${metadata}" ]]; then
        printf '缺少能力项元信息：tool=%s type=%s item=%s\n' "${tool_name}" "${entry_type}" "${entry_item}" >&2
        failures=$((failures + 1))
      fi
    done < <(
      capability_pack_catalog | while IFS='|' read -r scope _pack_name type item; do
        capability_pack_matches_tool "${scope}" "${tool_name}" || continue
        printf '%s|%s\n' "${type}" "${item}"
      done | awk '!seen[$0]++'
    )
  done

  [[ "${failures}" -eq 0 ]]
}

capability_pack_known() {
  local tool_name="${1:-}"
  local pack_name="${2:-}"
  [[ "$(capability_pack_item_count "${tool_name}" "${pack_name}")" != "0" ]]
}

capability_pack_item_count() {
  local tool_name="${1:-}"
  local pack_name="${2:-}"
  local count="0"

  count="$(capability_pack_entries "${tool_name}" "${pack_name}" | wc -l | tr -d '[:space:]')"
  [[ -n "${count}" ]] || count="0"
  printf '%s' "${count}"
}

capability_pack_items_csv() {
  local tool_name="${1:-}"
  local target_type="${2:-}"
  shift 2 || true

  local packs_csv=""
  local pack_name=""
  local entry_type=""
  local entry_item=""
  local -a collected_items=()
  local -a pack_names=()

  for packs_csv in "$@"; do
    mapfile -t pack_names < <(csv_clean_lines "${packs_csv}")
    for pack_name in "${pack_names[@]}"; do
      [[ -n "${pack_name}" ]] || continue
      while IFS='|' read -r entry_type entry_item; do
        [[ "${entry_type}" == "${target_type}" ]] || continue
        collected_items+=("${entry_item}")
      done < <(capability_pack_entries "${tool_name}" "${pack_name}")
    done
  done

  [[ "${#collected_items[@]}" -gt 0 ]] || return 0
  printf '%s\n' "${collected_items[@]}" | awk '!seen[$0]++' | paste -sd, -
}

capability_pack_items_csv_by_install_mode() {
  local tool_name="${1:-}"
  local target_type="${2:-}"
  local target_install_mode="${3:-}"
  shift 3 || true

  local packs_csv=""
  local pack_name=""
  local entry_type=""
  local entry_item=""
  local metadata=""
  local source_class=""
  local install_mode=""
  local risk_level=""
  local -a collected_items=()
  local -a pack_names=()

  for packs_csv in "$@"; do
    mapfile -t pack_names < <(csv_clean_lines "${packs_csv}")
    for pack_name in "${pack_names[@]}"; do
      [[ -n "${pack_name}" ]] || continue
      while IFS='|' read -r entry_type entry_item; do
        [[ "${entry_type}" == "${target_type}" ]] || continue
        metadata="$(capability_item_metadata "${tool_name}" "${entry_type}" "${entry_item}")"
        [[ -n "${metadata}" ]] || continue
        IFS='|' read -r source_class install_mode risk_level <<< "${metadata}"
        [[ "${install_mode}" == "${target_install_mode}" ]] || continue
        collected_items+=("${entry_item}")
      done < <(capability_pack_entries "${tool_name}" "${pack_name}")
    done
  done

  [[ "${#collected_items[@]}" -gt 0 ]] || return 0
  printf '%s\n' "${collected_items[@]}" | awk '!seen[$0]++' | paste -sd, -
}

resolve_capability_items_csv() {
  local tool_name="${1:-}"
  local target_type="${2:-}"
  local common_packs="${3:-}"
  local tool_packs="${4:-}"
  local enhanced_packs="${5:-}"
  local enhanced_enabled="${6:-0}"
  local experimental_packs="${7:-}"
  local experimental_enabled="${8:-0}"
  local explicit_specs="${9:-}"
  local resolved=""

  resolved="$(capability_pack_items_csv "${tool_name}" "${target_type}" "${common_packs}" "${tool_packs}")"

  if [[ "${enhanced_enabled}" == "1" ]]; then
    resolved="$(csv_merge_unique "${resolved}" "$(capability_pack_items_csv "${tool_name}" "${target_type}" "${enhanced_packs}")")"
  fi

  if [[ "${experimental_enabled}" == "1" ]]; then
    resolved="$(csv_merge_unique "${resolved}" "$(capability_pack_items_csv "${tool_name}" "${target_type}" "${experimental_packs}")")"
  fi

  resolved="$(csv_merge_unique "${resolved}" "${explicit_specs}")"
  printf '%s' "${resolved}"
}

resolve_installable_capability_items_csv() {
  local tool_name="${1:-}"
  local target_type="${2:-}"
  local target_install_mode="${3:-}"
  local common_packs="${4:-}"
  local tool_packs="${5:-}"
  local enhanced_packs="${6:-}"
  local enhanced_enabled="${7:-0}"
  local experimental_packs="${8:-}"
  local experimental_enabled="${9:-0}"
  local explicit_specs="${10:-}"
  local resolved=""

  resolved="$(capability_pack_items_csv_by_install_mode "${tool_name}" "${target_type}" "${target_install_mode}" "${common_packs}" "${tool_packs}")"

  if [[ "${enhanced_enabled}" == "1" ]]; then
    resolved="$(csv_merge_unique "${resolved}" "$(capability_pack_items_csv_by_install_mode "${tool_name}" "${target_type}" "${target_install_mode}" "${enhanced_packs}")")"
  fi

  if [[ "${experimental_enabled}" == "1" ]]; then
    resolved="$(csv_merge_unique "${resolved}" "$(capability_pack_items_csv_by_install_mode "${tool_name}" "${target_type}" "${target_install_mode}" "${experimental_packs}")")"
  fi

  resolved="$(csv_merge_unique "${resolved}" "${explicit_specs}")"
  printf '%s' "${resolved}"
}
