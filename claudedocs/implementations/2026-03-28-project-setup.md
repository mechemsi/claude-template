---
title: Project Setup
status: implemented
date: 2026-03-28
related: [decisions/001-app-router.md]
---

# Project Setup

## What Was Built

Initial project scaffold using Next.js 14 with App Router, Prisma ORM, Tailwind CSS, and Vitest.

## Key Files

| Path | Purpose |
|------|---------|
| `src/app/layout.tsx` | Root layout with providers |
| `src/app/page.tsx` | Landing page |
| `prisma/schema.prisma` | Database schema |
| `tailwind.config.ts` | Tailwind configuration |
| `vitest.config.ts` | Test configuration |

## Configuration Choices

- **TypeScript strict mode** enabled in `tsconfig.json`
- **Path aliases**: `@/` maps to `src/`
- **Prisma**: PostgreSQL with `cuid()` default IDs
- **Tailwind**: Default config with no custom theme yet
- **Vitest**: Configured with `@vitejs/plugin-react` for component testing

## How It Works

```
Request → Next.js App Router → Layout → Page Component
                                  ↓
                            Prisma Client → PostgreSQL
```

## Dependencies Added

| Package | Version | Purpose |
|---------|---------|---------|
| next | 14.x | Framework |
| prisma | 5.x | ORM |
| tailwindcss | 3.x | Styling |
| vitest | 1.x | Unit testing |
| @playwright/test | 1.x | E2E testing |
| zod | 3.x | Validation |

## Notes

- No authentication yet — see [Auth System plan](../plans/2026-03-28-auth-system.md)
- Database must be running locally on port 5432 (or override in `.env.local`)
