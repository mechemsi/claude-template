---
name: caching-strategies
description: Use when adding a cache layer (Redis, Memcached, in-memory, CDN, HTTP); when a slow query is being "fixed" by caching instead of being fixed; when designing TTLs and invalidation; when there is cache stampede / thundering herd risk on a hot key; when stale data shows up after a write; when designing cache keys with versioning; when deciding between cache-aside / read-through / write-through / write-back / refresh-ahead; when a request coalescing or stale-while-revalidate pattern is needed; when adding negative caching for misses; when considering caching per-user or PII data; when picking eviction (LRU/LFU/TTL); when an in-memory cache is unbounded; when reasoning about multi-tier caches (browser → CDN → app → Redis → DB).
---

# Caching Strategies

There are only two hard things in computer science: cache invalidation and naming things. The first one is what this skill is about — the rest is patterns that make invalidation tractable instead of magical.

## When to apply

- Adding any cache tier (in-process, Redis/Memcached, CDN, HTTP, browser)
- A request is slow and the proposed fix is "let's cache it"
- Designing TTLs, key formats, eviction policy, or purge logic
- A hot key, a stampede, or a "why is the DB on fire after deploy?" incident
- Stale reads showing up after a write
- Per-user / per-tenant / authenticated content is going through a shared cache
- Anything that smells like "we'll precompute it and store it somewhere fast"

## Core rule: caching is a contract that stale data is acceptable

Before any cache discussion, answer this in writing:

> *How stale can this value be before the user, the business, or the auditor cares?*

If the answer is "it can never be stale" you don't have a perf problem solvable by caching — you have a query, schema, or architecture problem. Fix that. Caching strict-consistency data is how you ship subtle, expensive bugs (wrong balances, dropped permissions, ghost inventory).

If the answer is "minutes are fine" or "seconds are fine" or "until the next write" — proceed.

## Pattern matrix

| Pattern | Read path | Write path | Consistency | Complexity | Pick when |
|---------|-----------|------------|-------------|------------|-----------|
| **Cache-aside** (lazy) | App reads cache → on miss, reads source, populates cache | App writes source; cache untouched (or purged) | Eventually consistent (TTL bound) | Low | Default. Read-heavy, infrequent writes, app owns the logic. |
| **Read-through** | App reads cache; cache fetches source on miss | App writes source; cache may auto-invalidate | Eventually consistent | Medium (cache lib does the work) | You want the cache to be the only data interface; app stays simple. |
| **Write-through** | Same as read-through | App writes cache and source synchronously | Read-after-write within a single instance — not across regions | Medium | Read-after-write needed locally; tolerates write-path latency. |
| **Write-back** (write-behind) | Same as read-through | App writes cache; flushed to source asynchronously | Strong on cache, durability risk on source | High | Counters, analytics, anywhere a brief write loss is acceptable for throughput. |
| **Refresh-ahead** | App reads cache; cache proactively re-fetches before TTL | Same as cache-aside | Eventually consistent, near-zero miss latency | High (needs prediction or schedule) | Hot, predictable keys where a miss is unacceptable (homepage, top-N). |

Default to **cache-aside** unless something specific makes another pattern obviously right. The other four are answers to specific problems, not aesthetic upgrades.

## Failure mode → mitigation matrix

| Failure mode | What happens | Mitigation |
|--------------|--------------|------------|
| **Stampede / thundering herd** | Hot key TTL expires; N concurrent misses all hit the source | Stale-while-revalidate, single-flight / request coalescing, probabilistic early expiration (XFetch), pre-warming on deploy |
| **Hot key** | One key gets disproportionate traffic; one shard saturates | Shard the key (`key:{hash%N}`), replicate across nodes, randomize TTL to break synchronized expiry |
| **Stale read** | Write completes; cache still serves the old value | Explicit purge on write, version-bump in key, write-through if budget allows |
| **Cache miss storm** | Cache restart / flush → every key misses simultaneously | Pre-warm critical keys on boot; randomize TTLs so they don't expire in lockstep |
| **Poisoned entry** | Bad write puts malformed value in cache; reads serve garbage until TTL | Validate on write; cache only after source-of-truth write succeeds; short TTL on values that come from external systems |
| **Unbounded growth** | In-memory cache with no size cap → OOM | Size cap + eviction policy (LRU/LFU); never use a `Map` as a "small" cache without bounds |
| **Cache outage** | Redis down → every request falls through to the DB at full RPS | Explicit fallback policy: serve last-good (if available), shed load, or fail fast — pick one and code it |
| **Synchronized expiry** | All keys written at deploy time share TTL → all expire together | Add jitter to TTL: `ttl = base + rand(0, base * 0.1)` |

