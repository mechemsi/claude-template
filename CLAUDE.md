# Project Instructions for Claude

## Overview
This is the shared team instructions file. It is committed to git and applies to all developers.

## Tech Stack
- **Language**: TypeScript / Node.js
- **Framework**: Next.js 14 (App Router)
- **Database**: PostgreSQL via Prisma ORM
- **Testing**: Vitest + Playwright
- **Styling**: Tailwind CSS
- **Validation**: Zod

## Code Style
- Follow rules in `.claude/rules/code-style.md`
- Follow naming and commenting rules in `.claude/rules/naming-and-comments.md`
- Follow API conventions in `.claude/rules/api-conventions.md`
- All new features must have tests per `.claude/rules/testing.md`
- Follow documentation conventions in `.claude/rules/documentation.md`
- Keep files small and modules well-bounded per `.claude/rules/file-and-module-structure.md`
- Manage dependencies per `.claude/rules/dependency-management.md`

## Git Conventions
- Follow commit and branching rules in `.claude/rules/git-commits.md`
- Branch naming: `feat/`, `fix/`, `chore/`, `docs/`
- Commit style: Conventional Commits (`feat: add login page`)
- Never commit directly to `main` — always open a PR
- **Never commit as Claude or attribute Claude as a co-author** — see `.claude/rules/git-commits.md`

## Project Structure
```
src/
  app/              # Next.js App Router pages
  components/       # Reusable UI components
  lib/              # Shared utilities and helpers
  server/           # API route handlers and services
  types/            # TypeScript type definitions
prisma/
  schema.prisma
tests/
  unit/
  e2e/
claudedocs/
  INDEX.md          # Master index — read this first for project context
  prds/             # Product Requirements (what/why) — written before plans
  plans/            # Technical designs (how) — written before implementation
  implementations/  # What was built and how it works (after implementation)
  decisions/        # Architecture Decision Records (ADRs)
  runbooks/         # Step-by-step operational guides
```

> **Skills — dual layout.** This template uses two skill locations:
>
> - **`skills/`** at repo root is the **shared library**: architecture and process skills (SOLID, design patterns, code smells, DRY/KISS/YAGNI, PRD writing, deploy, security review). Installed user-global by running `make install` from the repo root, which symlinks `./skills/*` into `~/.claude/skills/`. After install they auto-trigger across every project. New cross-project skills go here.
> - **`.claude/skills/`** in a project is the **project-local slot**: skills scoped to *this* codebase only — workflows that reference paths, services, or domain concepts that exist only here. They ship with the project, are checked into git, and never leak into other projects.
>
> See `.claude/skills/README.md` for the rule on which slot to use.

## Claude Code Surface Area

This template ships scaffolding for the full Claude Code surface so a fresh project starts wired-up:

```
.mcp.json                  # MCP servers — must live at repo root, applies to all teammates
.claude/
  settings.json            # permissions, env, hook + statusline registry
  settings.local.json      # personal overrides (gitignored)
  hooks/                   # deterministic lifecycle scripts (PostToolUse, SessionStart, PreCompact)
  commands/                # slash commands (/deploy, /review, /fix-issue)
  agents/                  # subagents with isolated context windows
  skills/                  # project-local skills (see "Skills" above)
  rules/                   # path-scoped style/convention rules
  output-styles/           # custom response formats (e.g. terse)
  plugins/                 # bundled commands+agents+skills+MCP under one namespace
  statusline.sh            # bottom-bar display script
```

## Documentation Workflow

Claude must keep `claudedocs/` up to date as part of the development process:

### Before starting a feature
1. Check `claudedocs/INDEX.md` for existing context — PRDs, plans, decisions, related implementations
2. For new user-facing features, write a PRD in `claudedocs/prds/` first (use `_template.md`); skip for refactors/bug fixes
3. After PRD approval, create a plan doc in `claudedocs/plans/` and link the PRD via `related`
4. If a significant technical choice is being made, create an ADR in `claudedocs/decisions/`

### After completing a feature
1. Create or update an implementation doc in `claudedocs/implementations/`
2. Update the plan doc status from `planned` to `implemented`
3. Update `claudedocs/INDEX.md` with any new or changed docs

### When a process is repeated
1. If you explain the same steps twice, create a runbook in `claudedocs/runbooks/`
2. Add it to `claudedocs/INDEX.md`

### Rules
- Always read `claudedocs/INDEX.md` first when starting work on a feature
- Never leave INDEX.md out of sync — update it whenever a doc is added or changes status
- Use YAML frontmatter in every doc (`title`, `status`, `date`, `related`)
- Link between related docs using relative paths

## Important Notes
- Always run `npm run typecheck` before finishing a task
- Keep components small and focused (< 150 lines)
- Use environment variables for all secrets — never hardcode
- When in doubt, ask rather than assume
