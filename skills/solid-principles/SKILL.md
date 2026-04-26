---
name: solid-principles
description: Use when designing classes, services, or modules; when a class is doing too many things; when introducing inheritance; when an interface forces clients to depend on methods they don't use; or when high-level code reaches for low-level concrete classes.
---

# SOLID Principles

Five object-oriented design principles that keep code flexible and maintainable.

## When to apply

- A class keeps growing — multiple reasons to change it (SRP)
- Adding a feature requires editing existing tested code (OCP)
- A subclass throws on inherited methods or breaks parent contracts (LSP)
- An interface has methods half the implementers don't need (ISP)
- A high-level module imports a concrete DB/HTTP/email client directly (DIP)

## Quick reference

| Letter | Principle | Smell that signals violation |
|--------|-----------|------------------------------|
| S | Single Responsibility | One class formats, validates, AND persists |
| O | Open/Closed | Adding a payment method means editing `processPayment` |
| L | Liskov Substitution | `Square extends Rectangle` breaks `setWidth` |
| I | Interface Segregation | `IRepository` has 20 methods, most unused per caller |
| D | Dependency Inversion | `OrderService` does `new SmtpEmailer()` inside |

## S — Single Responsibility

A class should have one reason to change.

```ts
// ❌ Three responsibilities
class Invoice {
  calculate(): number { /* ... */ }
  toPdf(): Buffer { /* ... */ }
  save(): Promise<void> { /* ... */ }
}

// ✅ One responsibility each
class Invoice { calculate(): number { /* ... */ } }
class InvoicePdfRenderer { render(invoice: Invoice): Buffer { /* ... */ } }
class InvoiceRepository { save(invoice: Invoice): Promise<void> { /* ... */ } }
```

## O — Open/Closed

Open for extension, closed for modification. Add new behavior via new code, not edits to tested code.

```ts
// ❌ Adding a method = editing the switch
function fee(method: 'card' | 'bank' | 'crypto', amount: number): number {
  switch (method) { /* must edit for new methods */ }
}

// ✅ Add new method by adding a class
interface PaymentMethod { fee(amount: number): number; }
class CardPayment implements PaymentMethod { fee(a: number) { return a * 0.029; } }
class BankPayment implements PaymentMethod { fee(_: number) { return 0.5; } }
```

## L — Liskov Substitution

Subtypes must be usable wherever the base type is, with no surprises.

```ts
// ❌ Subclass weakens contract
class Bird { fly(): void { /* ... */ } }
class Penguin extends Bird { fly(): void { throw new Error('cannot fly'); } }

// ✅ Hierarchy reflects real capability
interface Bird { eat(): void; }
interface FlyingBird extends Bird { fly(): void; }
```

## I — Interface Segregation

Many small interfaces beat one fat one. Clients should not depend on methods they don't call.

```ts
// ❌ Read-only callers forced to depend on writes
interface UserRepo {
  findById(id: string): Promise<User>;
  create(u: User): Promise<void>;
  delete(id: string): Promise<void>;
}

// ✅ Split by capability
interface UserReader { findById(id: string): Promise<User>; }
interface UserWriter { create(u: User): Promise<void>; delete(id: string): Promise<void>; }
```

## D — Dependency Inversion

High-level modules depend on abstractions, not concrete implementations. Inject dependencies; don't `new` them inside.

```ts
// ❌ OrderService is welded to SMTP
class OrderService {
  private emailer = new SmtpEmailer();
  async place(o: Order) { await this.emailer.send(/* ... */); }
}

// ✅ Depend on an interface, inject the implementation
interface Emailer { send(to: string, body: string): Promise<void>; }

class OrderService {
  constructor(private emailer: Emailer) {}
  async place(o: Order) { await this.emailer.send(o.email, '...'); }
}
```

## Common mistakes

- Treating SRP as "one method per class" — it's about cohesion, not size.
- Premature OCP scaffolding (1 implementation, abstract base, 3 hooks). Apply when a second case actually appears.
- Splitting interfaces by file structure rather than caller needs (ISP is about callers, not authors).
- Confusing DIP with DI containers — inversion is about the direction of dependency, not the framework.

## Related

- `code-quality-heuristics` — when a SOLID refactor would violate YAGNI.
- `code-smells` — concrete refactorings that resolve SOLID violations.
- `creational-patterns`, `structural-patterns`, `behavioral-patterns` — patterns that operationalize OCP and DIP.
