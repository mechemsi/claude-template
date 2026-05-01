---
name: performance-optimization
description: Use when a task says "make it faster", "optimize", "speed up", or "improve performance"; when adding caching, parallelism, async, batching, or a worker pool to "make it faster"; when an N+1 query, missing index, or chatty API is suspected; when memory growth or a leak is being investigated; when picking between O(n²) and O(n log n) algorithms; when micro-optimizing CPU code while a DB or network call dominates the hot path; when no profile or flamegraph has been run yet; when allocating a p99 latency budget across services; when an SLO is at risk; when a benchmark on a laptop is being used to predict prod; when "premature optimization" is being introduced; when a regression test for a hot path is missing.
---

# Performance Optimization

Optimization without measurement is folklore. The discipline is: confirm the bottleneck, fix the bottleneck, prove the fix, gate against regression.

## When to apply

- Any task framed as "make X faster" or "optimize Y"
- Adding caching, parallelism, batching, async, or a worker pool to "improve performance"
- An SLO/latency budget is at risk and a fix is being scoped
- Suspected N+1 query, missing index, chatty API, or over-fetching
- Memory growth or a suspected leak in a long-running process
- Deciding between two algorithms or data structures
- Considering a code-level micro-optimization in a request that also makes DB or network calls

## Quick reference

### Optimization order

| Step | Action | Common output |
|------|--------|---------------|
| 0 | Confirm there is a problem (SLO/budget at risk, user-visible) | "p99 of /orders is 800ms, target is 200ms" |
| 1 | Profile the real workload | flamegraph, EXPLAIN ANALYZE, APM trace |
| 2 | Find the dominant cost | "60% in `OrderRepo.findByUser` due to N+1" |
| 3 | Remove the work, then make remaining work cheaper | batch fetch, then add index |
| 4 | Prove the fix on production-like data | before/after p50/p95/p99 |
| 5 | Add a regression gate | bench in CI, or perf test with threshold |
| 6 | Stop when the SLO is met | further 10% gains compound in cost |

### Latency hierarchy (orders of magnitude)

| Operation | Approximate cost |
|-----------|------------------|
| L1 cache reference | ~1 ns |
| Branch mispredict | ~5 ns |
| L2 cache reference | ~7 ns |
| Mutex lock/unlock | ~25 ns |
| Main memory reference | ~100 ns |
| Compress 1 KB | ~3 µs |
| Send 1 KB over 1 Gbps LAN | ~10 µs |
| SSD random read | ~150 µs |
| Read 1 MB sequentially from memory | ~250 µs |
| Round trip within datacenter | ~500 µs |
| Read 1 MB sequentially from SSD | ~1 ms |
| Disk seek (HDD) | ~10 ms |
| Round trip cross-region (US ↔ EU) | ~150 ms |

If your "hot loop" is doing CPU work next to a function that makes any kind of network call, the network call dominates by 4–6 orders of magnitude. Optimize the call, not the loop.

### Bottlenecks in order of likelihood (server-side)

1. **N+1 queries** — a loop that calls the DB once per item.
2. **Missing or wrong index** — a query that scans where it should seek.
3. **Synchronous I/O on the hot path** — blocking the event loop / request thread on a remote call.
4. **Over-fetching** — `SELECT *`, no `LIMIT`, no projection, no pagination.
5. **Chatty service-to-service calls** — 5 RPCs where 1 with a DTO would do.
6. **Serialization cost on large payloads** — JSON-encoding a 5 MB object on every request.
7. **Lock contention** — hot row, global mutex, single-threaded queue.
8. **GC / memory pressure** — allocations dominate CPU; throughput cliff at heap limit.
9. **CPU-bound application code** — actually rare in line-of-business systems.

If you skip the profile and start at #9, you will be wrong far more often than right.

## Measure first

> ❌ "I'll replace `forEach` with `for` to speed this up."
>
> ✅ "I'll run a flamegraph; if `forEach` shows up at >5% of CPU on the real workload, I'll consider rewriting it. I expect it won't."

A profile is not optional. Tools by layer:

| Layer | Tool |
|-------|------|
| Database (Postgres) | `EXPLAIN (ANALYZE, BUFFERS)`, `pg_stat_statements`, slow query log, `auto_explain` |
| Database (MySQL) | `EXPLAIN ANALYZE`, slow query log, `performance_schema` |
| Node.js | `--cpu-prof`, `--heap-prof`, Chrome DevTools, clinic.js, 0x |
| Python | `py-spy`, `cProfile`, `tracemalloc`, `memray` |
| JVM | async-profiler, JFR, VisualVM, JMH for microbenchmarks |
| Go | `pprof` (CPU + heap + block + mutex), `go test -bench`, `go test -trace` |
| .NET | dotnet-trace, dotnet-counters, PerfView |
| Ruby | rbspy, stackprof |
| HTTP request path | OpenTelemetry, Datadog APM, New Relic, X-Ray |
| Browser / SPA | Chrome Performance panel, Lighthouse, Web Vitals (LCP/INP/CLS), bundle analyzer |

