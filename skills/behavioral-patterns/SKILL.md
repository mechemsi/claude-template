---
name: behavioral-patterns
description: Use when designing how objects interact, communicate, or distribute responsibilities; when modeling state transitions; when several handlers might process a request; when undo/redo, queueing, or logging of operations is needed; when one object's change must notify many; or when picking among interchangeable algorithms at runtime.
---

# Behavioral Design Patterns

Ten patterns for how objects assign responsibilities and communicate. They mostly replace conditional logic ("which handler? which algorithm? what state?") with composition.

## When to apply

| Symptom | Pattern |
|---------|---------|
| Series of handlers, each may handle or pass on | Chain of Responsibility |
| Encapsulate a request as an object (queue, log, undo) | Command |
| Traverse a collection without exposing its structure | Iterator |
| Many objects communicate in tangled mesh | Mediator |
| Need to snapshot/restore object state (undo) | Memento |
| One-to-many notification on state change | Observer |
| Behavior changes when state changes | State |
| Pick interchangeable algorithm at runtime | Strategy |
| Algorithm skeleton fixed, steps vary by subclass | Template Method |
| New operation over a stable object structure | Visitor |

## Quick reference

| Pattern | One-line intent |
|---------|-----------------|
| Chain of Responsibility | Pass request along a chain until one handles it |
| Command | Encapsulate a request as an object |
| Iterator | Sequentially access elements without exposing internals |
| Mediator | Centralize complex communications between peers |
| Memento | Capture and restore an object's state |
| Observer | Notify multiple observers when subject changes |
| State | Alter behavior when internal state changes |
| Strategy | Define a family of algorithms and make them interchangeable |
| Template Method | Define algorithm skeleton; let subclasses vary specific steps |
| Visitor | Define new operation on an object structure without modifying it |

---

## Chain of Responsibility

```ts
interface Handler { handle(req: Request): Response | null; setNext(h: Handler): Handler; }

abstract class BaseHandler implements Handler {
  private next: Handler | null = null;
  setNext(h: Handler): Handler { this.next = h; return h; }
  handle(req: Request): Response | null { return this.next ? this.next.handle(req) : null; }
}

class AuthHandler  extends BaseHandler { handle(r: Request) { if (!r.user) return { status: 401 }; return super.handle(r); } }
class RateLimiter  extends BaseHandler { handle(r: Request) { if (overLimit(r)) return { status: 429 }; return super.handle(r); } }
class RouteHandler extends BaseHandler { handle(r: Request) { return route(r); } }

const chain = new AuthHandler();
chain.setNext(new RateLimiter()).setNext(new RouteHandler());
```

**Use when.** Middleware-like processing, event filters. Most web frameworks ship a built-in version — use it.

---

## Command

```ts
interface Command { execute(): void; undo(): void; }

class AddTextCommand implements Command {
  constructor(private doc: Doc, private text: string, private at: number) {}
  execute() { this.doc.insert(this.at, this.text); }
  undo()    { this.doc.remove(this.at, this.text.length); }
}

class History {
  private stack: Command[] = [];
  do(c: Command) { c.execute(); this.stack.push(c); }
  undo()         { this.stack.pop()?.undo(); }
}
```

**Use when.** Undo/redo, request queueing, transaction logging, deferred execution.

---

## Iterator

```ts
class Tree<T> implements Iterable<T> {
  constructor(private root: Node<T> | null) {}
  *[Symbol.iterator](): IterableIterator<T> {
    function* visit(n: Node<T> | null): IterableIterator<T> {
      if (!n) return;
      yield* visit(n.left);
      yield n.value;
      yield* visit(n.right);
    }
    yield* visit(this.root);
  }
}

for (const value of new Tree(root)) { /* in-order */ }
```

In TS/JS, prefer the language's `Symbol.iterator`/generators rather than building Iterator classes by hand.

---

## Mediator

```ts
interface Mediator { notify(sender: Component, event: string): void; }

class FormMediator implements Mediator {
  constructor(private input: TextInput, private button: Button, private list: List) {
    input.setMediator(this); button.setMediator(this);
  }
  notify(sender: Component, event: string) {
    if (sender === this.input && event === 'change') this.button.setEnabled(this.input.value.length > 0);
    if (sender === this.button && event === 'click') this.list.add(this.input.value);
  }
}
```

**Use when.** Components reference each other in a many-to-many mesh. The mediator becomes the only thing peers know about.

