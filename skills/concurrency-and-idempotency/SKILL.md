---
name: concurrency-and-idempotency
description: Use when a webhook handler can be retried by the upstream; when a queue or message-bus consumer might receive the same message twice; when two concurrent requests can both pass a uniqueness check before either inserts; when a cron job runs on multiple instances; when Stripe-style idempotency keys are being designed; when code does check-then-act on shared state; when an ORM update lacks an optimistic version column and is racing; when retry/backoff is being added to a non-idempotent operation; when a counter is being updated as `count = appComputedValue` instead of `count = count + 1`; when distributed locks (Redis SETNX, Zookeeper, etcd) are being used for correctness; when "exactly-once" delivery is being assumed from a broker; when an outbox or saga is being designed.
---

# Concurrency and Idempotency

In any distributed system — even "just" one app server plus one database — operations get retried, messages get redelivered, requests race. Correctness comes from making receivers idempotent and using the database to enforce invariants, not from wishing the network were reliable.

## When to apply

- Endpoint or handler can be invoked more than once for the same logical event (webhook, payment callback, queue consumer)
- "Check that X doesn't exist, then create it" appears anywhere in code
- A counter, balance, or aggregate is updated by reading then writing
- A scheduled job runs on more than one instance, or could after a deploy
- Adding retries, exponential backoff, or a circuit breaker
- Using a Redis/Zookeeper/etcd lock to coordinate work
- Designing the response shape for a `POST` that creates resources
- An ORM emits `UPDATE` without a `WHERE version = ?` clause on data multiple actors can edit

## Quick reference

| Hazard | Wrong fix | Right fix |
|--------|-----------|-----------|
| Duplicate webhook delivery | `if (!exists) insert(...)` in app | Idempotency-key table with PK on the key, `INSERT ... ON CONFLICT DO NOTHING` |
| Two requests creating same email user | App-level "find by email" check | `UNIQUE` index on `email`; catch the constraint violation |
| Lost update on edit form | "Last write wins" | Optimistic concurrency: `version` column + `UPDATE ... WHERE version = ?` |
| Two instances run nightly cleanup | Cron only on instance 1 | DB-backed lease row, `UPDATE ... WHERE held_until < now()` |
| Counter increments lost | `SET count = $appValue` | `SET count = count + 1` (atomic in SQL) |
| Money transfer must see consistent balance | Read, decide, write | `SELECT ... FOR UPDATE` inside a transaction |
| Critical section across services | Naive Redis SETNX with TTL | Lock + **fencing token** verified at the resource |
| Retry on a `POST /charge` timeout | Just retry blindly | Idempotency key in request → server dedupes |

## At-least-once is the realistic default

Network calls fail. Brokers retry. Clients retry. "Exactly-once delivery" is a marketing phrase — at the wire level you get at-least-once or at-most-once, and at-most-once means you sometimes lose data. The standard pattern is:

> **At-least-once delivery + idempotent receivers = effectively-once processing.**

