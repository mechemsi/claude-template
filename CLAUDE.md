# Project Instructions for Claude

## Overview
This is the shared team instructions file. It is committed to git and applies to all developers.

## Tech Stack
- **Language**: TypeScript / Node.js
- **Framework**: Next.js 14 (App Router)
- **Database**: PostgreSQL via Prisma ORM
- **Testing**: Vitest + Playwright
- **Styling**: Tailwind CSS

## Code Style
- Follow rules in `.claude/rules/code-style.md`
- Follow API conventions in `.claude/rules/api-conventions.md`
- All new features must have tests per `.claude/rules/testing.md`

## Git Conventions
- Branch naming: `feat/`, `fix/`, `chore/`, `docs/`
- Commit style: Conventional Commits (`feat: add login page`)
- Never commit directly to `main` — always open a PR

## Project Structure
```
src/
  app/          # Next.js App Router pages
  components/   # Reusable UI components
  lib/          # Shared utilities and helpers
  server/       # API route handlers and services
  types/        # TypeScript type definitions
prisma/
  schema.prisma
tests/
  unit/
  e2e/
```

## Important Notes
- Always run `npm run typecheck` before finishing a task
- Keep components small and focused (< 150 lines)
- Use environment variables for all secrets — never hardcode
- When in doubt, ask rather than assume
