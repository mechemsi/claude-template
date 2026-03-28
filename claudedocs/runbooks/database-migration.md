---
title: Database Migration
---

# Runbook: Database Migration

## When to Use

When you've changed `prisma/schema.prisma` and need to apply those changes to the database.

## Steps

### 1. Create the Migration

```bash
npx prisma migrate dev --name describe-what-changed
```

This will:
- Generate a SQL migration file in `prisma/migrations/`
- Apply it to your local database
- Regenerate the Prisma client

### 2. Verify Locally

```bash
# Check migration status
npx prisma migrate status

# Run tests to make sure nothing broke
npm run test
```

### 3. Review the Generated SQL

Always read the generated migration file in `prisma/migrations/`. Watch for:
- Unexpected `DROP` statements
- Data-losing column type changes
- Missing default values for new non-nullable columns

### 4. Deploy to Production

```bash
npx prisma migrate deploy
```

This runs all pending migrations. It does NOT regenerate the client.

## Rollback

Prisma does not support automatic rollback. If a migration fails:

1. Fix the issue in a new migration
2. Or manually write a `DOWN` SQL script and run it against the database
3. Never delete a migration file that has been applied to production

## Common Issues

| Issue | Fix |
|-------|-----|
| "Migration has already been applied" | Your local DB is ahead. Run `npx prisma migrate status` to check. |
| "Column cannot be null" | Add a `@default()` value or make the column optional first, backfill, then make it required. |
| "Drift detected" | Your DB schema doesn't match migrations. Run `npx prisma migrate reset` locally (destroys data). |
