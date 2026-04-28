#!/usr/bin/env bash
# PreCompact hook — fires immediately before Claude Code compacts conversation context.
# Use it to persist anything you want preserved across the compaction boundary:
# in-flight task state, decisions made, files touched.
#
# stdin receives a JSON payload with conversation metadata. Anything written to
# .claude/state/ survives compaction and can be re-read by SessionStart on resume.

set -euo pipefail

cd "${CLAUDE_PROJECT_DIR:-$(pwd)}"
mkdir -p .claude/state

payload=$(cat)
ts=$(date -Iseconds)

# Snapshot recent file changes so post-compaction sessions know what was in flight.
{
  printf '# Pre-compact snapshot — %s\n\n' "$ts"
  printf '## Git status\n```\n'
  git status --short 2>/dev/null || echo "(no git)"
  printf '```\n\n## Branch\n'
  git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "(no git)"
  printf '\n'
} > .claude/state/last-compact.md

exit 0
