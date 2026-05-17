# Project Memory

Claude Code keeps per-project **memory** — small Markdown files holding facts it
should recall across sessions. By default that memory lives in a per-machine
path under `~/.claude/`, so it is **lost when you switch machines**.

This project keeps its memory **inside the repo** so it is committed, pushed,
and synced across every device via git.

## Where memory lives

- **Committed copy (source of truth):** `.claude/memory/` in this repo.
- **Per-machine path Claude Code actually reads:**
  `~/.claude/projects/<encoded-project-path>/memory/`, where
  `<encoded-project-path>` is the project's absolute path with every `/`
  replaced by `-` (e.g. `/home/me/projects/app` → `-home-me-projects-app`).

The per-machine path is a **symlink** pointing at `.claude/memory/`. Because the
real files are in the repo, `git pull` keeps memory current on every device.

## New device setup

After cloning the repo, run **once per device**:

```sh
sh .claude/link-memory.sh
```

This creates (or refreshes) the symlink. If Claude Code already created a real
memory directory at the per-machine path, the script folds those memories into
`.claude/memory/` before replacing the directory with the symlink — nothing is
lost. The script is idempotent; re-running it is safe.

## Memory file format

`.claude/memory/MEMORY.md` is the **index** — one line per memory, loaded into
Claude's context every session, so keep it terse:

```
- [Title](file.md) — short hook
```

Each memory is a sibling `.md` file with YAML frontmatter:

```yaml
---
name: short-slug
description: One-line summary of the fact.
metadata:
  type: project   # one of: user | feedback | project | reference
---
```

- `user` — a stable preference or fact about the developer.
- `feedback` — a correction or instruction given mid-work, generalized.
- `project` — a fact about this codebase, a fix, or a decision.
- `reference` — a pointer (URL, path, command) worth recalling.

Keep one fact per file. When a memory is added, add its row to `MEMORY.md`.

## Rules

- **Never put secrets in memory.** Memory files are committed and pushed —
  treat them exactly like source code. No credentials, tokens, or `.env` values.
- Memory is committed like any other file; include it in normal commits.
- Keep memories short and factual — they cost context tokens every session.
- Delete a memory file (and its `MEMORY.md` row) when the fact is stale.