## Cache-aside in practice

```ts
// ❌ Cache-aside that doesn't purge on write — guaranteed stale until TTL
async function updateUser(id: string, data: Partial<User>): Promise<User> {
  return db.users.update({ where: { id }, data }); // cache now stale for up to 5 min
}

// ✅ Purge on write — best-effort, but reads repopulate fresh
async function updateUser(id: string, data: Partial<User>): Promise<User> {
  const user = await db.users.update({ where: { id }, data });
  await cache.del(`user:${id}:v1`);
  return user;
}
```

The `del` is best-effort: a Redis hiccup can leave a stale entry. If `del` *must* succeed, use write-through or an outbox-driven purge (see `concurrency-and-idempotency`). For most read-mostly workloads, "best-effort purge + short TTL" is the pragmatic choice.

## Cache key design

Keys are an API. Once they exist in production they are hard to change.

```
svc:entity:id:vN[:scope][:format]
```

- **`svc`** — service or namespace (`auth`, `billing`). Prevents collisions when multiple services share Redis.
- **`entity`** — `user`, `order`, `session`.
- **`id`** — the natural key.
- **`vN`** — **schema version**. Bump it when the cached value's shape changes. Old entries naturally age out; no flush required.
- **`scope`** — anything that affects the response: locale, role, auth scope, currency.
- **`format`** — `json` vs `proto` vs `gzip` if you serve multiple.

```ts
// ❌ No version — can't roll out a new value shape without flushing the world
cache.get(`user:${id}`);

// ❌ Includes the request timestamp, so every call is a miss
cache.get(`user:${id}:${Date.now()}`);

// ✅ Versioned, scoped, deterministic
cache.get(`auth:user:${id}:v3:locale=${locale}`);
```

If a cached value depends on the caller's identity, that identity must be in the key. A user's "their orders" page cached under `orders:list:v1` will leak across users on the next deploy that forgets to add `user_id`. Be paranoid.

## Stampede mitigations

When a hot key expires and 500 RPS all miss simultaneously, the source gets all 500 in a window of milliseconds. Three patterns, in order of complexity:

**Stale-while-revalidate** — store value with two thresholds (`SOFT_TTL` and `HARD_TTL`). Within `SOFT_TTL`, serve fresh. Between `SOFT_TTL` and `HARD_TTL`, serve stale and trigger one background refresh. Past `HARD_TTL`, miss and refetch. The HTTP `stale-while-revalidate` directive is the same idea at the boundary.

**Single-flight / request coalescing** — within one process (or via Redis lock across processes), only the first miss runs `fetcher()`; the rest await its result. See `concurrency-and-idempotency` — same primitive.

**Probabilistic early expiration (XFetch)** — each request has a small probability of refreshing the entry *before* TTL, with probability rising as TTL approaches. Hot keys refresh themselves before they cliff; cold keys behave normally. Refresh when `now - generated_at >= TTL - delta * beta * ln(rand())`.

```ts
// ❌ Naive miss-then-fetch — every concurrent miss runs the fetcher
const v = await cache.get(key) ?? await fetcher();

// ✅ Single-flight via in-process map (extend with Redis SETNX cross-process)
const inflight = new Map<string, Promise<Value>>();
async function singleFlight(key: string, fetcher: () => Promise<Value>) {
  const cached = await cache.get(key);
  if (cached) return cached;
  let p = inflight.get(key);
  if (!p) {
    p = fetcher().finally(() => inflight.delete(key));
    inflight.set(key, p);
  }
  return p;
}
```

## Negative caching

A missing entry that doesn't exist *also* costs a DB hit on every request that asks for it. Cache the absence with a **shorter** TTL than positive entries — creates need to become visible quickly:

```ts
// ❌ Every request for a deleted user pounds the DB until a row exists
const cached = await cache.get(`user:${id}:v1`);
if (cached) return JSON.parse(cached);
const user = await db.users.findUnique({ where: { id } }); // null → not cached → re-query forever

// ✅ Cache the miss with a sentinel and a short TTL
const cached = await cache.get(`user:${id}:v1`);
if (cached === '__null__') return null;
if (cached) return JSON.parse(cached);
const user = await db.users.findUnique({ where: { id } });
if (user) await cache.set(`user:${id}:v1`, JSON.stringify(user), { ex: 300 });
else      await cache.set(`user:${id}:v1`, '__null__',           { ex: 30  });
return user;
```

Watch for an enumeration abuse vector — attacker IDs filling the cache with `__null__` sentinels. Bound by per-IP rate limits.

## Invalidation strategies

