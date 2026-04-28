#!/usr/bin/env bash
# SessionStart hook — fires once when a Claude Code session opens in this project.
# Use it to surface context Claude should know up-front: branch, dirty state, recent work.
#
# Anything printed to stdout becomes additional context Claude sees at session start.
# Keep output short — every line costs tokens for the rest of the session.

set -euo pipefail

cd "${CLAUDE_PROJECT_DIR:-$(pwd)}"

branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "no-git")
dirty=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
last_commit=$(git log -1 --pretty=format:'%h %s' 2>/dev/null || echo "no commits")

cat <<EOF
[project context]
branch: $branch ($dirty uncommitted file(s))
last commit: $last_commit
EOF
