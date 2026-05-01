---
name: db-migration-safety
description: Use when writing, reviewing, or running database schema migrations against a non-empty database; when adding NOT NULL without a default, renaming/dropping columns or tables, adding foreign keys, creating indexes on large tables, or backfilling data; when an ORM (Prisma, Doctrine, Rails ActiveRecord, Django, Alembic/SQLAlchemy, TypeORM, Sequelize, Knex, GORM, Liquibase, Flyway) auto-generates a migration that's about to ship; when deploys fail with locks, timeouts, or "column does not exist" errors; when planning the order between code release and schema change.
---

# Database Migration Safety

Schema changes are the most common cause of production outages outside deploys themselves. The principles below are ORM- and language-agnostic; an ORM-specific cookbook lives at the bottom.

## When to apply

- Any DDL against a populated table (anything more than a fresh dev DB)
- Adding/changing/removing a column, index, or constraint
- ORM diff says "drop column", "rename column", "alter type", or "add NOT NULL"
- Backfilling data via migration `UPDATE`/`INSERT`
- Foreign keys on tables with > ~100k rows
- Migrations that have ever timed out or locked traffic in this environment
- Coordinating a deploy where code and schema change together

## Core rule: every migration must be safe in **both directions of the deploy window**

A deploy is never atomic across all instances. For some seconds-to-minutes, **old code runs against the new schema** (and during rollback, **new code runs against the old schema**). Every migration must keep one of these true:

> The currently-running code can read and write the database both before and after the migration runs.

Anything that violates this — `DROP COLUMN`, `RENAME COLUMN`, `ALTER COLUMN ... NOT NULL`, type narrowing — must be split across multiple deploys.

## The expand → migrate → contract pattern

The single most important pattern. Almost every "destructive" change is really three deploys:

| Phase | What happens | Schema | Code |
|-------|--------------|--------|------|
| **Expand** | Add the new shape alongside the old | Add column / table / index. New is nullable, no constraints. | Old code keeps working. |
| **Migrate** | Move/copy data, dual-write if needed | No schema change. Backfill in batches. | New code writes both old and new; reads from new with fallback. |
| **Contract** | Remove the old shape | Drop old column / table / constraint. | New code only references new. |

You only ever ship one phase per deploy. Skipping phases is how outages happen.

## Dangerous operations and their safe rewrites

| Naive | Why it breaks | Safe sequence |
|-------|---------------|---------------|
| `ALTER TABLE t ADD COLUMN c TEXT NOT NULL` | Rewrites the table; old code that doesn't know `c` still inserts → fails | 1) add nullable, 2) backfill in batches, 3) `SET NOT NULL` once 100% populated |
| `ALTER TABLE t RENAME COLUMN a TO b` | Old code's `SELECT a` breaks instantly | 1) add `b`, 2) dual-write app code, 3) backfill, 4) read from `b`, 5) drop `a` |
| `ALTER TABLE t DROP COLUMN c` | Any rolled-back instance with old code crashes on insert | Stop writing & reading `c` in code first; ship at least one deploy where `c` is unused; only then drop |
| `ALTER TABLE t ADD CONSTRAINT fk FOREIGN KEY ...` | Locks both tables, validates every existing row | Postgres: `ADD CONSTRAINT ... NOT VALID` (instant) → `VALIDATE CONSTRAINT` (no write lock) |
| `CREATE INDEX idx ON t(col)` on a large table | Locks writes for the duration | Postgres: `CREATE INDEX CONCURRENTLY`. MySQL 5.6+: online DDL by default. Otherwise: replica swap. |
| `ALTER TABLE t ALTER COLUMN c TYPE bigint` | Full table rewrite | New nullable column → backfill → swap reads → drop old (expand-contract) |
| `UPDATE t SET c = ... ` (no WHERE / no batch) | Holds long row locks; bloats WAL | Batch with `LIMIT` + `WHERE id BETWEEN x AND y`, sleep between batches, idempotent |
| `DELETE FROM t WHERE ...` on large table | Same as above + bloat | Batch delete; or partition switch; or soft-delete + sweep |
| `ALTER TABLE t SET DEFAULT ...` (on Postgres < 11) | Full table rewrite to backfill the default | PG ≥ 11 stores default in catalog (fast). Older: add nullable, set default for new rows, backfill, then `NOT NULL` |

## Locking and timeouts

DDL takes locks. The lock level matters more than the duration:

- **`ACCESS EXCLUSIVE`** (Postgres) — blocks reads *and* writes. Even a 200ms `ALTER` on a hot table = a stampede of timed-out requests piling up.
- **`SHARE`** / **`SHARE ROW EXCLUSIVE`** — blocks writes only.
- **`ACCESS SHARE`** — blocks nothing meaningful.

