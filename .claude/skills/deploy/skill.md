# Skill: Deploy Workflow

**Type**: Auto-invoked workflow
**Triggers**: When asked to deploy, prepare a release, or run pre-deploy checks

## Purpose
Execute a structured, safe deployment checklist to ensure nothing is missed before shipping to production.

## Workflow

### Phase 1 — Code Quality Gates
```bash
npm run typecheck     # Zero TypeScript errors required
npm run lint          # Zero lint errors required
npm run test          # All tests must pass
npm run build         # Build must succeed
```
Stop and report if any phase fails. Do not proceed to Phase 2.

### Phase 2 — Database
```bash
npx prisma migrate status
```
- If migrations are pending: list them and confirm with the developer before running
- If schema changed but no migration exists: warn loudly — this can break production
- Never run `prisma migrate deploy` without explicit developer confirmation

### Phase 3 — Environment Variables Audit
- Diff `.env.example` against the last deploy tag to find newly added vars
- List any new vars the developer must set in the production environment
- Flag any vars that changed format or meaning

### Phase 4 — Breaking Changes Check
- Review API changes: any removed/renamed endpoints or changed response shapes?
- Review DB changes: any dropped columns or tables?
- Flag anything requiring coordinated rollout or feature flags

### Phase 5 — PR / Release Notes
Draft a release summary:
```
## What Changed
[bullet list of features/fixes]

## How to Test
[steps to verify key flows in production]

## Database Changes
[list of migrations, or "None"]

## New Environment Variables
[list, or "None"]

## Rollback Plan
[steps to revert if needed]

## Risk Level
[ ] Low — bug fix, no schema change
[ ] Medium — new feature, additive changes only
[ ] High — breaking change, schema migration
```

### Phase 6 — Final Sign-off
- Summarize pass/fail for each phase
- Remind developer to monitor logs post-deploy
- Suggest rollback command if applicable
