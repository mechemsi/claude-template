#!/usr/bin/env bash
# Status line — printed at the bottom of the Claude Code TUI.
# stdin receives a JSON payload describing the current session (model, cwd, tokens, etc.).
# stdout becomes the status line. Keep it to one line.
#
# Registered in .claude/settings.json under "statusLine".

set -euo pipefail

payload=$(cat)
model=$(printf '%s' "$payload" | jq -r '.model.display_name // "claude"' 2>/dev/null || echo "claude")
cwd=$(printf '%s' "$payload" | jq -r '.workspace.current_dir // "."' 2>/dev/null || echo ".")
dir=$(basename "$cwd")

branch=$(git -C "$cwd" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "—")
dirty=""
if [ -n "$(git -C "$cwd" status --porcelain 2>/dev/null)" ]; then
  dirty="*"
fi

printf '[%s] %s | %s%s' "$model" "$dir" "$branch" "$dirty"
