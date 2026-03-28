# Personal Overrides for Claude (gitignored)

## My Preferences
- I prefer verbose explanations when refactoring — explain *why*, not just *what*
- Always show me the diff before applying large changes
- I use VS Code — format suggestions accordingly

## Local Dev Setup
- My local DB runs on port 5433 (not default 5432)
- I have a `.env.local` with test credentials — don't overwrite it
- I prefer `pnpm` over `npm` locally

## Personal Shortcuts
- When I say "clean it up", refactor for readability without changing behavior
- When I say "lock it down", focus on security hardening
- When I say "ship it", help me prepare a PR description and checklist

## Overrides
- Skip test generation for files inside `src/app/(marketing)/` — these are static pages
- Use `console.log` freely in scripts — I'll clean up before committing
