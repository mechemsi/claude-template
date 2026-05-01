---
name: layered-architecture
description: Use when a controller, route handler, command, or HTTP/RPC entry point imports a repository, ORM client (Prisma, Sequelize, Mongoose, Knex), or DB driver directly; when `prisma.x.findMany`/`db.query` calls appear inside a Next.js route, Express controller, or NestJS controller; when deciding where business logic should live across controller, service, and repository; when a "service" is a one-line passthrough or a controller exceeds ~200 lines doing data access; when designing CQRS command/query handlers; when transaction boundaries are unclear or scattered across layers.
---

# Layered Architecture

Controllers and commands handle transport. Services and handlers run use cases. Repositories persist. Each layer talks only to the next one in.

## When to apply

- A Next.js route, Express controller, or RPC handler is calling `prisma.*`, `db.query`, or any ORM method directly
- Business rules (`if order.status === 'shipped' throw`) live inside a controller
- The same use case is reimplemented in two transports (HTTP + queue worker) because logic lives in the controller
- Tests need to spin up an HTTP server just to test "cancel order" behavior
- A "service" exists but is `async list() { return repo.findAll(); }` — adds no boundary
- Transactions are opened/committed in a controller, or worse, in a repository

## The rule

```
┌──────────────────────┐   parses request, returns response.
│  Controller / Cmd    │   no business logic, no repos.
└──────────┬───────────┘
           │ calls one method
           ▼
┌──────────────────────┐   one use case per method (or per Handler).
│  Service / Handler   │   loads aggregates, calls domain, saves, opens TX.
└──────────┬───────────┘
           │ depends on interface
           ▼
┌──────────────────────┐   loads & saves aggregates. no business rules.
│  Repository          │
└──────────┬───────────┘
           ▼
       database
```

Dependencies point inward only. Controllers know about services; services know about repositories; repositories know about the DB. Never the other way.

## Layer responsibilities

| Layer | Owns | Must NOT |
|-------|------|----------|
| **Controller / Route / Command** | Auth check, request parsing, validation envelope, status code, serialization | Open transactions, call repositories, branch on domain state |
| **Service / Handler** | Use case orchestration, transaction boundary, calling domain methods, emitting events | Format HTTP responses, parse query strings, render JSON envelopes |
| **Domain entity / aggregate** | Invariants, state transitions (`order.cancel()`), domain rules | Know about HTTP, DB, or framework types |
| **Repository** | Load and persist aggregates, query for read models | Embed business rules, decide what should happen, throw domain errors |

## ❌ Controller reaches into the repo

```ts
// src/app/api/v1/orders/[id]/cancel/route.ts
import { prisma } from '@/lib/prisma';

export async function POST(req: Request, { params }: { params: { id: string } }) {
  const order = await prisma.order.findUnique({ where: { id: params.id } });
  if (!order) return Response.json({ error: 'NOT_FOUND' }, { status: 404 });
  if (order.status === 'shipped') {
    return Response.json({ error: 'ALREADY_SHIPPED' }, { status: 409 });
  }
  await prisma.order.update({
    where: { id: params.id },
    data: { status: 'cancelled', cancelledAt: new Date() },
  });
  return Response.json({ success: true });
}
```

Problems:
- Business rule (`status === 'shipped'`) lives in transport. The next worker that cancels orders will copy-paste it — and drift.
- No transaction boundary: a follow-up step (refund, audit log) added later won't be atomic.
- Untestable without spinning up Next.js + Prisma.

## ✅ Controller delegates to a service

```ts
// src/server/orders/cancel-order-service.ts
export class CancelOrderService {
  constructor(
    private readonly orders: OrderRepository,
    private readonly clock: Clock,
    private readonly events: EventBus,
  ) {}

  async execute(cmd: { orderId: OrderId; actorId: UserId }): Promise<void> {
    await this.orders.withTransaction(async (tx) => {
      const order = await tx.findById(cmd.orderId);
      if (!order) throw new OrderNotFound(cmd.orderId);
      order.cancel(this.clock.now());           // domain enforces invariants
      await tx.save(order);
      this.events.publish(new OrderCancelled(order.id, cmd.actorId));
    });
  }
}
```

```ts
// src/app/api/v1/orders/[id]/cancel/route.ts
import { cancelOrderService } from '@/server/container';
import { requireSession } from '@/server/auth';

export async function POST(req: Request, { params }: { params: { id: string } }) {
  const session = await requireSession(req);
  try {
    await cancelOrderService.execute({
      orderId: asOrderId(params.id),
      actorId: session.userId,
    });
    return Response.json({ success: true });
  } catch (e) {
    return mapDomainError(e);   // single place that knows HTTP status codes
  }
}
```

