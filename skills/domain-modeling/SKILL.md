---
name: domain-modeling
description: Use when designing data structures or entities for a business domain; when fields drift between layers (different shapes of "user" everywhere); when validation logic is scattered; when IDs are bare strings and get mixed up; when a class is "anemic" (just getters/setters with logic in services); when modeling money, dates, or other domain primitives.
---

# Domain Modeling (DDD essentials)

Encode business rules in types and objects so the compiler enforces invariants. Push logic *into* the data, not next to it.

## When to apply

- Adding a new entity, aggregate, or value object
- Three layers each have their own `User` type and they keep drifting
- Bug reports show "negative quantity allowed", "duplicate email created", "money rounded wrong"
- Service classes are 500+ lines of `if/else` over data they don't own
- IDs of different kinds are getting mixed (passing `userId` where `accountId` was expected)

## Building blocks

| Block | Purpose | Identity | Mutable? |
|-------|---------|----------|----------|
| **Value Object** | Describes a quality (Money, Address, Email) | None — equality by value | Immutable |
| **Entity** | Has a lifecycle and identity (User, Order) | ID | Mutable but state changes go through methods |
| **Aggregate** | Cluster of entities + VOs treated as a unit | Root entity's ID | Only the root mutates internals |
| **Repository** | Persists/loads aggregates | — | — |
| **Domain Service** | Logic that doesn't naturally belong to one entity | — | Stateless |
| **Domain Event** | Something happened (`OrderPlaced`) | — | Immutable record |

## Value Object

```ts
// ❌ Money as a number — easy to mix currencies, easy to round wrong
function total(items: { priceCents: number }[]): number {
  return items.reduce((s, i) => s + i.priceCents, 0);
}

// ✅ Money as a value object
class Money {
  constructor(readonly cents: number, readonly currency: 'USD' | 'EUR' | 'GBP') {
    if (!Number.isInteger(cents)) throw new Error('Money must be in integer cents');
  }
  add(other: Money): Money {
    if (other.currency !== this.currency) throw new Error('currency mismatch');
    return new Money(this.cents + other.cents, this.currency);
  }
  scale(factor: number): Money { return new Money(Math.round(this.cents * factor), this.currency); }
  equals(other: Money): boolean { return this.cents === other.cents && this.currency === other.currency; }
}
```

Other classic VOs: `Email`, `PhoneNumber`, `Address`, `DateRange`, `Percentage`, `Quantity`.

## Branded ID types

Stop strings of different kinds from being mixed:

```ts
type UserId = string & { readonly __brand: 'UserId' };
type AccountId = string & { readonly __brand: 'AccountId' };

function asUserId(s: string): UserId { return s as UserId; }
function asAccountId(s: string): AccountId { return s as AccountId; }

function transfer(from: AccountId, toUser: UserId, amount: Money): void { /* ... */ }

const u = asUserId('u_1');
const a = asAccountId('a_1');
transfer(u, a, new Money(100, 'USD'));  // ❌ compile error — caught by the brand
transfer(a, u, new Money(100, 'USD'));  // ✅
```

Tiny annotation, large class of bugs eliminated.

## Entity

An entity has identity. Two `Order` instances with the same fields are still different orders if their IDs differ.

```ts
class Order {
  constructor(
    readonly id: OrderId,
    private items: LineItem[],
    private status: OrderStatus,
  ) {}

  // State changes only via methods that enforce invariants
  cancel(): void {
    if (this.status === 'shipped') throw new CannotCancelShippedOrder();
    this.status = 'cancelled';
  }

  total(): Money {
    return this.items.reduce((sum, i) => sum.add(i.lineTotal()), Money.zero('USD'));
  }
}
```

Public mutators carry verbs (`cancel`, `addItem`, `applyDiscount`). No raw `setStatus(s)` — that bypasses the invariants.

## Aggregate

A boundary around entities + value objects that change together. Outside code can only touch the root.

```ts
class Order /* aggregate root */ {
  // External code holds a reference to Order, never to LineItem directly
  addItem(productId: ProductId, qty: Quantity, price: Money): void {
    if (this.status !== 'draft') throw new OrderNotEditable();
    this.items.push(new LineItem(productId, qty, price));
  }
  removeItem(productId: ProductId): void { /* ... */ }
}
```

Repositories load and save the whole aggregate. Don't leak `LineItem` references; the order owns them.

## Anemic vs rich models

```ts
// ❌ Anemic — data bag, logic elsewhere
class Order { items: LineItem[]; status: string; }

class OrderService {
  cancel(o: Order) {
    if (o.status === 'shipped') throw new Error('...');
    o.status = 'cancelled';
  }
  total(o: Order): number {
    return o.items.reduce((s, i) => s + i.price * i.qty, 0);
  }
}

// ✅ Rich — logic with the data
class Order {
  cancel() { /* ... */ }
  total() { /* ... */ }
}
```

Anemic models are an OO anti-pattern: the class holds the state but every operation lives somewhere else, leading to scattered invariants and impossible-to-find bugs.

**Exception**: in pure functional codebases, "data + functions" is the idiom. There, validate at construction (smart constructors) and keep functions pure. The principle is the same: invariants attached to the data.

## Repository

```ts
interface OrderRepository {
  findById(id: OrderId): Promise<Order | null>;
  save(order: Order): Promise<void>;
}
```

The repository abstracts persistence. Domain code depends on the interface (DIP). Implementations live in infrastructure (Prisma, Postgres, in-memory for tests).

## Bounded contexts

The same word means different things in different parts of the business.

> A `User` in **billing** has `paymentMethods` and `taxId`.
> A `User` in **auth** has `passwordHash` and `lastLogin`.
> A `User` in **support** has `tier` and `openTickets`.

These are three different types in three different modules. Don't unify them into one mega-User. Translate at boundaries (anti-corruption layer).

## Common mistakes

- Putting validation in services instead of constructors — invariants leak.
- Letting external code mutate aggregate internals — encapsulation broken.
- Using primitives (`number`, `string`) for things with rules (Money, Email) — bugs creep in.
- Building a "shared" `User` type used by every layer — drift, breakage, coupling.
- Confusing entity equality (by ID) with value equality (by fields).

## Related

- `solid-principles` — entities and aggregates are SRP applied to domain; repositories are DIP.
- `code-smells` — Primitive Obsession, Feature Envy, Data Clumps all signal a missing VO/entity.
- `error-handling` — domain errors live with domain code, raised by entity methods.