| Strategy | What it does | Failure mode | Use when |
|----------|--------------|--------------|----------|
| **TTL only** | Entries expire on their own | Stale window = TTL | Read-mostly data, low write rate, staleness budget exists |
| **Explicit purge on write** | Write path deletes affected keys | Purge can fail; partial purges | Read-after-write needed; writes are infrequent |
| **Versioned key** | Bump `vN` on schema/format change | Old keys still fill cache until they age out | Schema rollouts, format migrations — never a flush |
| **Tag-based** | Cache layer tracks tag → keys; invalidate by tag (Cloudflare, Varnish, some Redis modules) | Requires infra support; tag explosion if not bounded | Multi-key invalidation that maps to a business event ("invalidate this tenant") |

The key version is the rollout-safe one. To change the shape of a cached object: bump from `:v3` to `:v4` in code, deploy, watch the old keys evict naturally. Never run a `FLUSHALL` against a shared Redis to "clean up" — you'll DDoS your own database.

## HTTP caching (the boundary cache)

The cache contract for clients and CDNs lives in headers. Three response headers do most of the work:

- **`Cache-Control`** — `public`/`private`, `max-age`, `s-maxage` (CDN-only), `must-revalidate`, `no-store`, `stale-while-revalidate`, `stale-if-error`.
- **`ETag`** — strong validator; client returns it in `If-None-Match` for `304 Not Modified`.
- **`Vary`** — request headers that affect the response. **Critical** for authenticated content: without `Vary: Authorization` (or equivalent), a CDN serves User A's response to User B.

```
# ✅ Public; CDN 5min; serve stale 1 day on origin failure
Cache-Control: public, max-age=60, s-maxage=300, stale-while-revalidate=60, stale-if-error=86400

# ✅ Authenticated; do not share
Cache-Control: private, max-age=0, must-revalidate
Vary: Authorization, Accept-Encoding
```

`no-cache` means "revalidate before use", not "don't cache". `no-store` means "don't store". Confusing them is how confidential responses end up in shared caches. See `api-design`.

## Multi-tier thinking

A real request crosses several caches: `Browser → CDN → App in-memory → Redis → DB query cache → DB`. Each tier has its own TTL and invalidation path. "Invalidating the cache" almost always means "invalidating one of them". A Redis purge does nothing about the CDN copy; a CDN purge does nothing about each app server's local LRU.

Rules:

1. Pick which tier owns each piece of data and document it.
2. Inner-tier TTL ≤ outer-tier TTL — otherwise the inner cache outlives its parent's freshness signal.
3. On invalidation, purge from outermost (CDN) inward. The reverse leaves an outer copy serving stale.
4. In-process caches across N instances are N independent caches. "Purge everywhere" needs a pub/sub fanout (Redis `PUBSUB`, NATS) — and that fanout is best-effort.

## Hot-key problem

One key gets 80% of the traffic: a homepage feed, a global feature flag, a celebrity user. The shard holding that key saturates while the rest sit idle. Mitigations:

- **Shard the key**: `flag:dark_mode:{0..15}` written to all shards on update; readers pick `hash(client_id) % 16`. Trades write fan-out for read distribution.
- **Replicate**: serve from multiple Redis replicas, accept replication lag.
- **Local read-through cache** with very short TTL (1–5s) collapses N req/s per app server into one upstream read.
- **Randomize TTL** to spread the next miss wave: `ttl = base + jitter`.

## What NOT to cache

- **Per-user data with low reuse**: caching `GET /me` when each user calls it once a session adds a network hop instead of saving one.
- **Strongly consistent data**: account balances, inventory at checkout, role/permission decisions. Fix the query or use write-through with a confirmed source write — and think twice anyway.
- **PII without retention review**: caches are storage. They're subject to the same retention, deletion, and "right to erasure" rules. See `security-review`.
- **Staleness-as-security issues**: revoked tokens, banned-user flags, content takedowns, KYC results.
- **Things you don't know how to invalidate**: if "how does this refresh when source changes?" answers "it doesn't" or "later", don't cache.

## Caching and writes

Only write-through and explicit-purge-on-write give any read-after-write story. Cache-aside without a purge will *always* serve stale on the write path until TTL. Write-back is a durability tradeoff — bounded loss on cache failure, acceptable for analytics counters and not for orders or payments.

## Local in-memory caches

```ts
// ❌ Unbounded — leaks memory until OOM
const userCache = new Map<string, User>();

// ✅ Size-capped LRU with TTL
import { LRUCache } from 'lru-cache';
const userCache = new LRUCache<string, User>({ max: 10_000, ttl: 60_000 });
```