The same `CancelOrderService` is reused by a queue worker, a CLI, and a test — none of them duplicate the rule.

## CQRS handlers

Same idea, one class per use case. Useful when use cases multiply or you want each to be deployable as its own unit.

```ts
interface CommandHandler<C, R = void> { execute(cmd: C): Promise<R>; }

class CancelOrderHandler implements CommandHandler<CancelOrderCommand> {
  constructor(private readonly orders: OrderRepository, private readonly events: EventBus) {}
  async execute(cmd: CancelOrderCommand): Promise<void> { /* ... */ }
}

// Controller dispatches; doesn't know which handler runs.
await commandBus.dispatch(new CancelOrderCommand(orderId, actorId));
```

For reads, mirror the structure with query handlers that return DTOs (not aggregates):

```ts
class GetOrderSummaryHandler {
  constructor(private readonly db: ReadDb) {}
  async execute(q: { orderId: OrderId }): Promise<OrderSummaryDto | null> {
    return this.db.query(/* hand-written SQL or read-optimized projection */);
  }
}
```

Read queries are allowed to bypass the domain — they don't mutate.

## Transaction boundary

Lives in the service/handler, never the controller, never the repository.

```ts
// ✅ Service owns the unit of work
await this.orders.withTransaction(async (tx) => {
  const order = await tx.findById(id);
  order.applyDiscount(coupon);
  await tx.save(order);
  await this.audit.record(tx, /* ... */);  // same TX
});
```

Repositories expose a `withTransaction` (or accept a transactional handle) but do not decide *when* a transaction starts.

## Cross-aggregate work

Don't load aggregate A's repo from inside aggregate B's handler to mutate both atomically. That's a sign your aggregate boundaries are wrong, or you should use eventual consistency (domain event → second handler → second TX).

```ts
// ❌ One handler reaching into two aggregate repos
class PlaceOrderHandler {
  async execute(cmd) {
    const order = /* ... */;  await this.orders.save(order);
    const customer = /* ... */;  customer.incrementOrderCount();  await this.customers.save(customer);
  }
}

// ✅ One TX = one aggregate. Other side reacts to the event.
class PlaceOrderHandler { /* saves order, publishes OrderPlaced */ }
class IncrementCustomerOrderCountOnOrderPlaced { /* listens, opens its own TX */ }
```

## Testing pays for the boundary

| Layer | What you test it with |
|-------|------------------------|
| Domain entity | Pure unit test, no repo, no DB |
| Service / handler | In-memory repository fake, no HTTP |
| Repository | Integration test against real DB |
| Controller | Smoke test: parse → call service spy → format response |

If you find yourself needing Prisma to test a business rule, the rule is in the wrong place.

## Common mistakes

- **Anemic services** — `userService.findById(id) → userRepo.findById(id)`. If a service is pure passthrough today, **keep the boundary** (it's where logic will land tomorrow), but don't write a layer of fake methods. Generate them, or just expose the repo via the service constructor and add real methods as needed.
- **Smart repositories** — repo methods named `cancelOrder` or `chargeAndPersist`. Repos persist; they don't decide. Move the logic to the entity or service.
- **ORM types leaking out** — returning `Prisma.Order` from a controller. The controller should map to a DTO; aggregates shouldn't be Prisma rows.
- **Transactions in controllers** — `await prisma.$transaction(...)` inside a route handler. Push it down.
- **Service-per-entity instead of service-per-use-case** — `OrderService` with 30 methods becomes the new God object. Prefer one class per use case (or grouped by tightly-coupled use cases).
- **Read queries forced through aggregates** — loading the entire `Order` aggregate just to render a list view. For reads, query directly against a read model or projection.
- **Controllers that call multiple services to assemble a view** — that's a query handler / read model, not three round-trips orchestrated in transport code.

## Related

- `solid-principles` — DIP (services depend on `Repository` interface, not Prisma) and SRP (one reason to change per layer).
- `domain-modeling` — Repository, Domain Service, and Aggregate are the building blocks this skill arranges.
- `structural-patterns` — Service is a Facade over domain + repository; CQRS handlers are Command pattern from `behavioral-patterns`.
- `error-handling` — domain errors are thrown by entities/services and translated to HTTP at the controller boundary.
- `api-design` — controller's job is the HTTP envelope (status, validation error format, pagination meta); pair with this skill.
- `testing-architecture` — the test pyramid this layering enables (unit on domain, integration on repos, smoke on controllers).
