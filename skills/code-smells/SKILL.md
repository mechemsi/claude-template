---
name: code-smells
description: Use when reviewing or refactoring existing code; when a function or class feels "too big"; when adding a feature requires touching many unrelated files; when conditionals keep growing; when bare strings/numbers spread through the codebase; or when a class spends more time using another class's data than its own.
---

# Code Smells & Refactoring

Code smells are surface symptoms of deeper design issues. Each smell maps to one or more refactoring techniques that resolve it.

## When to apply

- Reviewing a PR that "works" but feels off
- Adding a feature requires changes in 5+ unrelated files
- Conditionals keep gaining branches
- Tests are hard to write because setup is huge
- Bug fixes recur in the same area

## Quick reference

| Smell | Where it lives | Primary refactoring |
|-------|----------------|---------------------|
| Long Method | One function | Extract Method |
| Large Class | One class | Extract Class / Extract Module |
| Long Parameter List | Function signature | Introduce Parameter Object / Preserve Whole Object |
| Duplicated Code | Multiple functions/files | Extract Function, Pull Up Method |
| Feature Envy | Method using another class's data | Move Method |
| Data Clumps | Same group of params travels together | Extract Class |
| Primitive Obsession | Stringly-typed domain data | Replace Primitive with Object / Branded Types |
| Magic Literals | Unnamed numbers/strings sprinkled in code | Extract Constant / Replace with Enum or Union Type |
| Switch Statements | Type-based branching | Replace Conditional with Polymorphism (Strategy/State) |
| Shotgun Surgery | One change → many files | Move Method/Field, consolidate |
| Divergent Change | One class changes for many reasons | Extract Class (SRP fix) |
| Lazy Class | Class that does almost nothing | Inline Class |
| Dead Code | Never called | Delete (verify with usage search) |
| Speculative Generality | Hooks "for the future" | Inline / Remove (YAGNI) |
| Comments | Comments explaining what code does | Extract Method with intention-revealing name |

## Long Method

> A method longer than ~30 lines, multiple levels of indentation, or doing several things separated by blank-line "paragraphs".

```ts
// ❌ Multiple jobs in one function
async function checkout(cart: Cart, user: User): Promise<Order> {
  // validate
  if (!cart.items.length) throw new Error('empty');
  for (const i of cart.items) if (i.qty <= 0) throw new Error('bad qty');
  // price
  let subtotal = 0;
  for (const i of cart.items) subtotal += i.price * i.qty;
  const tax = subtotal * 0.21;
  // persist
  const order = await db.order.create({ /* ... */ });
  // notify
  await emailer.send(user.email, `Order ${order.id} placed`);
  return order;
}

// ✅ Each step has a name
async function checkout(cart: Cart, user: User): Promise<Order> {
  validateCart(cart);
  const totals = priceCart(cart);
  const order = await persistOrder(user, cart, totals);
  await sendOrderConfirmation(user, order);
  return order;
}
```

## Switch Statements (type-based branching)

```ts
// ❌ Switch on a type field — every new type edits this function
function area(s: Shape): number {
  switch (s.kind) {
    case 'circle': return Math.PI * s.r ** 2;
    case 'square': return s.side ** 2;
    case 'rect':   return s.w * s.h;
  }
}

// ✅ Replace Conditional with Polymorphism (Strategy)
interface Shape { area(): number; }
class Circle implements Shape { constructor(private r: number) {} area() { return Math.PI * this.r ** 2; } }
class Square implements Shape { constructor(private side: number) {} area() { return this.side ** 2; } }
```

See `behavioral-patterns` (Strategy, State) and `solid-principles` (OCP).

## Primitive Obsession

```ts
// ❌ Stringly-typed identifiers — easy to mix up
function transfer(fromAccount: string, toUser: string, amountCents: number): void { /* ... */ }
transfer(userId, accountId, dollars); // bug, compiler can't help

// ✅ Branded types or value objects
type AccountId = string & { readonly __brand: 'AccountId' };
type UserId = string & { readonly __brand: 'UserId' };
class Money { constructor(readonly cents: number) {} }
function transfer(from: AccountId, to: UserId, amount: Money): void { /* ... */ }
```

## Magic Literals

> A bare number or string literal whose meaning is not obvious from the value itself, especially when the same literal appears in more than one place. Distinct from Primitive Obsession (which is about *types*) — this is about *unnamed values*.

### Magic numbers