Rules:

1. **Set `lock_timeout` and `statement_timeout`** at the migration session start. Better to fail fast than hold a queue:
   ```sql
   SET lock_timeout = '2s';
   SET statement_timeout = '5min';
   ```
2. **Acquire locks late, release early.** Don't open a transaction at the top of a long migration that takes locks.
3. **Re-run-safe.** A migration that fails halfway must be runnable again without manual repair. Use `IF NOT EXISTS`, idempotent `INSERT ... ON CONFLICT`, and small steps.

## Backfilling data

Never `UPDATE t SET ...` on millions of rows in one statement.

```sql
-- ❌ Locks rows for minutes, bloats WAL/redo, blocks replication
UPDATE users SET locale = 'en' WHERE locale IS NULL;

-- ✅ Batched, resumable, observable
DO $$
DECLARE
  rows_updated int;
BEGIN
  LOOP
    UPDATE users
       SET locale = 'en'
     WHERE id IN (
       SELECT id FROM users WHERE locale IS NULL LIMIT 5000
     );
    GET DIAGNOSTICS rows_updated = ROW_COUNT;
    EXIT WHEN rows_updated = 0;
    PERFORM pg_sleep(0.2);
  END LOOP;
END $$;
```

Better yet, run backfills **outside** the migration framework — as a one-shot job — so a slow backfill doesn't gate every other deploy. Migration files should change schema; data work belongs in a script with logging, progress, and a kill switch.

## Code/schema deploy ordering

Pick the right order for the change. The wrong order is a strict superset of "things that break in production".

| Change | Deploy schema first? | Deploy code first? |
|--------|----------------------|---------------------|
| Add nullable column | ✅ schema first; old code ignores it | — |
| Add NOT NULL column | ✅ schema (nullable + backfill) before code that requires it | — |
| Drop column | — | ✅ code that no longer references it first; drop later |
| Rename column | Neither — must use expand-contract over multiple deploys | — |
| Add table | ✅ schema first | — |
| Drop table | — | ✅ code first; drop after observation window |
| Add index | ✅ schema first (concurrent / online) | — |
| Add NOT NULL constraint to existing nullable column | ✅ schema (backfill) before code relies on it | — |
| Add new enum value | ✅ schema first | — |
| Remove enum value | — | ✅ code first; cleanup migration after |

## Reversibility

Every migration must have a rollback story, even if you never run it.

- **Forward-only migrations** (drop column, drop table, irreversible data transforms) must be guarded by an explicit "no automatic rollback" comment in the migration file *and* paired with a retention plan: a backup, a renamed-to-`_legacy_` table, or a soft-delete window.
- **Auto-generated `down()` migrations** are a trap — frameworks emit syntactically reversible SQL that silently loses data. Treat any auto-`down` as untrusted; review each one before relying on it.
- **The real rollback path is forward.** If a deploy goes bad, ship a fix-forward migration, not a `down`. `down` migrations are for local dev resets.

## ORM cookbook

Same principles, different syntax. The frameworks don't make migrations safe — they make them **easy**, which is not the same thing.

| ORM / framework | Auto-generated diff is safe? | How to escape into raw SQL | Typical gotcha |
|-----------------|------------------------------|----------------------------|----------------|
| **Prisma** (TS) | ❌ Often emits `DROP` then `ADD` for renames | `prisma migrate dev --create-only` then hand-edit SQL | `@map` doesn't move data — it only renames at the schema level |
| **Doctrine** (PHP/Symfony) | ⚠️ `doctrine:migrations:diff` produces single-step destructive DDL | Edit the generated `up()` to split phases; use `$this->addSql(...)` | Auto-generated `down()` is rarely tested |
| **Rails ActiveRecord** | ⚠️ `change` method assumes reversibility | Use `up`/`down` explicitly for non-trivial changes | `add_column ... null: false, default: x` rewrites the table on PG < 11 |
| **Django ORM** | ⚠️ `makemigrations` chains operations into one transaction | Split into two migrations; use `RunPython` for data | `unique=True` adds an index that locks; use `Meta.indexes` with `CONCURRENTLY` via raw SQL |
| **Alembic / SQLAlchemy** | ⚠️ Autogenerate misses indexes and check constraints | `op.execute("...")` for raw SQL | `op.alter_column` defaults to a full rewrite on PG; use `existing_*` carefully |
| **TypeORM** | ❌ Synchronize=true in prod is catastrophic | Generate then edit `migrations/*.ts` | Renames flagged as drop+create — always inspect |
| **Sequelize** (Node) | ⚠️ CLI emits one transaction wrapping all DDL | Split files; use `queryInterface.sequelize.query(...)` | No `CONCURRENTLY` index helper — drop to raw SQL |
| **Knex.js** | Manual — no auto-diff | First-class `raw()` for SQL | Forgetting `await` on chained schema calls |
| **GORM** (Go) | ❌ `AutoMigrate` is fine for dev, dangerous in prod | Use `goose`, `golang-migrate`, or `atlas` | `AutoMigrate` never drops; schema drifts silently |
| **Hibernate / JPA** (Java) | ❌ `hbm2ddl.auto=update` in prod is catastrophic | Use Liquibase or Flyway alongside | Entity changes don't equal migration changes |
| **Liquibase** | Manual changesets | Native | `<dropColumn>` is irreversible by default — set `failOnError` and review |
| **Flyway** | Manual SQL files | Native | Naming + checksumming: never edit a migration after it's been applied |
| **Atlas** (declarative) | Compares desired vs actual; emits diff | Inspects then applies | Declarative diffs can be aggressive — always review the plan |