That moves the correctness burden from the network (where you can't fix it) to the receiver (where you can). Every webhook handler, queue consumer, and retry-able RPC must be idempotent by design.

## Idempotency keys (the Stripe pattern)

For any non-idempotent operation exposed over the wire (`POST /charges`, `POST /transfers`, `POST /orders`), require an idempotency key from the caller and store it server-side.

```sql
CREATE TABLE idempotency_keys (
  key            TEXT PRIMARY KEY,
  request_hash   BYTEA NOT NULL,           -- detects key reuse with different payload
  status         TEXT NOT NULL,            -- 'in_flight' | 'completed'
  response_code  INTEGER,
  response_body  JSONB,
  locked_until   TIMESTAMPTZ,              -- so a crashed in-flight row can be reclaimed
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  expires_at     TIMESTAMPTZ NOT NULL      -- TTL: drop after 24h–30d depending on domain
);
```

Lifecycle on every request:

1. `INSERT ... ON CONFLICT (key) DO NOTHING RETURNING *` — atomic claim.
2. If the row already existed and `status = 'completed'`: return the stored response. Done.
3. If it existed and `status = 'in_flight'` and `locked_until > now()`: return `409 Conflict` (don't re-execute).
4. If we created it: do the work, then `UPDATE` with `status = 'completed'` and the response, in the **same transaction** as the business write.
5. Background sweeper deletes rows past `expires_at`.

Where the key comes from:

- **Client-supplied** (`Idempotency-Key` header) — best for public APIs; trust the client to generate a UUID per logical attempt.
- **Derived from request** — hash of `(actor, operation, payload)` when you can't change clients. Risk: legitimate retries with a different timestamp hash differently.
- **Business key** — `order_id`, `webhook_event_id`. Best when the upstream provides a stable ID (Stripe `evt_*`, GitHub `X-GitHub-Delivery`).

Without a TTL the table grows forever. Without an "in_flight" state, two concurrent retries both run the work. Both bugs are common.

```ts
// ❌ Webhook handler that double-charges on retry
export async function handleStripeWebhook(req: Request) {
  const event = JSON.parse(await req.text());
  if (event.type === 'invoice.paid') {
    await grantSubscription(event.data.object.customer); // retried delivery → granted twice
  }
}

// ✅ Dedup on Stripe's event ID — they guarantee uniqueness per event
export async function handleStripeWebhook(req: Request) {
  const event = JSON.parse(await req.text());
  const claimed = await db.query(
    `INSERT INTO processed_webhook_events (event_id, source)
     VALUES ($1, 'stripe') ON CONFLICT DO NOTHING`,
    [event.id],
  );
  if (claimed.rowCount === 0) return new Response(null, { status: 200 }); // already processed
  if (event.type === 'invoice.paid') {
    await grantSubscription(event.data.object.customer);
  }
  return new Response(null, { status: 200 });
}
```

## Unique constraints are the only race-free dedup

App-level "check then insert" is always a TOCTOU bug. Two requests can both pass the check before either inserts.

```ts
// ❌ Race: both requests see "no user with this email" and both insert
async function register(email: string, password: string) {
  const existing = await db.user.findUnique({ where: { email } });
  if (existing) throw new EmailTaken();
  return db.user.create({ data: { email, passwordHash: hash(password) } });
}

// ✅ Let the database arbitrate. The unique index is the contract.
async function register(email: string, password: string) {
  try {
    return await db.user.create({ data: { email, passwordHash: hash(password) } });
  } catch (err) {
    if (isUniqueViolation(err, 'users_email_key')) throw new EmailTaken();
    throw err;
  }
}
```

The same pattern beats every "check then act" race: orders from the same cart, slots in a calendar, vanity URLs, room reservations. The `UNIQUE` index is non-negotiable; the app-level pre-check is at best a UX optimization, never a correctness guarantee.

## Optimistic concurrency (version columns)

When a user can edit a record that other actors might also edit, version it:

```sql
ALTER TABLE documents ADD COLUMN version INTEGER NOT NULL DEFAULT 0;
```

```ts
// ❌ Last write wins — two editors trample each other silently
await db.document.update({ where: { id }, data: { title, body } });

// ✅ Update only if nobody else moved the version forward
const result = await db.document.updateMany({
  where: { id, version: expectedVersion },
  data: { title, body, version: expectedVersion + 1 },
});
if (result.count === 0) throw new ConcurrentModification(id, expectedVersion);
```

The `version` lives next to the data. The client sends back the version it loaded (in the request body, not just an ETag). The server's `WHERE version = ?` makes the update atomic — no transaction needed. On conflict the client either retries with fresh data or surfaces the conflict to the user.

Use this as the default for any user-editable resource. Reserve pessimistic locks for cases where the value of waiting is higher than the value of failing fast.

## Pessimistic locking (`SELECT … FOR UPDATE`)

Use only when invariants span rows and you must serialize. The textbook example is moving money:

```sql
BEGIN;
SELECT balance FROM accounts WHERE id = $1 FOR UPDATE;   -- locks the row
SELECT balance FROM accounts WHERE id = $2 FOR UPDATE;
UPDATE accounts SET balance = balance - $3 WHERE id = $1;
UPDATE accounts SET balance = balance + $3 WHERE id = $2;
COMMIT;
```

Rules:

- Always lock rows in a deterministic order (e.g. by `min(id), max(id)`) to avoid deadlocks.
- Keep the transaction short. `FOR UPDATE` on a hot row blocks every other writer.
- Never call external services inside the locked transaction — your lock is now hostage to their latency.
- Prefer `FOR UPDATE SKIP LOCKED` for queue-like workloads (multiple workers pulling jobs).

## Distributed locks need fencing tokens

A lock implemented as "set a key in Redis with a TTL" is unsafe for correctness. Process pause (GC, container scheduler, kernel preempt) can let your TTL expire while you still believe you hold the lock. Now two clients act at once and the resource has no way to tell.

The fix is a **fencing token**: a monotonically increasing number returned by the lock service, presented to the protected resource on every write. The resource rejects any write whose token is older than the highest token it has accepted.

```
Client A: acquire(lock) → token=33  → pause for GC → wakes up, writes with token=33
Client B: acquire(lock) → token=34  → writes with token=34
Resource: highest_seen=34, rejects A's token=33 write
```

If the resource can't enforce monotonic tokens, the lock is for *efficiency* (avoid duplicate work most of the time), not *correctness* (never two writers). Be honest about which one you have. Redlock and similar TTL-only schemes have well-known failure modes — read Kleppmann's critique before relying on them for money or inventory.

## Cron and scheduled jobs: lease, don't flag

Two app instances + one cron schedule = two simultaneous runs of "nightly cleanup". A flag file or a "running" boolean is racy. Use a database lease row:

```sql
CREATE TABLE job_leases (
  job_name      TEXT PRIMARY KEY,
  holder        TEXT NOT NULL,
  held_until    TIMESTAMPTZ NOT NULL
);
```

```ts
// ❌ Two instances both pass the check and both run
if (!await isJobRunning('nightly-cleanup')) {
  await markRunning('nightly-cleanup');
  await runCleanup();
  await markFinished('nightly-cleanup');
}

// ✅ Atomic claim via UPDATE — only one row is returned
const claimed = await db.query(
  `UPDATE job_leases
      SET holder = $1, held_until = now() + interval '10 minutes'
    WHERE job_name = 'nightly-cleanup'
      AND held_until < now()
   RETURNING holder`,
  [instanceId],
);
if (claimed.rowCount === 1) {
  try { await runCleanup(); }
  finally {
    await db.query(`UPDATE job_leases SET held_until = now() WHERE job_name = $1 AND holder = $2`,
      ['nightly-cleanup', instanceId]);
  }
}
```

The lease has a TTL longer than the worst expected runtime, so a crashed worker self-heals. The job itself must still be idempotent — a lease is defense in depth, not a substitute for idempotency.

## Atomic counters and aggregates

Read-modify-write of a counter from app code is a lost-update bug waiting to happen.

```sql
-- ❌ Lost update under concurrency
SELECT view_count FROM posts WHERE id = $1;   -- both readers see 100
UPDATE posts SET view_count = 101 WHERE id = $1;
UPDATE posts SET view_count = 101 WHERE id = $1;   -- final value: 101, should be 102

-- ✅ Atomic in the database
UPDATE posts SET view_count = view_count + 1 WHERE id = $1;
```

Same shape for balances, stock levels, score totals. If the new value depends on the old one and concurrency is possible, the arithmetic must happen in the `UPDATE` statement, not in the application.

## Upsert is idempotent — when the conflict target is right

`INSERT … ON CONFLICT` is the cleanest way to make an insert retry-safe, but the conflict target must match the business key exactly:

```sql
-- ✅ Retry-safe: same (user_id, day) always lands on the same row
INSERT INTO daily_logins (user_id, day, count)
VALUES ($1, current_date, 1)
ON CONFLICT (user_id, day) DO UPDATE SET count = daily_logins.count + 1;
```

Watch the trap: `ON CONFLICT DO UPDATE` with `SET *` will silently overwrite columns the retry didn't intend to change. Always spell out the columns.

## Outbox pattern (reliable event publishing)

You cannot atomically write to a database AND publish to a message bus. Either the DB commits and the publish fails, or vice versa. The outbox pattern fixes this:

```sql
-- Same transaction as the business write
BEGIN;
INSERT INTO orders (id, ...) VALUES (...);
INSERT INTO outbox (id, topic, payload, created_at) VALUES (gen_random_uuid(), 'order.placed', $1, now());
COMMIT;
```

A separate publisher process reads `outbox`, publishes to the bus, marks rows sent. Consumers must dedupe on the message ID — at-least-once delivery still applies. The idempotency burden has been moved to the consumer, where it belongs.

## Sagas (compensating transactions)

When a single use case spans services and you can't have one transaction, model it as a sequence of local transactions plus compensations: `bookFlight → bookHotel → chargeCard`, with `cancelFlight`, `cancelHotel`, `refundCard` as compensations. Each forward step **and** each compensation must be idempotent — the saga orchestrator will retry both on failure.

## Retry policy

Retry only operations that are idempotent or guarded by an idempotency key. Use exponential backoff with full jitter, cap attempts, and surface the original error after exhaustion. See `error-handling` for the reference implementation; the rules below are the concurrency-specific ones:

- Never retry a `POST` that creates resources without an idempotency key.
- Never retry a payment without an idempotency key — Stripe and similar APIs require one for safe retries.
- A 5xx response means "outcome unknown", not "failed". The work may have completed; only the response was lost. Treat as a candidate for retry **only if** the request was idempotent.
- Log every retry attempt with the same correlation ID as the original request — see `logging-observability`.

## TOCTOU classics — same shape everywhere

Time-of-check / time-of-use bugs all have the same shape: read state, decide based on it, then act on the assumption the state didn't change.

```ts
// ❌ Filesystem TOCTOU
if (await fs.exists(path)) await fs.unlink(path);   // unlink can race with another deleter

// ❌ Cache TOCTOU
const cached = await cache.get(key);
if (cached) return cached;
const fresh = await computeExpensive();             // many requests stampede past the miss
await cache.set(key, fresh);

// ❌ Remote-state TOCTOU
const status = await stripe.charge.retrieve(id);
if (status.status === 'pending') await stripe.charge.capture(id);   // could already be captured
```

Fixes: rely on operations that fail loudly when the assumption breaks (`unlink` then ignore ENOENT; cache lock or single-flight; idempotent capture API). Detect the pattern by asking "what if the world changed between this `if` and this action?" — if the answer is "we'd corrupt something", it's TOCTOU.

## HTTP method semantics

By spec: `GET`, `PUT`, `DELETE` are idempotent; `POST` is not. That's why public APIs require idempotency keys on `POST` and not on the others. When designing endpoints (see `api-design`), prefer `PUT` to a stable URL for create-or-update flows where the client knows the ID — that's idempotent for free.

## Where idempotency lives

Per `layered-architecture`: the idempotency boundary is the service/handler layer, not the controller and not the repository. The controller parses the `Idempotency-Key` header; the service holds the `INSERT ... ON CONFLICT` against the idempotency table inside the same transaction as the business write; the repository just persists. Splitting it any other way leaks transport concerns into persistence or duplicates the dedup table per route.

## Common mistakes

- **Trusting "exactly-once" delivery** — every broker offers either at-least-once or at-most-once. Exactly-once is always end-to-end (broker + idempotent receiver), never the broker alone.
- **App-level dedup instead of a unique index** — only the database can serialize concurrent inserts; app checks are TOCTOU.
- **Idempotency table without a `completed`/`in_flight` distinction** — two parallel retries both think they're first and both run the work.
- **Idempotency table without a TTL** — grows forever, eventually dominates the database.
- **Holding `SELECT … FOR UPDATE` across an HTTP call** — your row is now locked for the duration of someone else's downtime.
- **`UPDATE` without `WHERE version = ?`** on data multiple users can edit — last write silently wins.
- **TTL-only distributed locks treated as a correctness guarantee** — process pauses break them; you need fencing tokens or a consensus system.
- **Cron job with no lease** — the day a second instance comes up (rolling deploy, autoscale) you double-run.
- **Retrying a non-idempotent `POST`** — at best wasted work, at worst double-charged customers.
- **Outbox without consumer dedup** — solved one half of the problem, ignored the other.
- **`SET count = $appComputedValue`** — race-condition lost update; use `SET count = count + 1` instead.
- **`ON CONFLICT DO UPDATE` that overwrites unrelated columns** — the retry "succeeds" but silently corrupts state.

## Related

- `error-handling` — retry with backoff, transient vs permanent classification, never-swallow rule.
- `api-design` — `Idempotency-Key` header conventions, HTTP method semantics, error envelope for `409 Conflict`.
- `db-migration-safety` — adding the `UNIQUE` index, `version` column, or `idempotency_keys` table is itself a migration; expand-contract still applies.
- `logging-observability` — every retry, dedup hit, lease acquisition, and version conflict must be logged with a correlation ID.
- `layered-architecture` — idempotency boundary lives in the service/handler, never the controller, never the repository.
- `domain-modeling` — aggregates and version fields; saga compensations are domain events.