```ts
// ❌ What is 0.21? What is 86400?
const tax = subtotal * 0.21;
if (Date.now() - session.createdAt > 86400 * 1000) logout();

// ✅ Names carry the meaning
const VAT_RATE = 0.21;
const SESSION_LIFETIME_MS = 24 * 60 * 60 * 1000;
const tax = subtotal * VAT_RATE;
if (Date.now() - session.createdAt > SESSION_LIFETIME_MS) logout();
```

### Magic strings — finite domain → enum or union

```ts
// ❌ String literals scattered across the codebase
if (order.status === 'pending')   { /* ... */ }
if (order.status === 'PENDING')   { /* typo: silently never matches */ }
order.status = 'shipped';

// ✅ Closed set → string-literal union (TS-idiomatic) with a constant map
type OrderStatus = 'pending' | 'paid' | 'shipped' | 'cancelled';
const ORDER_STATUS = {
  Pending:   'pending',
  Paid:      'paid',
  Shipped:   'shipped',
  Cancelled: 'cancelled',
} as const satisfies Record<string, OrderStatus>;

if (order.status === ORDER_STATUS.Pending) { /* ... */ }
order.status = ORDER_STATUS.Shipped;
```

Use a `const`-object + union type instead of a TypeScript `enum` — `enum` has tree-shaking and runtime quirks, and the const-object pattern gives the same exhaustiveness.

### Security-sensitive values → environment variables, not constants

A constant is the right home for *domain* values (tax rate, retry count, status names). It is **not** the right home for *secrets or per-environment config* (API keys, DB URLs, JWT secrets, third-party endpoints that differ per env). Those go in `process.env.*` with boot-time validation.

```ts
// ❌ Hardcoded secret — leaks via git history forever
const STRIPE_KEY = 'sk_live_abc123…';

// ❌ Hardcoded per-env URL
const API_BASE = 'https://api.staging.example.com';

// ✅ Env var, validated at boot
import { z } from 'zod';
const env = z.object({
  STRIPE_SECRET_KEY: z.string().startsWith('sk_'),
  API_BASE_URL:      z.string().url(),
}).parse(process.env);
```

Decision rule:

| Value type | Where it lives |
|------------|----------------|
| Domain constant (rate, limit, status name, role) | Named `const` / union type / const-object map |
| Secret (API key, JWT secret, DB password) | `process.env.*`, never committed |
| Per-environment config (URLs, feature flags) | `process.env.*` |
| Test fixture / sample value | Test file, clearly labelled |

See `12-factor-app` (III. Config) and `security-review` (Secrets & Config) for the env-var side.

### When NOT to extract

- The literal is used exactly once and its meaning is obvious in context (`array[0]`, `n + 1`, `'\n'`).
- The value is the literal — e.g. a regex `^[a-z]+$` is clearer inline than as `LOWERCASE_RE`.
- Test inputs/expected outputs — extracting them obscures what the test asserts.

## Feature Envy

A method that calls multiple methods on another object more than its own. Move the method to where the data lives.

```ts
// ❌ Discount calculator reaches into Order constantly
class Discount {
  applyTo(o: Order) {
    return o.subtotal() - o.subtotal() * o.customer.tier.rate;
  }
}

// ✅ Move the calculation to Order (or to the data it envies)
class Order {
  discounted(): Money { return this.subtotal().scale(1 - this.customer.tier.rate); }
}
```

## Shotgun Surgery vs Divergent Change

- **Shotgun Surgery**: one change → many files. Indicates scattered responsibility. Fix by *consolidating*.
- **Divergent Change**: one class changes for many reasons. Violates SRP. Fix by *splitting*.

They're mirror images. Both point to misplaced responsibility.

## Common mistakes

- Treating long-but-linear functions as smelly — sequential pipelines can be fine if each step is named.
- Renaming a smell instead of fixing it — wrapping `userIdString` in a class called `UserIdString` is not a refactoring.
- Over-applying Replace Conditional with Polymorphism for a 2-case switch (KISS wins).
- Deleting "dead" code without checking dynamic call sites (reflection, route registries, DI containers).

## Related

- `solid-principles` — SRP, OCP underpin most refactorings here.
- `code-quality-heuristics` — DRY (real vs cosmetic), YAGNI (Speculative Generality).
- `behavioral-patterns` — Strategy/State for polymorphism replacements.
- `structural-patterns` — Decorator/Adapter for wrap-and-extend refactorings.