The first profile is almost always surprising. If it isn't, the workload isn't realistic.

## Prefer removing work over making work faster

Most "optimizations" that succeed are removals.

| Instead of | Do |
|------------|-----|
| Optimizing how a list is built and returned | Paginate; return only what the caller renders |
| Caching a slow query | Add the missing index first; cache only what's still slow |
| Parallelizing a serial loop of HTTP calls | Batch them into one call (or fewer calls) |
| Faster JSON encoder | Smaller payload — drop fields, project columns |
| Faster image processing | Resize at upload time, store the variants, never recompute |
| Speeding up a poll loop | Replace polling with a webhook, an event, or a long-poll |

## N+1 — the canonical example

```ts
// ❌ One DB round-trip per order item.  100 orders → 100 queries.
async function ordersWithCustomer(userId: UserId) {
  const orders = await db.orders.findMany({ where: { userId } });
  for (const order of orders) {
    order.customer = await db.customers.findUnique({ where: { id: order.customerId } });
  }
  return orders;
}

// ✅ One round-trip for orders, one for the customers, zip in app code.
async function ordersWithCustomer(userId: UserId) {
  const orders = await db.orders.findMany({ where: { userId } });
  const ids = [...new Set(orders.map(o => o.customerId))];
  const customers = await db.customers.findMany({ where: { id: { in: ids } } });
  const byId = new Map(customers.map(c => [c.id, c]));
  return orders.map(o => ({ ...o, customer: byId.get(o.customerId) }));
}
```

Or use the ORM's eager-load primitive (`include`/`with`/`joinedload`) — same idea, fewer hand-rolled lines. Either way, two queries beats N+1.

## Big-O still matters

Algorithms dominate at scale even if the constants look fine on small data:

```ts
// ❌ O(n²) — fine at n=100, painful at n=10k, dead at n=100k
function intersect<T>(a: T[], b: T[]): T[] {
  return a.filter(x => b.includes(x));
}

// ✅ O(n) — Set membership is O(1) average
function intersect<T>(a: T[], b: T[]): T[] {
  const set = new Set(b);
  return a.filter(x => set.has(x));
}
```

Choose the algorithm before reaching for tricks.

## Latency budgets

Allocate the SLO across the request path. A 200ms p99 budget for `POST /orders`:

| Component | Budget | Notes |
|-----------|--------|-------|
| Ingress / TLS / routing | 5 ms | |
| Auth + session lookup | 10 ms | cached in Redis |
| Validation | 2 ms | |
| Domain logic | 5 ms | pure CPU |
| DB writes (1 TX, 3 statements) | 60 ms | |
| Outbound webhook (fire-and-forget) | 0 ms | enqueued, not awaited |
| Serialization + response | 8 ms | |
| Headroom | 110 ms | for tail-latency spikes |

If any single component exceeds its slice on the profile, that's where the work is. If everyone fits but the total is over budget, the SLO needs revising or the architecture needs work.

## Tail latency

Mean is a lie. Users experience p95 / p99 / p99.9. Median latency can be 50ms while p99 is 5s and the system feels "broken" — both numbers are true. Always plot the distribution. Common causes of tail blowup: GC pauses, lock contention, cache misses on cold keys, retries on a flaky downstream, autoscaling cold starts.

## Throughput vs latency

These are different problems.

| Goal | Lever | Cost |
|------|-------|------|
| Lower per-request latency | Skip work, parallelize independent steps, smaller payloads | App complexity |
| Higher throughput at the same latency | Add concurrency capacity, batching, connection pools | Memory, contention |
| Higher throughput, latency can rise | Aggressive batching, queueing | Per-item latency |

Batching trades latency for throughput. Don't apply it to a hot endpoint where users wait synchronously.

## Concurrency and parallelism

- **I/O-bound**: async/await, `Promise.all`, goroutines, threads with non-blocking I/O. Concurrency without parallelism is enough.
- **CPU-bound**: actual parallelism — workers, threads, multiprocessing, GPU. Adding `await` to CPU code adds overhead without gain.
- **Always cap concurrency.** Unbounded `Promise.all(arr.map(...))` over a 50k-item array will exhaust connections, file handles, or memory. Use a concurrency limiter (`p-limit`, semaphore, worker pool).
- **Backpressure.** A producer faster than the consumer needs a bounded queue and a drop/block policy, not unbounded buffering.

