---
name: testing-architecture
description: Use when deciding what kind of test to write (unit/integration/E2E); when test suites are slow or flaky; when deciding what to mock vs hit for real; when adding tests for a new service; when refactoring code that's hard to test; or when a test exists but doesn't catch the bug it should have.
---

# Testing Architecture

Tests give you confidence to change code. The architecture of your test suite — what level you test at, what you mock, how you isolate — determines whether tests *help* or *block* iteration.

## When to apply

- Designing tests for a new feature
- Test suite > 10 minutes locally, or flaky in CI
- Bug slipped through that "should have been caught"
- A change requires editing 50 tests
- Mocks are mocking your own code

## The pyramid (and when to invert it)

```
        /\          E2E   — few, expensive, real browser/HTTP
       /  \
      /    \        Integration — moderate, real DB / real HTTP server, mocked external APIs
     /------\
    /        \      Unit — many, fast, in-memory, pure logic
   /__________\
```

**Default ratios** (rough guideline, not a rule):
- ~70% unit, ~20% integration, ~10% E2E.

**Invert the pyramid** for thin services (a CRUD wrapper around a DB): the bugs live at the boundary, not in pure logic. Lean integration-heavy.

## What lives at each level

| Level | Tests | Doesn't test |
|-------|-------|--------------|
| **Unit** | Pure functions, value objects, domain logic | Anything touching IO, DB, HTTP |
| **Integration** | A service against real DB, real Redis, mocked third-parties | The browser, third-party servers |
| **E2E** | A user journey through the whole stack | Edge cases — those belong lower |

A test that takes 200ms is not unit. A test that pretends to be unit but spins up a Postgres container is misclassified.

## Mock the right things

### Mock these (boundaries you don't own)

- Third-party HTTP APIs (Stripe, Sendgrid)
- Time / clocks (fake timers, frozen `Date.now`)
- Random sources (seed)
- Environment-specific things (filesystem on Windows vs Linux)

### Don't mock these (your own code)

- Your repositories — use a test DB or in-memory implementation.
- Your domain entities — they're cheap, build real ones.
- Functions in the same module as the test — that means the test setup is a lie.

```ts
// ❌ Mocking your own service from a service test
const fakeOrderService = { place: vi.fn() };
// you've now tested nothing real

// ✅ Real OrderService, fake the third-party Stripe client
const orderService = new OrderService(realRepo, realPricer, fakeStripe);
```

### Heuristic

If you can't replace the mock with the real thing without changing test outcomes, you're testing the mock, not the system.

## Hexagonal / ports-and-adapters testing

Domain code depends on **ports** (interfaces). Real adapters in production, fake adapters in tests:

```ts
// Port (in domain layer)
interface PaymentGateway {
  charge(card: Card, cents: number): Promise<Charge>;
}

// Real adapter (infrastructure)
class StripeGateway implements PaymentGateway { /* ... */ }

// Test adapter (test code)
class InMemoryGateway implements PaymentGateway {
  charges: Charge[] = [];
  async charge(card: Card, cents: number) {
    const c = { id: `ch_${this.charges.length}`, cents };
    this.charges.push(c);
    return c;
  }
}
```

Now `OrderService` runs in tests with `InMemoryGateway` — fast, deterministic, no network. The same code in prod runs with `StripeGateway`.

## Test data

| Approach | When |
|----------|------|
| **Object literals inline** | One-off, the values matter to the test |
| **Builder / factory** | Many tests need similar fixtures with small overrides |
| **`faker` random data** | Tests of *types* of input, not specific cases |
| **Database snapshots / seeds** | Integration tests with shared baseline state |

Builders read well:

```ts
const order = orderBuilder()
  .withItem({ priceCents: 1000, qty: 2 })
  .withCustomer(customerBuilder().vip().build())
  .build();
```

Avoid huge fixture files referenced by name (`order_42.json`) — readers can't see what's relevant to the test.

## Test independence

- A test must pass alone and in any order. No shared mutable state between tests.
- Reset DB between integration tests (transaction rollback, or truncate, or template DB).
- Don't rely on test execution order. `it.skip` after a `it.before` that mutates is a bug.

## Flaky tests

A flaky test is broken — it must be fixed or quarantined immediately, never re-run.

Common causes:
- **Timing**: `await new Promise(r => setTimeout(r, 100))` — replace with a real signal (event, polling helper).
- **Order dependence**: parallel tests share a DB row.
- **External services**: real network in tests.
- **Time / random**: not seeded.

A red test in CI that "usually passes if you re-run" trains the team to re-run on every red. Then real failures get re-run too.

## What makes a good test

| Good | Bad |
|------|-----|
| Names describe behavior in plain English | `test_user_1`, `test it works` |
| Arrange / Act / Assert blocks visible | Logic and asserts mixed throughout |
| One reason to fail per test | Test asserts 8 things; first failure hides 7 |
| Tests survive refactors | Tests assert internal structure, break on rename |
| Reads like documentation of behavior | Reads like a copy of the implementation |

## Coverage targets are guides, not goals

Coverage tells you what's tested. It doesn't tell you it's *well* tested.

- Branch coverage > line coverage as a signal.
- 100% coverage with assertion-free tests proves nothing.
- 70% coverage with sharp tests beats 95% with shallow ones.

## What NOT to test

- Framework code (you don't need to test that React renders).
- Trivial getters/setters with no logic.
- Generated code.
- Third-party libraries you trust.

## Common mistakes

- "Unit" tests that boot a Postgres container — that's integration.
- Mocking your own classes — tests the mock, not the system.
- One test asserting eight things — first failure hides the rest.
- Re-running flaky tests in CI — masks real bugs.
- 100% coverage as a goal — leads to assertion-free tests.

## Related

- `solid-principles` — DIP makes mocking at boundaries trivial; SRP keeps tests narrow.
- `domain-modeling` — rich domain models test cleanly without touching IO.
- `error-handling` — every typed error needs a test that triggers it.
