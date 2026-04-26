---
name: error-handling
description: Use when writing try/catch blocks; when adding async functions that can fail; when designing how a function reports failure to its caller; when retrying transient operations; when an error message would surface to a user; or when Claude is tempted to write `catch (e) {}` or wrap everything in a generic try/catch.
---

# Error Handling

Treat errors as a first-class part of the API. Functions either succeed with a value or fail in a documented, recoverable way.

## When to apply

- Designing a new function that can fail (network, IO, parsing, business rule)
- Reviewing code with `catch` blocks
- A bug report says "it just silently failed"
- Adding retries or fallbacks
- Translating a low-level error into a user-facing message

## Core distinctions

### Expected vs unexpected errors

| | Expected | Unexpected |
|---|---|---|
| Examples | `UserNotFound`, `InsufficientFunds`, `ValidationError` | `ReferenceError`, `OutOfMemory`, division by zero |
| Where modeled | Domain — return them as values or typed errors | Runtime — let them propagate, log, alert |
| Caller must handle? | Yes, type system enforces | No — they indicate bugs |
| User sees? | Friendly message | Generic "something went wrong", report the bug |

The mistake most teams make: treating both the same. Wrapping a domain rule violation in `try/catch` next to a TypeError destroys the type system's leverage.

### Result type vs exceptions

Two valid styles. Pick one per layer and stay consistent.

**Result type (recommended for domain layer):**

```ts
type Result<T, E> = { ok: true; value: T } | { ok: false; error: E };

type ChargeError =
  | { kind: 'insufficient_funds' }
  | { kind: 'card_declined'; reason: string }
  | { kind: 'network'; retryable: true };

async function chargeCard(card: Card, cents: number): Promise<Result<Charge, ChargeError>> {
  // ...
}

const result = await chargeCard(card, 1000);
if (!result.ok) {
  switch (result.error.kind) {
    case 'insufficient_funds': return showInsufficientFundsUi();
    case 'card_declined':      return showDeclinedUi(result.error.reason);
    case 'network':            return retryLater();
  }
}
useCharge(result.value);
```

The compiler forces the caller to handle every case.

**Exceptions (acceptable for outermost boundaries):**

```ts
class InsufficientFundsError extends Error { readonly kind = 'insufficient_funds' as const; }
class CardDeclinedError extends Error { constructor(public reason: string) { super(reason); } readonly kind = 'card_declined' as const; }

async function chargeCard(card: Card, cents: number): Promise<Charge> {
  // throws typed errors, never a generic Error
}
```

Never throw raw `Error` or `string`. Always a typed subclass with a discriminator.

## The forbidden patterns

```ts
// ❌ Silent swallow
try { await charge() } catch {}
try { await charge() } catch (e) { /* TODO */ }

// ❌ Log-and-continue without context
try { await charge() } catch (e) { console.error(e); }

// ❌ Wrapping everything in try/catch out of paranoia
try { return user.name; } catch { return ''; }

// ❌ Throwing strings or untyped objects
throw 'something bad';
throw { code: 500 };

// ❌ Catching to "convert" without preserving the cause
try { ... } catch { throw new Error('failed'); }  // lost the original
```

## The required patterns

### 1. Catch only what you can handle

```ts
// ✅ Catch the specific case, let everything else bubble
try {
  return await fetchUser(id);
} catch (err) {
  if (err instanceof NotFoundError) return null;
  throw err;  // re-throw anything else
}
```

If a `catch` block can't say *what* it's handling and *why*, it shouldn't exist.

### 2. Preserve the cause

```ts
// ✅ Wrap with context, keep the chain
try {
  await db.users.create(user);
} catch (err) {
  throw new UserCreationError('failed to create user', { cause: err });
}
```

`{ cause }` is supported by modern Node and browsers — use it. Stack traces stay intact.

### 3. Boundary translation

At the outermost boundary (HTTP handler, message-bus consumer), translate domain/typed errors into the boundary's error format:

```ts
// HTTP handler
try {
  const result = await chargeCard(card, cents);
  return res.json(result);
} catch (err) {
  if (err instanceof InsufficientFundsError) return res.status(422).json({ code: 'INSUFFICIENT_FUNDS' });
  if (err instanceof ValidationError)        return res.status(400).json({ code: 'VALIDATION_ERROR', details: err.issues });
  // Unknown — log and return generic 500
  log.error('unhandled error in charge', { err });
  return res.status(500).json({ code: 'INTERNAL_ERROR' });
}
```

Nothing crosses the wire as a stack trace. Every internal-error response uses a stable `code` so clients can branch.

### 4. Retry with backoff for transient errors

```ts
async function retry<T>(fn: () => Promise<T>, opts = { tries: 3, baseMs: 100 }): Promise<T> {
  let lastErr: unknown;
  for (let i = 0; i < opts.tries; i++) {
    try { return await fn(); }
    catch (err) {
      lastErr = err;
      if (!isRetryable(err)) throw err;
      const delay = opts.baseMs * 2 ** i + Math.random() * 50;
      await new Promise(r => setTimeout(r, delay));
    }
  }
  throw lastErr;
}
```

Only retry **idempotent** operations or those guarded by an idempotency key. Never retry POST-create-row without one.

### 5. Circuit breaker for cascading failures

When a downstream service is failing, don't keep hammering it. After N failures in a window, open the circuit (fail fast), and probe periodically. Libraries: `opossum`, `cockatiel`. Roll your own only as a last resort.

## User-facing messages

- Map error → friendly message at the UI layer, not in domain code.
- Never display stack traces or technical messages to end users.
- Log the technical detail, show the user a short, actionable message.
- Include a correlation/request ID so support can trace the incident.

## Common mistakes

- Treating every error as "exceptional" — domain rules are not exceptions, model them in the type system.
- One giant try/catch wrapping a 100-line function — narrow the scope.
- Re-throwing a generic Error and losing the original — use `{ cause }`.
- Logging an error then continuing as if it didn't happen — either handle it or stop.
- Retrying non-idempotent operations.

## Related

- `solid-principles` — DIP makes error injection (and testing) easier.
- `api-design` — error envelope conventions, HTTP status semantics.
- `logging-observability` — structured logs with correlation IDs.
