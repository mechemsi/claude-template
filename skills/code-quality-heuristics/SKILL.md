---
name: code-quality-heuristics
description: Use when considering whether to extract a helper, create an abstraction, add a configuration option, or build for a future requirement; when copy-pasting code; when adding indirection; or when a piece of code feels too clever or too speculative.
---

# Code Quality Heuristics — DRY, KISS, YAGNI

Three rules that keep code small, simple, and grounded in real requirements. They sometimes pull against each other — the skill is knowing which one wins in context.

## When to apply

- About to copy-paste a block of code → DRY check
- About to introduce a base class, interface, or config flag → KISS + YAGNI check
- Found duplicated lines that look the same but mean different things → DRY trap
- Tempted to "make it generic" / "future-proof" / "in case we need it" → YAGNI red flag

## DRY — Don't Repeat Yourself

Every piece of *knowledge* should have one authoritative source. DRY is about knowledge, not characters.

**The rule of three.** Two similar fragments may be coincidence. Wait for the third before extracting — by then the real abstraction is visible. Premature extraction creates the wrong abstraction, which costs more than duplication.

```ts
// ⚠️ Looks duplicated, but represents different domain rules
function userDisplayName(u: User): string {
  return `${u.firstName} ${u.lastName}`;
}
function authorByline(a: Author): string {
  return `${a.firstName} ${a.lastName}`; // could change independently
}

// ❌ Wrong: forced abstraction couples unrelated concerns
function fullName(p: { firstName: string; lastName: string }): string { /* ... */ }
```

```ts
// ✅ Real DRY violation — one rule, repeated
function calculateTax(amount: number): number { return amount * 0.21; }
// ...elsewhere
const tax = price * 0.21; // duplicate the rate → drift waiting to happen
```

## KISS — Keep It Simple, Stupid

Choose the simplest design that solves the problem. Cleverness has a debugging cost.

```ts
// ❌ Clever
const isEven = (n: number) => !(n & 1);

// ✅ Obvious
const isEven = (n: number) => n % 2 === 0;
```

Signs of unnecessary complexity:
- A factory creating one product
- Generics with one usage site
- An event bus for two components that could call each other directly
- A configuration object for behavior the codebase never varies

## YAGNI — You Aren't Gonna Need It

Don't build for hypothetical future requirements. The future requirement is usually different from what you imagined, and the speculative code is now in the way.

```ts
// ❌ Over-engineered for "maybe we'll support multiple providers"
interface PaymentGateway { /* ... */ }
class StripeGateway implements PaymentGateway { /* ... */ }
class PaymentGatewayFactory { /* ... */ }
// Reality: only Stripe is integrated for the next 18 months.

// ✅ Build what's needed, refactor when the second case lands
class StripePayments { charge(amount: number): Promise<Charge> { /* ... */ } }
```

## When the heuristics conflict

| Situation | Winner | Why |
|-----------|--------|-----|
| 2nd duplication of a stable rule | DRY | Knowledge with one source of truth |
| 2nd duplication of arguably-unrelated code | KISS / YAGNI | Wait for the 3rd to confirm pattern |
| Clever abstraction removes 4 lines but adds 50 | KISS | Net complexity went up |
| Plug-in architecture for a single plug-in | YAGNI | Build the plug-in, not the plug-in system |

## Decision flow

```
About to add abstraction / extract / generalize?
│
├── Driven by a concrete current need (3rd duplication, real second consumer)?
│   ├── Yes → proceed (DRY)
│   └── No  → STOP. YAGNI.
│
└── Does the new design read more clearly than the current one?
    ├── Yes → proceed
    └── No  → STOP. KISS.
```

## Common mistakes

- Calling unrelated code "duplicated" because it *looks* similar — DRY is about knowledge, not syntax.
- Citing YAGNI to skip writing tests or handling errors — those are current needs, not future ones.
- Citing KISS to leave a 600-line function alone — simple to write isn't simple to read.

## Related

- `solid-principles` — SRP often resolves real DRY violations.
- `code-smells` — Long Method, Shotgun Surgery, Divergent Change are the symptoms these heuristics prevent.
