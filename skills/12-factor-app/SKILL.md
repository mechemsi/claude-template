---
name: 12-factor-app
description: Use when configuring a service for production; when adding env vars or secrets; when a service is hard to deploy, scale, or run on a new environment; when a deployment behaves differently in dev vs prod; when adding background jobs; or when designing how a process should start, stop, and recover.
---

# The Twelve-Factor App

A discipline for building services that scale, deploy cleanly, and behave the same in dev as in prod. Originally from Heroku; still the floor for any production web service in 2026.

## When to apply

- New service from scratch
- Existing service that's hard to deploy or hard to test in prod-like config
- Adding background work, queues, or scheduled jobs
- Hardening a service for autoscaling
- "Works on my machine" bugs

## Quick scorecard

Score each factor 0/1 on the current service. Anything below 8 is technical debt.

| # | Factor | Pass = |
|---|--------|--------|
| 1 | Codebase | One repo per service, many deploys from it |
| 2 | Dependencies | Explicitly declared and isolated |
| 3 | Config | Stored in env vars, never in code |
| 4 | Backing services | Treated as attached resources via URL/credentials |
| 5 | Build, release, run | Strictly separated stages |
| 6 | Processes | Stateless and share-nothing |
| 7 | Port binding | Self-contained — exports HTTP via a port, no external server needed |
| 8 | Concurrency | Scale out via the process model |
| 9 | Disposability | Fast startup, graceful shutdown |
| 10 | Dev/prod parity | Same backing services, short deploy gap |
| 11 | Logs | Treated as event streams written to stdout |
| 12 | Admin processes | Run as one-off processes against the same code |

---

## I. Codebase

One codebase tracked in version control, many deploys (dev / staging / prod).

```
✅ One repo → multiple environments (different config)
❌ Multiple repos for "the same app" with diverged code
❌ Sharing code across services via copy-paste
```

Sharing code? Make it a library, version it, depend on it.

## II. Dependencies

Declared explicitly (`package.json`), isolated (lockfile + node_modules per project).

```
✅ Lockfile committed; CI uses --frozen-lockfile / npm ci
❌ Installing globally and assuming it's there
❌ Missing dep that "happened to be there" via another lib's transitive
```

See `.claude/rules/dependency-management.md`.

## III. Config — in the environment

Anything that varies between deploys is config: DB URLs, credentials, feature flags, hostnames.

```ts
// ❌ Hardcoded
const db = connect('postgres://localhost:5432/myapp');

// ❌ Different config files per environment
const config = require(`./config.${env}.json`);

// ✅ Env vars
const db = connect(process.env.DATABASE_URL);
```

Validate config at boot, fail fast:

```ts
import { z } from 'zod';

const env = z.object({
  DATABASE_URL: z.string().url(),
  JWT_SECRET: z.string().min(32),
  PORT: z.coerce.number().default(3000),
}).parse(process.env);
```

Never commit `.env` files with real secrets. Commit `.env.example` with structure only.

## IV. Backing services as attached resources

DBs, caches, queues, third-party APIs are all "attached resources" pointed to by URL/credential. Swapping a local Postgres for AWS RDS should be one env-var change.

```ts
// ✅ Same code works against any Postgres
const db = new Postgres(process.env.DATABASE_URL);
```

Don't hardcode SQL features only one DB supports unless you've picked that DB as a hard requirement.

## V. Build, release, run — strictly separated

| Stage | What | Mutable? |
|-------|------|----------|
| **Build** | Compile code, fetch deps, produce artifact (image, bundle) | yes (during build) |
| **Release** | Combine artifact + config = release | no (immutable) |
| **Run** | Execute the release | no (config can't change without new release) |

Don't change code on the production server. Don't change config without a new release ID. Roll back = redeploy a previous release.

## VI. Processes — stateless, share-nothing

The process is ephemeral. State lives in backing services (DB, Redis, S3).

```
❌ In-memory user session map
❌ Files written to local disk and read across requests
❌ Sticky sessions because state is in-process
✅ Session in Redis, files in S3, anything multi-request in DB
```

You should be able to kill any process at any moment and lose nothing.

## VII. Port binding

The service is self-contained — it binds to a port and serves HTTP. No reliance on Apache, nginx, or a parent webserver embedding it.

```ts
const server = createServer(app);
server.listen(env.PORT, () => log.info('listening', { port: env.PORT }));
```

In front of it: load balancer, reverse proxy, CDN — but the app process itself is a complete server.

## VIII. Concurrency — scale out via processes

Need more capacity? Run more processes. The process is the unit of horizontal scale.

- Web requests → web process
- Background jobs → worker process
- Scheduled tasks → cron / scheduler process

Don't reach for in-process worker threads as the primary scaling story. They have their place (CPU-bound work, parallel file processing) but they don't replace process-level scale.

## IX. Disposability — fast startup, graceful shutdown

| Phase | Requirement |
|-------|-------------|
| Startup | Process is ready in seconds, not minutes |
| Shutdown | On SIGTERM: stop accepting new requests, finish in-flight, close DB connections |

```ts
// Graceful shutdown
let shuttingDown = false;
process.on('SIGTERM', async () => {
  shuttingDown = true;
  server.close();          // stop accepting new connections
  await drainWorkers();    // finish in-flight jobs
  await db.end();
  process.exit(0);
});

// Health endpoint
app.get('/health', (_req, res) => {
  if (shuttingDown) return res.status(503).send('shutting down');
  res.send('ok');
});
```

The orchestrator (Kubernetes, ECS) sends SIGTERM, waits a grace period, then SIGKILL. Use the grace window.

## X. Dev/prod parity

Keep dev, staging, and prod as similar as possible:
- Same DB engine and version (use Postgres locally if Postgres in prod — not SQLite).
- Same backing services (don't mock S3 with local files in dev unless you also test against real S3).
- Short gap between commit and deploy.

Docker / docker-compose helps locally; same image runs in prod.

## XI. Logs as event streams

The app writes unbuffered to **stdout**. The execution environment captures, routes, archives.

```
✅ console / logger writes to stdout
❌ App opens /var/log/myapp.log and rotates it itself
❌ Logging library configured to ship to a logging service from inside the app
```

Let the platform (systemd journal, Kubernetes log collector, Cloud Run) handle log shipping. Your app just writes events.

See `logging-observability` for what to write.

## XII. Admin processes — one-offs against the same code

DB migrations, data backfills, scheduled cleanups: run them as processes from the same codebase, with the same config.

```bash
# ✅ Same image, different command
node dist/scripts/migrate.js
node dist/scripts/backfill-prices.js --since=2026-01-01

# ❌ Running ad-hoc SQL from your laptop
# ❌ A scheduled task whose code lives in cron entries
```

Migrations checked into the repo, reviewed in PRs, run on deploy. Backfills as scripts in the repo, runnable in any environment.

## Common mistakes

- Storing config in `config/production.json` checked into git — forces a code change for any config change.
- Background jobs in the web process — slow requests when work piles up.
- Long startup (30s+) — autoscaling becomes useless.
- App writes its own log file — scales poorly, breaks under read-only filesystems.
- Different DB in dev (SQLite) than prod (Postgres) — bugs nobody catches locally.

## Related

- `.claude/rules/dependency-management.md` — factor II in detail.
- `logging-observability` — factor XI in detail.
- `error-handling` — graceful shutdown depends on careful error propagation.
- `api-design` — factor IV: backing services pointed to by URL/credential.
