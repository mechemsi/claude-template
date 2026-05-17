#!/usr/bin/env sh
# Link this repo's committed Claude memory (.claude/memory) into Claude Code's
# per-project memory path, so memories sync across devices via git.
#
# Run once per device after cloning:  sh .claude/link-memory.sh
set -e

repo="$(cd "$(dirname "$0")/.." && pwd)"
encoded="$(printf '%s' "$repo" | sed 's#/#-#g')"
target="$HOME/.claude/projects/${encoded}/memory"

mkdir -p "$(dirname "$target")"

# Existing symlink — just refresh it.
if [ -L "$target" ]; then
    rm "$target"
# Existing real directory (e.g. created by a fresh Claude Code run) — fold any
# memories it holds into the repo copy, then replace it with the symlink.
elif [ -d "$target" ]; then
    for f in "$target"/*.md; do
        [ -e "$f" ] || continue
        base="$(basename "$f")"
        [ -e "$repo/.claude/memory/$base" ] || cp "$f" "$repo/.claude/memory/$base"
    done
    rm -rf "$target"
fi

ln -s "$repo/.claude/memory" "$target"
echo "Linked: $target -> $repo/.claude/memory"