## Memory

- **Allocations vs retention.** A high allocation rate is a GC problem; high retention is a leak or oversized cache.
- **Streaming over buffering** for any payload bigger than ~1 MB. `req.pipe(transform).pipe(res)` beats `JSON.parse(await req.text())` on a 50 MB upload.
- **Heap snapshots** in long-running services after a load test reveal retainers no profiler will.
- **Cap in-memory caches.** Unbounded `Map<K, V>` without an eviction policy is a leak in disguise (cf. `caching-strategies`).

## Frontend essentials (briefly)

- **Bundle size**: code-split routes; tree-shake; defer non-critical chunks.
- **Images**: resize at upload, serve modern formats (AVIF/WebP), `loading="lazy"`, `srcset` for responsive sizes.
- **Web Vitals**: LCP < 2.5s, INP < 200ms, CLS < 0.1. Measure with Chrome's Web Vitals extension or RUM.
- **Render cost**: avoid layout thrashing; keep the main thread free; use `requestIdleCallback` for non-urgent work.
- **Network**: preconnect to critical origins; HTTP/2 multiplexing; cache static assets aggressively (cf. `caching-strategies`).

## Coordinated benchmarks

A laptop benchmark predicts a laptop. To predict prod:

- Same hardware class as prod (or a known multiple).
- Realistic data volume — at least 1× the size of the smallest prod tenant, ideally the median.
- Warm-up runs to avoid measuring JIT compilation or cold caches.
- Multiple runs; report p50/p95/p99, not "I ran it once and got 42 ms".
- Network conditions match — locally, both ends of the call are on `localhost`; in prod, they are not.

## Stop when the SLO is met

Each additional 10% gain costs disproportionately more code complexity. Past the SLO, optimization adds risk without business return. Lock in the win with a regression gate and move on.

## Regression gates

After fixing a hot path:

- Add a benchmark or load test that exercises the path with realistic data.
- Set a threshold (e.g. "p99 must stay under 250 ms on the standard fixture").
- Wire it into CI, marked as flaky-on-purpose if necessary so it warns rather than blocks — but it must run on every PR. Cross-link `ci-cd-pipeline`.
- Without this, a "while I was in here" change six weeks later silently regresses your fix.

## Common mistakes

- **Optimizing without a profile.** The mental model of where time is spent is wrong far more often than not.
- **Micro-optimizing CPU when the dominant cost is I/O or DB.** Six orders of magnitude separates them. The micro-opt is invisible.
- **Treating mean as p99.** Half your users still see the bad case.
- **Adding `async`/`await` to pure-CPU code.** Overhead without parallelism gain.
- **Caching to mask a query that should be indexed.** Indexes are cheaper, simpler, and fix it at the source. Cross-link `caching-strategies` and `db-migration-safety`.
- **Unbounded `Promise.all` / goroutine fan-out.** Works at 100 items, melts at 100k.
- **Benchmarking on cold caches and reporting steady-state numbers.** Or vice versa.
- **Optimizing for "scale we don't have".** YAGNI applies to perf — if today's prod is 1k QPS, don't rebuild for 1M QPS.
- **No regression test after the fix.** The next refactor will undo it silently.
- **Treating the framework's defaults as inviolable.** Default connection pool of 10? Default JSON parser? Default ORM include depth? All defensible defaults until they're the bottleneck.
- **Confusing throughput optimizations with latency optimizations.** Batching helps the first, hurts the second.
- **"Rewrite in a faster language"** before measuring. The same N+1 in Rust is still an N+1.

## Related

- `caching-strategies` — one major optimization lever, but only one. Don't reach for it before measuring.
- `db-migration-safety` — adding an index is a migration; treat it with migration discipline.
- `concurrency-and-idempotency` — parallelism is concurrency control; capped, idempotent, observable.
- `logging-observability` — RED/USE metrics and traces are how you spot a perf regression in prod.
- `testing-architecture` — perf tests are a level of test; same hygiene rules apply (deterministic, fast feedback).
- `code-quality-heuristics` — YAGNI applies to performance budgets too; don't pay complexity tax for headroom you'll never use.
- `error-handling` — timeouts, circuit breakers, and graceful degradation are perf primitives, not just reliability ones.
- `ci-cd-pipeline` — the regression gate this skill prescribes lives here.
