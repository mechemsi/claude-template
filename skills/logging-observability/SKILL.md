---
name: logging-observability
description: Use when adding `console.log` or any logging; when debugging an issue that only happens in production; when designing how a system reports its health; when adding metrics, dashboards, or alerts; when a bug requires correlating events across services; or when sensitive data might end up in logs.
---

# Logging and Observability

You can't fix what you can't see. Treat logs and metrics as production code: structured, leveled, correlated, and free of secrets.

## When to apply

- Reaching for `console.log` to debug something
- A new service or new public-facing endpoint
- Designing alerts or on-call runbooks
- Reviewing PRs that touch error paths
- Adding any field that comes from user input or third-party data

## The three pillars

| Pillar | Question it answers | Examples |
|--------|---------------------|----------|
| **Logs** | What happened? | structured event records |
| **Metrics** | How much / how often? | counters, gauges, histograms |
| **Traces** | Where did time go? | distributed spans across services |

You don't need all three from day one, but design as if you'll add them.

## Structured logging

**Plain strings are write-only.** A JSON-shaped log is queryable.

```ts
// ❌
console.log(`User ${user.id} placed order ${order.id} for $${total}`);

// ✅
log.info('order.placed', {
  userId: user.id,
  orderId: order.id,
  totalCents: total.cents,
  currency: total.currency,
});
```

Use a logger (`pino`, `winston`, `bunyan`) — never `console.log` in production code.

### Required fields on every log line

- `timestamp` (ISO 8601, UTC)
- `level` (`trace` | `debug` | `info` | `warn` | `error`)
- `message` (short, stable, machine-parseable name like `order.placed`)
- `service`, `version`, `env`
- `traceId` / `correlationId` (see below)

### Levels

| Level | When |
|-------|------|
| `trace` | Per-line internals, almost never enabled |
| `debug` | Verbose flow info for diagnosis, off in prod |
| `info` | Normal events worth knowing about (request done, job complete) |
| `warn` | Recoverable abnormality (retry succeeded, cache miss spike) |
| `error` | Something failed and someone may need to act |

If every line is `info`, the level system is useless. Be deliberate.

## Correlation / trace IDs

A request entering an API spawns DB queries, downstream calls, queue messages — all should share one ID so you can reconstruct the request later.

```ts
// At the boundary, generate or accept a request ID
app.use((req, _res, next) => {
  req.id = req.headers['x-request-id']?.toString() ?? randomUUID();
  next();
});

// Propagate it into the logger context
const log = baseLogger.child({ requestId: req.id });
log.info('charge.start', { amount });
await chargeCard(card, amount);  // chargeCard's logs also carry requestId
```

In Node, `AsyncLocalStorage` lets you carry the ID across async hops without threading it through every signature.

For multi-service traces, use OpenTelemetry — instruments HTTP, DB drivers, queues automatically.

## What to log

| Always | Never |
|--------|-------|
| Request start/end at the boundary, with method/path/status/duration | Passwords, tokens, API keys, session cookies |
| Errors with full context (operation, IDs, error class) | Full credit card numbers, CVCs |
| State transitions (order placed, user upgraded) | Government IDs, health data, raw PII unless required & encrypted |
| External calls (host, latency, status) | Stack traces in user-facing responses |
| Slow operations (over a threshold) | The entire request body in plain text |

When in doubt, redact. Most loggers support a redaction config — use it:

```ts
const log = pino({
  redact: ['req.headers.authorization', 'password', 'token', '*.creditCard'],
});
```

## What NOT to log

- A success log on every line of code. Logs document **noteworthy** events, not playback.
- Errors that are part of normal flow (e.g. "user not found" on a check-existence endpoint).
- The same event at multiple levels (don't log it `info` then catch and log it `error` two stacks up).

## Metrics: RED and USE

For every service, expose at least:

**RED** (request-shaped systems):
- **R**ate — requests per second
- **E**rrors — failed requests per second
- **D**uration — latency distribution (p50, p95, p99)

**USE** (resources):
- **U**tilization — % busy
- **S**aturation — queue depth / rejected work
- **E**rrors — error count

Counter ≠ histogram. Latency is always a histogram (you need percentiles, not averages).

```ts
// pseudocode with prom-client
httpRequestsTotal.inc({ method: 'POST', route: '/orders', status: 201 });
httpDuration.observe({ method: 'POST', route: '/orders' }, durationSeconds);
```

Cardinality matters: never put unbounded values (user IDs, request IDs) in metric labels — it explodes the time series database.

## Alerts

Alerts must be:
- **Actionable** — there's something a human should do.
- **Tied to user impact** — a 0.1% error rate on a healthcheck endpoint is not an alert.
- **Have a runbook** — if you can't write one, the alert isn't ready.

Symptom-based alerts ("error rate over 1% for 5 min") beat cause-based alerts ("CPU high") every time.

## Local debugging vs production

Locally, pretty-print logs with colors. In production, JSON one-line. Set the level via env var (`LOG_LEVEL=debug` for incident triage).

```ts
const log = pino({
  level: process.env.LOG_LEVEL ?? 'info',
  transport: process.env.NODE_ENV === 'development'
    ? { target: 'pino-pretty' }
    : undefined,
});
```

## Common mistakes

- `console.log` left in committed code (use the logger; tests should fail PRs that introduce `console.*`).
- Logging the user's password "just for debugging" — this leaks even if you remove the line later (logs were already shipped).
- Logging the same error three times as it bubbles up — log it once, at the boundary.
- Average latency on a dashboard — useless. Always p50/p95/p99.
- Alerts without runbooks — pages with nothing to do erode trust.

## Related

- `error-handling` — what errors *are*; this skill covers how they're *seen*.
- `12-factor-app` — factor XI says treat logs as event streams; don't manage log files in-app.
- `security-review` — redaction, PII handling, audit trails.
