# /deploy — Deployment Checklist

Walk through all pre-deploy steps and prepare the branch for deployment.

## Pre-deploy Checklist
1. **Type check** — run `npm run typecheck`, fix all errors
2. **Lint** — run `npm run lint`, fix all warnings
3. **Tests** — run `npm run test`, ensure all pass
4. **Build** — run `npm run build`, confirm no build errors
5. **Migrations** — check if any Prisma migrations are pending (`npx prisma migrate status`)
6. **Env vars** — list any new env vars added; remind to set them in production
7. **Breaking changes** — flag any API changes that require coordination
8. **PR description** — draft a clear PR description with:
   - What changed and why
   - How to test
   - Any risks or rollback notes

## Post-deploy Notes
- Monitor error logs for 15 minutes after deploy
- Confirm key user flows work in production

## Usage
```
/deploy
/deploy --branch feat/new-auth
```