Even bounded, a per-instance cache is *N* independent caches in a horizontally-scaled service. Don't use it for user-specific or write-affected data — different requests see different values across instances. Reserve it for read-mostly reference data (config, feature flags, country lists) with a TTL you can tolerate as skew between instances.

## Cache poisoning

A cached bad value is worse than a slow query — it's wrong for everyone until TTL or the next purge.

```ts
// ❌ Cache populated even though the response is malformed (could be an HTML error page)
const raw = await externalApi.fetch(id);
await cache.set(`ext:${id}`, raw, { ex: 3600 });

// ✅ Validate before caching; never cache failure-shaped responses
const parsed = ExternalSchema.safeParse(await externalApi.fetch(id));
if (!parsed.success) throw new ExternalApiError('malformed response');
await cache.set(`ext:${id}`, JSON.stringify(parsed.data), { ex: 3600 });
```

Same rule for source-of-truth writes: cache *after* the DB commits, not before. A failed transaction that already wrote to cache leaves the cache permanently ahead of reality.

## Observability

Without these metrics you can't tune the cache and won't know when it breaks:

- **Hit rate** per cache and key prefix. A drop from 95% to 60% after a deploy is a key-format regression.
- **Miss latency** (p50/p99). Misses hit the source — slow but bounded.
- **Eviction rate**. High = cache too small. Zero = cache too large or TTLs too short.
- **Stampede counter**: concurrent misses overlapping on the same key.
- **Hot-key list** (top-K per minute). Spot a celebrity before it pages you.
- **Stale-serve rate** (with SWR): is "stale" the common case or the edge case?

Tag every call with `cache_name`, `op`, `key_prefix`. Per-key cardinality blows up dashboards — use prefixes. See `logging-observability`.

## Per-project derivation

Like `db-migration-safety`, the principles are universal but the toolchain varies. If `.claude/rules/caching.md` exists, it pins the answers. Otherwise ask once, document, then apply the matrix:

1. Which cache tier(s)? Redis / Memcached / DragonflyDB / Cloudflare / Varnish / Next.js Data Cache / in-process LRU.
2. Staleness budget for this data? Seconds, minutes, until-next-write?
3. Eviction policy and size cap? `maxmemory-policy` (Redis), `max` (`lru-cache`), etc.
4. How is invalidation propagated? Best-effort `DEL`, pub/sub fanout, key-version bump, CDN purge API?
5. Fallback when the cache is down? Serve last-good, shed load, fail fast — pick one and code it.

## Common mistakes

- **Caching to mask a slow query that should be fixed.** Caching ships the bug to a longer feedback loop. Fix the index or the query first; cache as the second layer of defense.
- **No version in cache keys.** A new value shape on deploy means either a flush (DB outage) or a bug (parser sees old shape). `:vN` makes rollouts boring.
- **Assuming write-through gives consistency in a multi-region setup.** It doesn't. The cache in region B sees the source change asynchronously.
- **Uncapped in-memory cache.** A `Map` you "only use for hot users" grows until OOM at 3am.
- **Identical TTLs across the keyspace.** Synchronized expiry → miss storm. Add jitter.
- **Caching PII without retention review.** Caches are storage; storage has retention obligations.
- **Cache as the system of record by accident.** Write-back without a verified flush, or "we just read from Redis and haven't queried the DB in months" — you have a Redis-shaped database with worse durability.
- **Ignoring eviction metrics.** "It's been fine" is a sentence said five minutes before eviction goes 100x and the DB melts.
- **`FLUSHALL` to fix a problem.** Every key misses, every miss hits the source, the source dies. Use a key-version bump instead.
- **Caching authenticated responses without `Vary: Authorization`** (or equivalent in your CDN) — leaks data across users.
- **Negative-caching with the same TTL as positive entries.** Long-lived `__null__` sentinels make legitimate creates invisible for too long.

## Related

- `api-design` — `Cache-Control`, `ETag`, `Vary`, and the HTTP cache contract are API-level decisions.
- `db-migration-safety` — bumping the cache key version is part of the rollout when a column type or response shape changes.
- `concurrency-and-idempotency` — single-flight / request coalescing is concurrency control over cache misses; the same primitive solves both.
- `error-handling` — cache miss is normal, cache *failure* (Redis down) needs an explicit fallback policy with retry rules.
- `logging-observability` — hit/miss/eviction/stampede/stale-serve metrics are mandatory; without them caching is faith.
- `12-factor-app` — caches are backing services (factor IV); same connection-string discipline as the database.
- `security-review` — caching authenticated content needs `Vary: Authorization`-equivalent thinking; PII in caches has retention obligations.
