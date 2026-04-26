---
name: structural-patterns
description: Use when composing or wrapping objects; when bridging incompatible interfaces; when building tree-like structures (menus, file systems, AST); when adding cross-cutting behavior (logging, caching, auth) without modifying the wrapped object; when a subsystem needs a simple front door; or when many fine-grained objects share state.
---

# Structural Design Patterns

Seven patterns for composing classes and objects into larger structures. Use when the question is "how do these pieces fit together?" rather than "how is this thing built?"

## When to apply

| Symptom | Pattern |
|---------|---------|
| Two interfaces don't match | Adapter |
| Want to vary abstraction and implementation independently | Bridge |
| Tree of "individual + groups of individuals" treated uniformly | Composite |
| Add behavior to objects dynamically without subclassing | Decorator |
| Big subsystem needs a simple front door | Facade |
| Lots of fine-grained objects, mostly identical state | Flyweight |
| Need to control access (lazy load, auth, cache) to an object | Proxy |

## Quick reference

| Pattern | One-line intent |
|---------|-----------------|
| Adapter | Make incompatible interfaces work together |
| Bridge | Decouple abstraction from implementation; vary independently |
| Composite | Treat individual objects and compositions uniformly |
| Decorator | Attach responsibilities dynamically; alternative to subclassing |
| Facade | Unified front for a complex subsystem |
| Flyweight | Share fine-grained objects to reduce memory |
| Proxy | Surrogate that controls access to another object |

---

## Adapter

**Intent.** Convert one interface into another your code expects.

```ts
// Existing client expects this
interface UserRepository { findById(id: string): Promise<User>; }

// Third-party SDK has this
class LegacyUserClient {
  async fetchUser(uid: string): Promise<{ uid: string; full_name: string }> { /* ... */ }
}

// Adapter
class LegacyUserAdapter implements UserRepository {
  constructor(private client: LegacyUserClient) {}
  async findById(id: string): Promise<User> {
    const u = await this.client.fetchUser(id);
    return { id: u.uid, name: u.full_name };
  }
}
```

**Use when.** Integrating a third-party API, migrating between two SDKs, or wrapping a legacy class behind a clean interface.

---

## Bridge

**Intent.** Separate an abstraction (what it does) from its implementation (how) so both can vary independently.

```ts
interface Renderer { drawCircle(r: number): void; drawSquare(s: number): void; }
class CanvasRenderer implements Renderer { /* ... */ }
class SvgRenderer    implements Renderer { /* ... */ }

abstract class Shape { constructor(protected r: Renderer) {} abstract draw(): void; }
class Circle extends Shape { constructor(r: Renderer, private radius: number) { super(r); } draw() { this.r.drawCircle(this.radius); } }
class Square extends Shape { constructor(r: Renderer, private side: number) { super(r); } draw() { this.r.drawSquare(this.side); } }
```

Now M shapes × N renderers = M+N classes, not M×N.

**Don't confuse with Adapter.** Adapter joins existing incompatible code. Bridge is a planned split before either side exists.

---

## Composite

**Intent.** Compose objects into trees and treat individual objects and compositions uniformly.

```ts
interface FsNode { name: string; size(): number; }

class File implements FsNode {
  constructor(public name: string, private bytes: number) {}
  size(): number { return this.bytes; }
}

class Folder implements FsNode {
  constructor(public name: string, private children: FsNode[] = []) {}
  add(n: FsNode): void { this.children.push(n); }
  size(): number { return this.children.reduce((s, c) => s + c.size(), 0); }
}
```

Callers don't care if a node is a file or folder — `node.size()` just works.

---

## Decorator

**Intent.** Wrap an object to add behavior at runtime without changing its class.

```ts
interface DataSource { read(): Promise<string>; }

class FileSource implements DataSource { /* reads file */ }

class CachingSource implements DataSource {
  private cache: string | null = null;
  constructor(private inner: DataSource) {}
  async read(): Promise<string> {
    if (this.cache === null) this.cache = await this.inner.read();
    return this.cache;
  }
}

class LoggingSource implements DataSource {
  constructor(private inner: DataSource) {}
  async read(): Promise<string> { console.log('read'); return this.inner.read(); }
}

const source = new LoggingSource(new CachingSource(new FileSource()));
```

**Use when.** Layering cross-cutting concerns (cache, log, auth, retry) over a domain object. Each decorator does ONE thing.

---

## Facade

**Intent.** Provide a simple interface to a complex subsystem.

```ts
class CheckoutFacade {
  constructor(
    private cart: CartService,
    private inventory: InventoryService,
    private payments: PaymentService,
    private orders: OrderService,
    private notifier: Notifier,
  ) {}

  async placeOrder(userId: string, paymentMethodId: string): Promise<Order> {
    const cart = await this.cart.get(userId);
    await this.inventory.reserve(cart.items);
    const charge = await this.payments.charge(paymentMethodId, cart.total);
    const order  = await this.orders.create(userId, cart, charge);
    await this.notifier.send(userId, `Order ${order.id} placed`);
    return order;
  }
}
```

**Use when.** Callers consistently coordinate multiple services in the same way.

---

## Flyweight

**Intent.** Share immutable parts ("intrinsic state") across many similar objects to save memory.

```ts
// Intrinsic state — shared
class Glyph { constructor(public char: string, public font: string, public size: number) {} }

const glyphCache = new Map<string, Glyph>();
function getGlyph(char: string, font: string, size: number): Glyph {
  const key = `${char}|${font}|${size}`;
  let g = glyphCache.get(key);
  if (!g) { g = new Glyph(char, font, size); glyphCache.set(key, g); }
  return g;
}

// Extrinsic state — per-occurrence (position, color) lives outside the Glyph
```

**Use when.** Millions of similar objects (game tiles, text glyphs, chart points) blow memory. Otherwise YAGNI.

---

## Proxy

**Intent.** A stand-in that controls access to a real object — for lazy loading, access control, caching, or remote calls.

```ts
interface ImageData { render(): void; }

class HeavyImage implements ImageData {
  constructor(private path: string) { /* loads from disk */ }
  render(): void { /* draws */ }
}

class LazyImageProxy implements ImageData {
  private real: HeavyImage | null = null;
  constructor(private path: string) {}
  render(): void {
    if (!this.real) this.real = new HeavyImage(this.path);
    this.real.render();
  }
}
```

**Common variants.**
- *Virtual proxy* — defer expensive creation (above).
- *Protection proxy* — check permissions before forwarding calls.
- *Remote proxy* — local stand-in for an object on another server (RPC clients).

**Decorator vs Proxy.** Same shape, different purpose. Decorator *adds* behavior to a real object. Proxy *controls access* to a real (or remote, or not-yet-loaded) object.

## Common mistakes

- Reaching for Decorator when middleware/pipelines fit better (web frameworks usually have one already).
- Using Facade as a dumping ground — keep it cohesive (one user-visible flow per facade).
- Flyweight optimizing memory that wasn't a problem (KISS).
- Adapter that does business logic — adapters translate, they don't decide.

## Related

- `solid-principles` — Adapter and Decorator are textbook OCP and DIP.
- `creational-patterns` — Bridge often pairs with Abstract Factory to build matching pairs.
- `behavioral-patterns` — Composite often pairs with Iterator and Visitor.