---

## Memento

```ts
class EditorMemento { constructor(readonly content: string, readonly cursor: number) {} }

class Editor {
  constructor(public content = '', public cursor = 0) {}
  save(): EditorMemento { return new EditorMemento(this.content, this.cursor); }
  restore(m: EditorMemento) { this.content = m.content; this.cursor = m.cursor; }
}
```

Pairs naturally with Command for undo. Memento captures *state*; Command captures *intent*.

---

## Observer

```ts
type Listener<E> = (event: E) => void;

class EventBus<E> {
  private listeners = new Set<Listener<E>>();
  subscribe(l: Listener<E>): () => void { this.listeners.add(l); return () => this.listeners.delete(l); }
  publish(e: E): void { this.listeners.forEach(l => l(e)); }
}
```

**Use when.** One-to-many state propagation. Beware: in-process observers can hide control flow. Prefer reactive libraries (RxJS) or framework primitives (React state, Vue refs) when they fit.

---

## State

```ts
interface OrderState { pay(o: Order): void; ship(o: Order): void; }

class Pending implements OrderState {
  pay(o: Order)  { o.setState(new Paid()); }
  ship(o: Order) { throw new Error('not paid'); }
}
class Paid implements OrderState {
  pay(_: Order)  { throw new Error('already paid'); }
  ship(o: Order) { o.setState(new Shipped()); }
}
class Shipped implements OrderState {
  pay(_: Order)  { throw new Error('already shipped'); }
  ship(_: Order) { throw new Error('already shipped'); }
}
```

**Use when.** A `switch (this.status)` appears in many methods of one class. Each branch becomes a state class.

---

## Strategy

```ts
interface ShippingStrategy { cost(weightKg: number): number; }
class StandardShipping implements ShippingStrategy { cost(w: number) { return 5 + w * 1.2; } }
class ExpressShipping  implements ShippingStrategy { cost(w: number) { return 12 + w * 2.0; } }

class ShippingService {
  constructor(private strategy: ShippingStrategy) {}
  setStrategy(s: ShippingStrategy) { this.strategy = s; }
  quote(weightKg: number): number { return this.strategy.cost(weightKg); }
}
```

**Use when.** A computation has multiple interchangeable variants chosen at runtime. In TS, often a function type (`type Strategy = (w: number) => number`) is enough.

---

## Template Method

```ts
abstract class ReportGenerator {
  generate(): string {
    const data = this.fetch();
    const transformed = this.transform(data);
    return this.format(transformed);
  }
  protected abstract fetch(): Row[];
  protected abstract transform(rows: Row[]): Row[];
  protected format(rows: Row[]): string { return rows.map(r => r.toString()).join('\n'); }
}
```

**Use when.** Algorithm shape is fixed, individual steps differ. **Don't use** when you can pass functions as parameters — Strategy via function composition is usually simpler in JS/TS.

---

## Visitor

```ts
interface AstVisitor<T> {
  visitNumber(n: NumberNode): T;
  visitAdd(a: AddNode): T;
  visitMul(m: MulNode): T;
}

interface AstNode { accept<T>(v: AstVisitor<T>): T; }

class Evaluator implements AstVisitor<number> {
  visitNumber(n: NumberNode): number { return n.value; }
  visitAdd(a: AddNode): number     { return a.left.accept(this) + a.right.accept(this); }
  visitMul(m: MulNode): number     { return m.left.accept(this) * m.right.accept(this); }
}
```

**Use when.** Adding new operations over a stable object structure (compilers, interpreters, document tree analyses). **Don't use** when the structure changes more often than the operations — switch becomes painful.

## State vs Strategy (frequent confusion)

- **Strategy**: caller picks the algorithm. The class doesn't know which strategy is in use.
- **State**: the object replaces its strategy *itself* in response to internal events. State transitions are part of the model.

## Common mistakes

- Reaching for Observer when a function call would do (one consumer? not Observer).
- Implementing Iterator by hand instead of using `Symbol.iterator`/generators.
- Using Visitor for two operations on one structure (KISS — methods on the nodes are fine).
- Modeling every CRUD field as a Command — Command shines when commands carry behavior (undo, queue, retry).

## Related

- `solid-principles` — Strategy/State are OCP applied to algorithms/states.
- `code-smells` — Switch Statements is the smell most of these patterns cure.
- `structural-patterns` — Composite often pairs with Iterator and Visitor.
