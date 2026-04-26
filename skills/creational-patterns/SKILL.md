---
name: creational-patterns
description: Use when designing object construction logic; when a constructor takes many arguments; when which concrete class to build depends on runtime input; when complex initialization spans many steps; when shared state needs a single access point; or when copying complex objects.
---

# Creational Design Patterns

Five classic patterns for object construction. Each addresses a specific construction problem — pick by symptom, not by name recognition.

## When to apply

| Symptom | Pattern |
|---------|---------|
| Constructor takes 5+ args, many optional | Builder |
| Need to pick concrete class at runtime | Factory Method |
| Need to build *families* of related objects | Abstract Factory |
| Need exactly one instance with global access | Singleton (use sparingly) |
| Cloning an existing complex object is cheaper than rebuilding | Prototype |

## Quick reference

| Pattern | One-line intent |
|---------|-----------------|
| Factory Method | Subclass decides which concrete class to instantiate |
| Abstract Factory | Create families of related objects without naming concrete classes |
| Builder | Construct complex objects step by step; same steps → different shapes |
| Prototype | Create new objects by copying an existing instance |
| Singleton | Ensure a class has one instance, with global access |

---

## Factory Method

**Intent.** Defer instantiation to a function/method so callers don't depend on concrete classes.

```ts
interface Notifier { send(to: string, msg: string): Promise<void>; }
class EmailNotifier implements Notifier { /* ... */ }
class SmsNotifier implements Notifier { /* ... */ }

function createNotifier(channel: 'email' | 'sms'): Notifier {
  switch (channel) {
    case 'email': return new EmailNotifier();
    case 'sms':   return new SmsNotifier();
  }
}
```

**Use when.** A function would otherwise switch on a type tag and `new` different classes inline.

**Don't use when.** There's only one concrete class — just call `new`.

---

## Abstract Factory

**Intent.** Produce *families* of related objects (e.g., a UI kit's Button + Modal + Input) without binding to concrete implementations.

```ts
interface UiKit {
  createButton(): Button;
  createModal(): Modal;
}

class MaterialKit implements UiKit { /* returns Material variants */ }
class IosKit implements UiKit { /* returns iOS variants */ }

function renderApp(kit: UiKit) {
  const btn = kit.createButton();
  const modal = kit.createModal();
  // ...components are guaranteed to belong to the same family
}
```

**Use when.** You need multiple objects that must stay consistent as a set (theming, multi-DB drivers, payment ecosystems).

**Don't use when.** You only build one kind of object — Factory Method is enough.

---

## Builder

**Intent.** Construct a complex object step-by-step. The same construction process can produce different representations.

```ts
class QueryBuilder {
  private wheres: string[] = [];
  private fields: string[] = ['*'];
  private tableName = '';

  from(t: string): this { this.tableName = t; return this; }
  select(...f: string[]): this { this.fields = f; return this; }
  where(clause: string): this { this.wheres.push(clause); return this; }
  build(): string {
    const w = this.wheres.length ? ` WHERE ${this.wheres.join(' AND ')}` : '';
    return `SELECT ${this.fields.join(', ')} FROM ${this.tableName}${w}`;
  }
}

const sql = new QueryBuilder().from('users').select('id', 'email').where('active = true').build();
```

**Use when.** Constructor parameter list explodes, many parameters are optional, or construction has steps.

**Don't use when.** A plain object literal or named-parameters object suffices.

---

## Prototype

**Intent.** Create new objects by cloning an existing one rather than constructing from scratch.

```ts
interface Cloneable<T> { clone(): T; }

class Document implements Cloneable<Document> {
  constructor(public title: string, public sections: Section[]) {}
  clone(): Document {
    return new Document(this.title, this.sections.map(s => s.clone()));
  }
}

const draft = template.clone();
draft.title = 'My Draft';
```

**Use when.** Building from scratch is expensive (heavy I/O, complex defaults), or templates with small variations are common.

**Don't use when.** Plain `structuredClone()` or a copy constructor is enough.

---

## Singleton

**Intent.** Guarantee one instance with a single global access point.

```ts
class ConfigStore {
  private static instance: ConfigStore | null = null;
  private constructor(private values: Record<string, string>) {}

  static getInstance(): ConfigStore {
    if (!ConfigStore.instance) {
      ConfigStore.instance = new ConfigStore(loadFromEnv());
    }
    return ConfigStore.instance;
  }
}
```

**Use sparingly.** Singletons are hidden global state — they hurt testability and concurrency. Prefer dependency injection of a single instance from a composition root. The two legitimate uses today: process-wide config caches, and module-level singletons exposed by ES modules (which are already singletons by construction).

**Don't use for.** "Convenience" — pass instances explicitly.

---

## Common mistakes

- **Builder for 3 fields.** A typed parameters object is simpler.
- **Abstract Factory for one product.** Use Factory Method.
- **Singleton everywhere.** Each one is a hidden dependency that breaks tests.
- **Factory Method that just calls `new` once.** Inline it.

## Related

- `solid-principles` — DIP and OCP underpin Factory and Abstract Factory.
- `structural-patterns` — what to do once an object is built.
- `code-quality-heuristics` — YAGNI guards against over-applying these patterns.
