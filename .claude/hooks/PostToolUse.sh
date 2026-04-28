#!/usr/bin/env bash
# PostToolUse hook — fires after a tool invocation completes.
# Use it for deterministic side-effects: format-on-save, lint-on-edit, audit logging,
# auto-commit on file change. Hooks run every time without Claude needing to remember.
#
# stdin receives a JSON payload describing the tool call. Most teams parse it with `jq`.
# Exit 0 to allow the tool result through; exit non-zero to surface an error to Claude.
#
# This stub logs every Write/Edit/MultiEdit call to .claude/.tool-log so you can audit
# what Claude touched in this session. Replace with real automation as needed.

set -euo pipefail

cd "${CLAUDE_PROJECT_DIR:-$(pwd)}"

payload=$(cat)

# Only act on file-mutating tools.
tool=$(printf '%s' "$payload" | jq -r '.tool_name // empty' 2>/dev/null || true)
case "$tool" in
  Write|Edit|MultiEdit|NotebookEdit) ;;
  *) exit 0 ;;
esac

mkdir -p .claude
file_path=$(printf '%s' "$payload" | jq -r '.tool_input.file_path // .tool_input.path // "unknown"' 2>/dev/null || echo "unknown")
printf '%s\t%s\t%s\n' "$(date -Iseconds)" "$tool" "$file_path" >> .claude/.tool-log

exit 0
