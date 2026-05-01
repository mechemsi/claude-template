---
name: feature-flags-and-rollout
description: Use when a feature is being put behind a flag/gate/toggle/experiment; when rolling a feature out incrementally (canary, blue/green, dark launch, percentage rollout); when a kill switch is being added; when a flag has been live past its planned launch date and "we should clean it up someday"; when evaluating a flag inconsistently per request causes UX flicker; when considering gating a database schema change behind a flag; when feature-flag debt is piling up and both branches of an old flag are getting partial maintenance; when designing rollout percentages and targeting rules; when a "release" and a "deploy" are being conflated; when permissions/entitlements are being implemented as runtime flags; when picking the safe default for when the flag service is unreachable.
---

# Feature Flags and Rollout

A feature flag is a runtime switch that **decouples deploy from release**. The deploy ships code; the flag flip exposes it. They can be hours, days, or weeks apart. That decoupling is the whole point — without it, "rollback" means another deploy, "canary" means another deploy, and "kill switch" means another deploy. With it, all three become a config flip observable in seconds.

The cost: every flag is a fork in the codebase. Both branches need tests, observability, and maintenance. Flags pay for themselves only when treated as code with a lifecycle: created with intent, removed on a schedule, audited on every flip.

## When to apply

- A change is risky, novel, or expensive-to-revert and needs a kill switch on the way to prod
- A feature is being rolled out to a subset of users (internal → 1% → 10% → 50% → 100%)
- An experiment / A/B test needs to assign and remember a variant per user
- A long-running migration code path must be toggleable (dual-read, dual-write)
- An external dependency might fail and you need to bypass it without a redeploy
- A regulatory or contractual requirement forces region- or tenant-specific behaviour
- A flag has been "temporary" past its planned lifespan and is now load-bearing in two states
- Someone is about to gate a schema change behind a flag (don't — see below)

## Toggle taxonomy (Pete Hodgson)

Different toggles have different lifespans, evaluators, defaults, and removal triggers. **Mixing categories is the root cause of most flag debt.** Classify at creation time and store the category in the flag's metadata.

| Category | Lifespan | Evaluator | Default when flag service is down | Removal trigger |
|----------|----------|-----------|------------------------------------|------------------|
| **Release** | Days–weeks | Per-user (stable hash) during ramp; all-on after | Off — fail-closed; new code stays dark | Once 100% has soaked, remove flag + dead branch in same PR |
| **Experiment** | Length of the experiment | Per-user (stable hash); variant persists per user | Control variant (so metrics aren't biased) | Experiment concludes → ADR → remove flag and losing branch |
| **Ops / kill switch** | Months–years (intentionally permanent) | Global or per-region | Safer side, per feature: kill-on when loss-of-feature is safer than loss-of-correctness | Never. Audit yearly to confirm still needed. |
| **Permission / entitlement** | Permanent | Per-user/tenant/role from auth/billing | "No entitlement" — fail-closed | Not a flag. Lives in auth/billing config with audit + ownership. |

Permission toggles are not feature flags. Implementing entitlements ("paid plan can use X") through the same system as release flags produces unauditable access changes — flag flips don't go through the same approval as RBAC changes. Keep them in separate systems even if the SDK looks identical.

## Release ≠ deploy

```
deploy:   ship code to prod (binary, container, lambda)
release:  expose that code to users (flag flip)
```

Once you internalize this:

- "Rollback" stops meaning "redeploy the previous binary" and starts meaning "flip the flag off". Seconds, not minutes.
- "Canary" stops meaning "deploy to one box and pray" and starts meaning "deploy to all boxes; expose to 1% of users".
- The merge-to-main bar drops from "this is the production behaviour" to "this code compiles, tests pass, and is dark by default". CI gets faster; deploys get less scary.

A release flag that lingers past the release date defeats this — both branches now ship every deploy, and rollback semantics become ambiguous. Ship → release → **clean up**, every time.

## Stable evaluation: hash on the actor, not the request

The same user must see the same value during a rollout window. Per-request evaluation produces flicker — same user sees the feature on, off, then on again across page loads. Flicker is a bug in every category of toggle.

```ts
// ❌ Per-request randomness — flickers for every user during rollout
function isEnabled(flag: string, percent: number): boolean {
  return Math.random() * 100 < percent;
}

// ❌ Hashed on the request ID — same user, different request = different result
function isEnabled(flag: string, ctx: { requestId: string }, percent: number): boolean {
  return hash(`${flag}:${ctx.requestId}`) % 100 < percent;
}

// ✅ Hashed on the stable actor ID — same user always gets the same answer
function isEnabled(flag: string, ctx: { userId: string }, percent: number): boolean {
  return hash(`${flag}:${ctx.userId}`) % 100 < percent;
}
```

For B2B, hash on `tenantId` not `userId` — otherwise half a team sees the new feature and the other half doesn't, generating support tickets. For regulatory rollouts, hash on `region`. **Never** hash on a request property (request ID, IP, session ID rotated per tab) unless flicker is acceptable for that surface.

The hash function must be deterministic across processes — same input on box A, box B, and the browser SDK must produce the same bucket. CRC32 or murmur3 over `flagKey:actorId` is standard.

## Defaults when the flag service is unreachable

Every flag SDK eventually fails to fetch config. The default in that moment is part of the contract.

```ts
// ❌ Silently fail-open — release flag turns on for 100% of users
//    when the flag CDN is unreachable
const showNewCheckout = flagSdk.get('new-checkout', { default: true });

// ✅ Release flag fails closed — keep the safe, shipped behaviour
const showNewCheckout = flagSdk.get('new-checkout', { default: false });

// ✅ Kill switch fails to "kill on" because loss-of-feature is safer
//    than loss-of-correctness here (a known buggy code path)
const useFlakyExternalPricing = flagSdk.get('flaky-pricing', { default: false });
//                                                              ^ kill-on by default

// ✅ Experiment fails to control — biased data is worse than no data
const variant = flagSdk.getString('signup-copy-test', { default: 'control' });
```

`default:` is not optional. Every call site declares what happens when the SDK can't reach the server, and that decision differs by toggle category. Code-review this every time.

## The rollout sequence

```
0% (deploy is dark)  →  internal users  →  1%  →  10%  →  50%  →  100%  →  remove flag + dead branch
```

Each step needs **a metric you'd revert on**, declared *before* the step starts. "We'll see" is not a rollback criterion. Write it down: error rate >0.5%, p99 latency >800ms, conversion drops by >10%, support tickets tagged `checkout` >X/hour. The flag flip *is* rollback — the bar for reverting at 1% should be low.

Worked example for `new-checkout`:

| Step | Audience | Soak | Revert if | Owner |
|------|----------|------|-----------|-------|
| 0 → internal | `tenant in INTERNAL_TENANTS` | 24h | any error in checkout error budget | @amy |
| internal → 1% | hash(userId) % 100 < 1 | 24h | success rate dips >2pp vs control | @amy |
| 1% → 10% | hash(userId) % 100 < 10 | 24h | p99 latency >700ms or success dips >1pp | @amy |
| 10% → 50% | hash(userId) % 100 < 50 | 48h | success dips >0.5pp or paged > once | @amy |
| 50% → 100% | all | 7d | any sev2+ traceable to flag | @amy |
| 100% → remove | flag deletion PR | — | post-removal regression in success rate | @amy |

## Rollback is the flag flip

Once the flag is the rollback mechanism, treat it as production infrastructure:

- **Flag flips must be observable end-to-end in <60s.** From console click to last cache TTL on the last edge node. If propagation is minutes, you don't have a kill switch — you have a slow redeploy.
- **The flip console must be available during an incident.** If the flag service auths through the same broken upstream causing the incident, you can't flip. Run the flag plane on independent infra.
- **Flips during incidents must not require code review.** Establish on-call authority to flip pre-approved kill switches. The incident is not the time to wake an architect.

## Don't gate schema changes behind flags

Schema is not runtime; flags are. A migration cannot be conditionally applied per user.

```ts
// ❌ Branching schema state on a flag — every read becomes a guess about
//    which columns exist on this row
if (flagSdk.get('new-pricing-model', { default: false })) {
  const row = await db.query('SELECT id, price_v2 FROM products WHERE id = $1', [id]);
  return row.price_v2;
} else {
  const row = await db.query('SELECT id, price FROM products WHERE id = $1', [id]);
  return row.price;
}

// ✅ Schema is safe regardless of flag state. Both columns exist; the flag only
//    chooses which one is read. The migration that added price_v2 was nullable,
//    backfilled, dual-written — see db-migration-safety.
const row = await db.query(
  'SELECT id, price, price_v2 FROM products WHERE id = $1', [id]);
const useV2 = flagSdk.get('new-pricing-model', { context: { userId }, default: false });
return useV2 ? row.price_v2 ?? row.price : row.price;
```

Rule: **the database must be safe no matter how the flag is set.** Flag-gate the *code path* that uses a new column; never flag-gate whether the column exists. Expand-migrate-contract happens *before* the flag rollout begins, not during. See `db-migration-safety`.

## Audit log

Every flag flip is a deploy without a diff. Every flip must record `who / what / when / from / to / reason`:

```
who:    user@example.com (and approver, if dual-control)
what:   flag=new-checkout, change=rollout 10% → 50%
when:   2026-05-02T14:31:18Z
from:   { rollout: 10, targeting: [...] }
to:     { rollout: 50, targeting: [...] }
reason: "Soak window passed, error budget intact"
```

If your flag platform doesn't emit this, replace it. A flag system without an audit log is not auditable infrastructure — and on the day a kill switch fires unexpectedly in prod, the audit log is the only thing standing between you and a multi-hour forensic.

## Telemetry tagging

Every event, log line, and trace span emitted from flag-gated code must carry the active flag values. Otherwise variant analysis is impossible: "is checkout slow?" becomes unanswerable when half the users are on the new path and half on the old.

```ts
// ❌ Metric averaged over both variants — dashboard goes flat, signal is lost
metrics.histogram('checkout.latency_ms', durationMs);

// ✅ Tag every emission with the active variant
const variant = flagSdk.getString('checkout-variant', { context: { userId }, default: 'control' });
metrics.histogram('checkout.latency_ms', durationMs, { variant });
logger.info('checkout.completed', { userId, variant, durationMs });
span.setAttribute('flag.checkout-variant', variant);
```

Non-negotiable for experiment toggles, strongly recommended during release ramps. See `logging-observability`.

## Cleanup discipline

A release flag at 100% is dead weight: two branches in code, two paths in tests, two paths in observability. The maintenance cost compounds every time someone touches surrounding code without realizing the flag is moot.

Every release/experiment toggle must declare at creation time:

```yaml
flag: new-checkout
category: release
owner: amy@example.com
created_at: 2026-04-15
removal_trigger: 2026-06-01   # date OR success metric
removal_ticket: ENG-1842
```

Schedule the cleanup the moment the flag ships — `/schedule` workflow, calendar reminder, tracked issue, recurring board sweep. A flag still in code 3 months past its launch date is a code smell; 18 months past is a maintenance landmine.

```ts
// ❌ Release flag from 18 months ago, both branches still here, neither
//    branch touched in a year. Nobody remembers which is current.
//    The off-branch is broken; nobody noticed because the flag is at 100%.
if (flagSdk.get('new-checkout-2024', { default: false })) {
  return renderNewCheckout(props);
} else {
  return renderLegacyCheckout(props);  // bit-rotted; would crash if flag flipped off
}

// ✅ Flag and dead branch removed in one PR after the soak window.
return renderCheckout(props);
```

When a removal date passes, escalate: open an issue, ping the owner, surface in a weekly audit (see `ci-cd-pipeline` "audit wiring"). Flag debt is debt.

## Multi-flag interactions

`n` boolean flags on the same surface = `2^n` behavioural variants. Three flags = eight code paths; only four are likely tested.

- **Cap concurrent active rollouts on the same surface.** Two is the practical limit; three needs explicit sign-off.
- **In CI, block PRs that introduce a third active flag on a surface that already has two.** The flag platform should know which flags touch which routes.
- **Test the matrix.** For `n` active flags, every variant in the on/off Cartesian product needs at least a smoke test. If you can't afford that, you have too many flags.
- **Document dependencies.** "Flag A only makes sense when Flag B is on." Encode it in the flag config (require B as a precondition) — don't leave it implicit.

## Targeting rules

| Targeting key | Use when | Example |
|----------------|----------|---------|
| `userId` hash bucket | Consumer rollout, individual experience | "10% of users see new checkout" |
| `tenantId` (workspace, org) | B2B — keep teams consistent | "5% of workspaces see new admin UI" |
| `region` / `country` | Regulatory, latency, language | "EU only", "JP first" |
| `userId IN (allowlist)` | Internal users, dogfood, beta program | "Employees + design partners" |
| `accountAge > N days` | Avoid disrupting long-tenured users | "New signups only get the new flow" |

Never target by request property unless flicker is acceptable. Never target by IP for personalization (mobile users roam, corporate NAT is shared, VPNs are common).

## Local dev and tests

Tests must force flag state deterministically. A test that asks the live flag service for `new-checkout` is non-hermetic, slow, and brittle.

```ts
// ❌ Test depends on whatever the prod flag service currently returns
test('checkout shows new layout', async () => {
  const result = await render(<Checkout />);
  expect(result).toMatchSnapshot();   // passes Monday, fails Friday
});

// ✅ Test pins the flag state for the duration of the test
test('checkout shows new layout when new-checkout is on', async () => {
  withFlag('new-checkout', true, async () => {
    const result = await render(<Checkout />);
    expect(result.getByTestId('new-checkout-root')).toBeInTheDocument();
  });
});

test('checkout shows legacy layout when new-checkout is off', async () => {
  withFlag('new-checkout', false, async () => {
    const result = await render(<Checkout />);
    expect(result.getByTestId('legacy-checkout-root')).toBeInTheDocument();
  });
});
```

CI runs the full matrix for active rollouts (every on/off combination) so the dead branch can't bit-rot silently. The branch at 0% in prod still ships with every deploy; if its tests don't run, the day you flip it on is the day you discover it's broken.

For local dev, support a flag override (`.flags.local`, env var, query string `?flags=new-checkout:on`) so a developer can toggle without round-tripping through the flag console.

## Permissions are not flags

```ts
// ❌ Entitlement implemented as a flag — flag-flip is not access control,
//    no per-customer audit, no approval workflow, no ownership
if (flagSdk.get('feature-x-paid-plan', { context: { userId }, default: false })) {
  return renderFeatureX();
}

// ✅ Entitlements live in the billing/auth system; flags are runtime experiments
if (await entitlements.has(userId, 'feature-x')) {
  return renderFeatureX();
}
```

Flag platforms make it tempting to express "paid plans only" as a flag with a tenant allowlist — the SDK is right there. Don't. Entitlements need clear ownership (billing, not feature engineering), per-customer audit of grants/revocations, automatic linkage to subscription state (canceled = lost entitlement), and different approval semantics. Mix the two systems and you eventually grant production access via a flag flip nobody approved.

## Common mistakes

- **Leaving release flags in code post-launch.** Both branches ship; one bit-rots; nobody remembers which is current. Flag debt compounds.
- **Gating schema changes behind flags.** Schema must be safe regardless of flag state. Migration is expand-migrate-contract; the flag controls the *code path*, not the schema shape.
- **Flag flips with no audit log.** A flip is a deploy without a diff; without an audit log, an unexpected flip is unforensicable.
- **Per-request flag evaluation.** Same user sees on/off/on across requests. UX flicker; metrics smeared across variants; experiment results invalid.
- **Permissions implemented as flags.** Flag flip becomes access control with none of the audit, approval, or ownership of RBAC. Eventually grants paid features for free.
- **Treating "deploy = release".** Loses the entire value of flags: rollback as a config flip, canary without redeploy, kill switches in seconds.
- **Defaults that fail-open for safety-critical features.** Flag CDN goes down → release flag silently turns on for 100% on stale config. Releases must fail-closed.
- **Running >2 active rollouts on the same surface.** Behaviour matrix explodes; off-by-default branches go untested; an interaction bug ships and is impossible to bisect.
- **Using `Math.random()` for rollout buckets.** Not stable per user, not deterministic across processes, not reproducible in tests.
- **Hashing on `requestId` instead of `userId`.** Same actor, different bucket per request → flicker.
- **No telemetry tag on the variant.** Dashboards average over variants; you can't tell whether the new path is the slow path; experiment analysis is impossible.
- **Kill switch propagation measured in minutes.** Not a kill switch — a slow redeploy. End-to-end propagation must be <60s including all caches.
- **A flag whose owner has left and whose removal date is in the past.** Everyone is afraid to flip it; nobody knows what it does. Audit yearly.
- **Trusting the flag service for correctness.** A flag check is a hint, not a security boundary. `if (flag) skipAuth()` is never acceptable.
- **Ignoring concurrency contracts inside gated code.** Flag-controlled writes still need idempotency keys and unique indexes — see `concurrency-and-idempotency`.

## Related

- `deploy` — release ≠ deploy; the deploy ships code, the flag flip releases it. Pre-deploy checklist asks "is this gated?"
- `ci-cd-pipeline` — required gates for active flags (matrix tests on on/off branches), audit-wiring for stale-flag detection.
- `db-migration-safety` — never gate schema changes behind flags; schema must be safe regardless of flag state. Expand-migrate-contract happens *before* the flag ramp begins.
- `error-handling` — fallback behaviour when the flag service is unreachable; defaults are part of the error contract.
- `logging-observability` — every event/log/trace from gated code must carry active flag values; otherwise variant analysis is impossible.
- `concurrency-and-idempotency` — flag-controlled writes still need idempotency keys, unique indexes, version columns. The flag is not a substitute for correctness primitives.
- `security-review` — kill switches and entitlements live near the auth boundary; permissions belong in the auth system, not the flag platform.
- `12-factor-app` — config from the environment; the flag system is the runtime config plane that complements env-var-style static config.
