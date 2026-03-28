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
- Follow API conventions in `.claude/rules/api-conventions.md`
- All new features must have tests per `.claude/rules/testing.md`
- Follow documentation conventions in `.claude/rules/documentation.md`

## Git Conventions
- Branch naming: `feat/`, `fix/`, `chore/`, `docs/`
- Commit style: Conventional Commits (`feat: add login page`)
- Never commit directly to `main` — always open a PR

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
  plans/            # Feature specs and designs (before implementation)
  implementations/  # What was built and how it works (after implementation)
  decisions/        # Architecture Decision Records (ADRs)
  runbooks/         # Step-by-step operational guides
```

## Documentation Workflow

Claude must keep `claudedocs/` up to date as part of the development process:

### Before starting a feature
1. Check `claudedocs/INDEX.md` for existing context — plans, decisions, related implementations
2. Create a plan doc in `claudedocs/plans/` if one doesn't exist yet
3. If a significant technical choice is being made, create an ADR in `claudedocs/decisions/`

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
