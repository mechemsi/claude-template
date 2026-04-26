---
name: install-claudet-rules
description: Use when the user wants to install or update the claudet rule library (`code-style`, `naming-and-comments`, `file-and-module-structure`, `dependency-management`, `testing`, `api-conventions`, `documentation`) into the current project's `.claude/rules/`; when the user says "sync rules from claudet", "install standard rules here", "update rules in this project", or asks why their rules look outdated compared to claudet's.
---

# Install / Update claudet rules in a project

Copy the canonical `.claude/rules/*.md` files from the claudet repo into the **current project's** `.claude/rules/` directory. Diff-aware update: existing files are compared; the user decides which to overwrite.

## Why copy, not symlink

Rules live as **real files** in each project so that:

- The project is self-contained — teammates clone and work without the claudet repo on their machine.
- The rules are committed alongside the code that depends on them.
- Per-project divergence is allowed (e.g. a Go project replaces the TS code-style rule).
- Skills are different — they're cross-cutting and benefit from one source of truth, hence the symlink. Rules are a project contract.

## When to use

- New project: install the full rule set
- Existing project: update specific rules to match claudet's latest
- Audit: see which rules are present, missing, or stale

**Don't use** for skills (they're symlinked globally via `make install`), or for `CLAUDE.md` (different scope — handled by the `bootstrap-claude-template` skill).

## Locate the claudet repo

This skill is installed as a symlink at `~/.claude/skills/install-claudet-rules/`. Resolve the repo root from the symlink target — works on any PC where `make install` has been run:

```bash
SKILL_REAL=$(readlink -f "$HOME/.claude/skills/install-claudet-rules/SKILL.md")
SRC=$(dirname "$(dirname "$(dirname "$SKILL_REAL")")")
RULES_SRC="$SRC/.claude/rules"
```

If `make install-copy` was used (no symlink), ask the user for the repo path.

## Workflow

### 1. Confirm scope

Determine the target project:

```bash
TARGET="$(pwd)"   # default to current working directory
RULES_DST="$TARGET/.claude/rules"
mkdir -p "$RULES_DST"
```

Refuse to operate if `$TARGET` looks like the claudet repo itself (would copy onto itself).

### 2. Determine action per rule file

For each rule file in `$RULES_SRC/*.md`:

```bash
for src in "$RULES_SRC"/*.md; do
  name=$(basename "$src")
  dst="$RULES_DST/$name"
  if [ ! -e "$dst" ]; then
    echo "  NEW       $name"          # action: copy
  elif cmp -s "$src" "$dst"; then
    echo "  ok        $name"          # action: skip (identical)
  else
    echo "  CHANGED   $name"          # action: diff + ask
  fi
done
```

### 3. Apply with user confirmation

- **NEW**: copy without prompting (it's an addition, not a destructive change).
- **CHANGED**: show the diff and ask the user per file. Three options:
  - **take claudet** — overwrite the project's version
  - **keep mine** — skip
  - **show diff in editor** — open both files for manual merge

```bash
# Show the diff with a useful default
diff -u "$dst" "$src" | head -80
```

If the user is reviewing many files and wants to power through, accept `--all-claudet` (overwrite every CHANGED file) or `--all-keep` (skip every CHANGED file) as an early shortcut, but warn before applying.

### 4. Selective install

Allow the user to install a subset by name:

```
You: install only naming-and-comments and file-and-module-structure
Claude: [copies just those two, reports]
```

### 5. Reverse: list what's stale

Mode where Claude reports without changing anything:

```
  ok        code-style.md
  ok        testing.md
  CHANGED   naming-and-comments.md      (claudet has 3 new sections)
  CHANGED   file-and-module-structure.md
  NEW       dependency-management.md    (not yet installed)
  LOCAL     api-conventions.md          (project has this; claudet doesn't)
```

Useful before deciding what to merge.

### 6. Update CLAUDE.md (project's)

If a NEW rule is being installed, also update the project's `CLAUDE.md` Code Style section to reference it:

```diff
 ## Code Style
 - Follow rules in `.claude/rules/code-style.md`
+- Follow naming and commenting rules in `.claude/rules/naming-and-comments.md`
 ...
```

Show the planned diff, ask the user, then apply.

### 7. Done — report summary

```
3 new installed: dependency-management, file-and-module-structure, naming-and-comments
2 updated: testing, code-style
1 kept (yours): api-conventions
1 unchanged: documentation
CLAUDE.md updated with 3 new rule references
```

## Project-specific rules

If the project has rules NOT in claudet (e.g. `payment-compliance.md`), leave them untouched — they're project-owned. The skill never deletes a rule from the project just because it's missing from claudet.

## Common mistakes

- Overwriting project rules without showing the diff.
- Copying every rule blindly when the project has legitimate divergence (e.g. a Go project shouldn't take the TS-specific `code-style.md`).
- Forgetting to update `CLAUDE.md` to reference newly-installed rules — they exist on disk but aren't loaded.
- Running this in the claudet repo itself.

## Related

- `bootstrap-claude-template` — for new projects, scaffolds the whole `.claude/` structure (use this first, then `install-claudet-rules` for ongoing sync).
- `~/.claude/skills/` — global skills, installed once via `make install` from claudet.
- `.claude/rules/` (this project) — destination, version-controlled per project.