The decision is the same regardless of framework: **read the generated SQL before merging.** If the diff contains `DROP`, `RENAME`, `NOT NULL`, `FOREIGN KEY`, or any `ALTER COLUMN ... TYPE` against a live table, expand-contract.

## Per-project derivation

Different projects pin to different ORMs and database engines. Use this skill as the principles layer; the project's `.claude/rules/db-migrations.md` (if present) names the ORM, the runner command, the migration directory, and any project-specific conventions (e.g. "all backfills in `scripts/backfills/`", "no migrations during ramadan freeze"). When that file is missing, ask the user once, then derive:

1. Which ORM/framework? (`prisma`, `doctrine`, `rails`, `django`, `alembic`, `typeorm`, `gorm`, `flyway`, …)
2. Which database engine? (Postgres locking rules ≠ MySQL ≠ SQLite ≠ SQL Server)
3. Where do migrations live? (`prisma/migrations/`, `migrations/Version*.php`, `db/migrate/`, `app/migrations/`, `alembic/versions/`, …)
4. How are they run in prod? (`prisma migrate deploy`, `doctrine:migrations:migrate --no-interaction`, `rails db:migrate`, …)
5. What's the table-size threshold above which "obvious" migrations need expand-contract? (default: 100k rows or 100MB)

## Common mistakes

- **Trusting auto-generated migrations.** They reflect the schema diff, not the safe path between schemas.
- **One commit, schema + code change requiring it.** A rollback that reverts code without reverting the schema (or vice versa) breaks the system. Decouple them across deploys.
- **Backfills inside the migration transaction.** A 20-minute migration holds locks and bloats WAL/binlog; replicas lag; deploys queue.
- **`hbm2ddl.auto=update`, `synchronize: true`, `db.AutoMigrate` in production.** All three silently mutate prod schema based on entity changes nobody reviewed.
- **Editing an already-applied migration.** Flyway/Liquibase will refuse; Doctrine/Alembic happily diverge between environments. Always add a *new* migration to fix.
- **Trusting `down()` migrations.** Most are wrong, untested, and lossy. Treat forward as the only direction in prod.
- **Dropping a column the same day code stops using it.** The previous deploy can still be rolled back. Wait for an observation window.
- **Adding a foreign key that validates every row.** Postgres allows `NOT VALID` + `VALIDATE` to split this across two migrations with no full-table lock.
- **Type narrowing** — `varchar(500)` → `varchar(100)` requires reading every row. Same as dropping data; treat as expand-contract.
- **Coupling migrations to deploy time.** Make migrations idempotent and resumable, then run them in a window decoupled from the code deploy.

## Related

- `deploy` — Phase 2 invokes this skill; treat the deploy checklist as the *when* and this skill as the *how*.
- `12-factor-app` — factor V (build/release/run) and disposability rely on safe schema evolution.
- `ci-cd-pipeline` — gate on migration diff review; auto-block PRs whose migration contains `DROP`/`RENAME`/`NOT NULL` without a paired note.
- `error-handling` — backfills and online migrations need retry-safe, idempotent, observable error paths.
- `layered-architecture` — repositories isolate the schema; safe migrations are easier when only one layer touches columns.
- `logging-observability` — migrations must emit progress (rows/sec, batch number, ETA) to be tractable.
- `refactoring-discipline` — parallel-change-in-code is the same shape as expand-contract-in-schema; the two reinforce each other.
- `concurrency-and-idempotency` — backfills must be batched, resumable, and idempotent; same primitives as retry-safe consumers.
- `feature-flags-and-rollout` — never gate the schema itself behind a flag; only the *code path* using new columns. Schema must be safe regardless of flag state.
- `code-review-discipline` — schema PRs are high-risk; require two reviewers and a paired migration-safety note.
