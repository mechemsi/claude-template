---
name: bootstrap-claude-template
description: Use when starting a new project from scratch and wanting Claude Code conventions; when the user says "scaffold from the template", "use claudet", "set up a new project", "init claude config in this repo", or asks to copy rules/agents/commands/claudedocs structure from the claudet template repo.
---

# Bootstrap from claude-template (claudet)

Scaffolds a target project's `.claude/` config, `claudedocs/` doc structure, and `CLAUDE.md` by copying from the canonical claudet template repo. Architecture and process skills live in the same repo under `skills/` and are installed user-global via `make install` — they are NOT part of the per-project bootstrap copy.

## Canonical source

```
Repo:    https://github.com/mechemsi/claude-template
Clone:   git@github.com:mechemsi/claude-template.git
Branch:  main
```

Embedded in the skill so it works even when no local clone is on the machine.

## Locating the source (in priority order)

Resolve `$SRC` by trying these in order:

### 1. Local clone via symlink (preferred — fast, offline-capable)

```bash
SKILL_LINK="$HOME/.claude/skills/bootstrap-claude-template"
if [ -L "$SKILL_LINK" ]; then
  SKILL_REAL=$(readlink -f "$SKILL_LINK/SKILL.md")
  SRC=$(dirname "$(dirname "$(dirname "$SKILL_REAL")")")
  [ -d "$SRC/.git" ] && SOURCE_KIND="local"
fi
```

### 2. Freshness check (only if local source resolved)

```bash
if [ "$SOURCE_KIND" = "local" ]; then
  git -C "$SRC" fetch --quiet origin main 2>/dev/null
  BEHIND=$(git -C "$SRC" rev-list --count HEAD..origin/main 2>/dev/null || echo "?")
  DIRTY=$(git -C "$SRC" status --porcelain | head -1)
  if [ "$BEHIND" != "0" ] && [ "$BEHIND" != "?" ]; then
    echo "Local claudet is $BEHIND commits behind origin/main."
    [ -z "$DIRTY" ] && echo "Pull now? (clean tree)"
  fi
fi
```

### 3. GitHub fallback (no local clone, or symlink broken)

```bash
if [ -z "$SOURCE_KIND" ]; then
  echo "No local claudet clone found. Shallow-clone from GitHub? (y/n)"
  # On yes:
  SRC=$(mktemp -d -t claudet-XXXXXXXX)
  git clone --depth 1 --branch main \
    https://github.com/mechemsi/claude-template.git "$SRC"
  SOURCE_KIND="ephemeral"
  trap 'rm -rf "$SRC"' EXIT
fi
```

Report which source resolved (kind / path / commit / freshness) before proceeding.

If the user has no network and no local clone, abort cleanly — never proceed with a partial scaffold.

## When to use

- New empty repo or empty directory needs Claude conventions
- Existing project wants the rules / agents / commands / docs layout
- User mentions "claudet", "claude-template", "the template repo"

**Don't use** for: copying skills (they're global), updating an existing claudet-derived project (use git pull or manual edits), or any non-scaffolding task.

## Source layout (canonical)

```
$SRC/  (claudet repo root, located via symlink resolution above)
├── CLAUDE.md
├── README.md            (skip — write a project-specific README)
├── Makefile             (skip — only used to install skills globally)
├── skills/              (skip — installed via `make install`, not per-project)
├── .claude/
│   ├── agents/          → copy
│   ├── commands/        → copy
│   ├── rules/           → copy
│   ├── settings.json    → copy
│   └── settings.local.json   (skip — gitignored, user-specific)
└── claudedocs/
    ├── INDEX.md         → copy and reset to empty index
    ├── prds/            → copy `_template.md` only
    ├── plans/           → copy structure only (drop sample files)
    ├── implementations/ → copy structure only
    ├── decisions/       → copy structure only
    └── runbooks/        → copy structure only
```

`.claude/skills/` does **not** exist in the source — skills live in `$SRC/skills/` as the canonical version-controlled source and are symlinked into `~/.claude/skills/` by `make install`.

## Workflow

### 1. Confirm target directory

Ask the user where to scaffold. Default: current working directory. Refuse to overwrite existing `.claude/` or `claudedocs/` without explicit confirmation.

### 2. Copy core config

```bash
TARGET=<absolute path>
SKILL_REAL=$(readlink -f "$HOME/.claude/skills/bootstrap-claude-template/SKILL.md")
SRC=$(dirname "$(dirname "$(dirname "$SKILL_REAL")")")

mkdir -p "$TARGET/.claude" "$TARGET/claudedocs"

cp -r "$SRC/.claude/agents"        "$TARGET/.claude/"
cp -r "$SRC/.claude/commands"      "$TARGET/.claude/"
cp -r "$SRC/.claude/rules"         "$TARGET/.claude/"
cp    "$SRC/.claude/settings.json" "$TARGET/.claude/"
```

### 3. Copy CLAUDE.md (and customize)

```bash
cp "$SRC/CLAUDE.md" "$TARGET/CLAUDE.md"
```

Then ask the user to confirm or edit the **Tech Stack**, **Project Structure**, and **Git Conventions** sections — defaults assume Next.js 14 + TS + Prisma + Vitest. Don't leave the template defaults if the project's stack is different.

### 4. Scaffold claudedocs

Create the directory structure and an empty INDEX.md. Copy only the PRD template; sample plans/implementations/decisions from the source template are project-specific to claudet itself and must not leak into the new project.

```bash
mkdir -p "$TARGET/claudedocs/"{prds,plans,implementations,decisions,runbooks}
cp "$SRC/claudedocs/prds/_template.md" "$TARGET/claudedocs/prds/_template.md"
```

Write a fresh `claudedocs/INDEX.md` with empty tables under headings: PRDs, Plans, Implementations, Decisions, Runbooks. Use `claudedocs/INDEX.md` from the source as a structural reference, but every row must be removed.

### 5. Gitignore additions

Append to `.gitignore` (create if missing):

```
.claude/settings.local.json
CLAUDE.local.md
```

### 6. Sanity check

After copying, run:

```bash
ls -la "$TARGET/.claude" "$TARGET/claudedocs"
head -20 "$TARGET/CLAUDE.md"
```

Confirm:
- No `.claude/skills/` directory was created.
- `claudedocs/` has 5 subdirectories and `INDEX.md`.
- `INDEX.md` has empty tables, not the source template's sample rows.
- `prds/_template.md` is present.

### 7. Note about global skills

Tell the user: architecture and process skills (`solid-principles`, `code-quality-heuristics`, `creational-patterns`, `structural-patterns`, `behavioral-patterns`, `code-smells`, `writing-prd`, `deploy`, `security-review`) are installed at `~/.claude/skills/` (symlinked from `$SRC/skills/`) and apply to every project automatically — nothing extra is needed.

If the new project is for a teammate who doesn't have those skills, tell them to clone the claudet repo and run `make install` from its root.

## Common mistakes

- Copying sample plan/implementation/decision files into the new project (those describe claudet, not the new project).
- Forgetting to reset `claudedocs/INDEX.md` — it'll point at non-existent docs.
- Copying `settings.local.json` or `CLAUDE.local.md` (both are personal/gitignored).
- Creating a `.claude/skills/` directory in the new project — skills are global.
- Leaving Next.js/Prisma assumptions in `CLAUDE.md` for a project with a different stack.

## Related

- Source template: `$SRC` (resolved at runtime from the symlinked install)
- Global skills: `~/.claude/skills/` (symlinks back into `$SRC/skills/`)
- After bootstrap, the `writing-prd` skill triggers automatically when the user describes a new feature.
- For ongoing rule sync (after claudet rules evolve), use the `install-claudet-rules` skill — it handles diff-aware updates without re-running bootstrap.
