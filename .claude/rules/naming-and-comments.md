# Naming and Comments

Good names eliminate the need for most comments. Comments that remain should explain **why**, never **what**.

## Naming

### Identifiers must reveal intent

```ts
// ❌                                 ✅
const d = new Date();                 const createdAt = new Date();
const list = users.filter(u => u.a);  const activeUsers = users.filter(u => u.isActive);
function process(x) { ... }           function applyDiscount(order) { ... }
```

If you have to read the body to understand the name, the name is wrong.

### Avoid abbreviations

Allowed abbreviations (universally understood):
- `id`, `url`, `uri`, `http`, `html`, `css`, `db`, `api`, `i18n`, `a11y`, `uuid`, `iso`, `utf`
- Loop counters: `i`, `j` in 3-line loops only
- `e` for caught exceptions in 2-line catch blocks

Everything else: spell it out. `usr`, `cfg`, `req`, `res`, `acc`, `tmp`, `mgr`, `svc` are not allowed in names that live longer than a function body.

### Boolean naming

Booleans must answer a yes/no question:

| Pattern | Example |
|---------|---------|
| `is*` | `isActive`, `isAdmin` |
| `has*` | `hasPermission`, `hasUnsavedChanges` |
| `can*` | `canEdit`, `canPublish` |
| `should*` | `shouldRetry`, `shouldClose` |
| `did*` (past) | `didSucceed`, `didMount` |

Never: `active: boolean`, `permission: boolean`, `disabled: boolean` (use `isDisabled` or invert to `isEnabled`).

### Function naming

Verbs first. Functions do things.
- `getUser()`, `findUser()`, `createUser()`, `updateUser()`, `deleteUser()`
- `formatDate()`, `parseAmount()`, `validateEmail()`
- Predicate functions: `isValidEmail()`, `hasAccess()`

### Class / type naming

Nouns. `User`, `Order`, `PaymentGateway`. Not `UserManager`, `UserHelper`, `UserUtils` — these are usually a sign the class lacks a clear responsibility (see SOLID/SRP).

### Avoid noise words

`Data`, `Info`, `Manager`, `Helper`, `Util`, `Object` add no information.

```ts
// ❌                       ✅
UserData                    User
UserInfo                    User (or UserProfile if it's a slice)
UserManager                 UserService (or split — see SOLID)
StringUtil                  Specific verb: capitalize(), slugify()
```

## Comments

### Default: write none

If a comment paraphrases the code, delete it. The name should do the work.

```ts
// ❌ Useless
// Loop through users
for (const user of users) { ... }

// Increment count by 1
count++;

// Returns the user's full name
function getFullName(user) { ... }
```

### Write a comment when (and only when)

1. **The "why" is non-obvious.** Business rule, regulatory constraint, performance hack, weird API requirement.
   ```ts
   // Stripe charges in cents — never multiply by 100 here, it's already in cents.
   await stripe.charge(amount);
   ```

2. **The "what's NOT being done" matters.** Explicitly call out a deliberate non-action.
   ```ts
   // Intentionally synchronous: the audit log must complete before we return.
   db.audit.insertSync(event);
   ```

3. **Linking to external context** — issue, RFC, ticket, regulator.
   ```ts
   // Workaround for https://github.com/nodejs/undici/issues/1234 — remove when fixed.
   ```

4. **TODOs / FIXMEs** — must include owner and date.
   ```ts
   // TODO(domas, 2026-04-26): replace with new pricing engine after Q3 launch.
   // FIXME(team-payments, 2026-05-01): race condition under high concurrency.
   ```

A `TODO` without owner/date is noise — it'll be there in five years.

### Maintain or delete

A wrong comment is worse than no comment. When you change code, update or delete the comment in the same commit. Reviewers should reject PRs where the diff and the comments disagree.

### Don't commit commented-out code

Use git history. Dead code in comments hides intent and grows.

```ts
// ❌
// const oldRate = 0.18;
// const oldRate = 0.20;
const rate = 0.21;

// ✅
const rate = 0.21;
```

## Documentation comments (JSDoc / docstrings)

Required only for **public APIs** (exported from a module's barrel) and only when the function name + types aren't enough.

```ts
/**
 * Charges the given payment method. Idempotent on `idempotencyKey`.
 *
 * @throws {InsufficientFundsError} when the card is declined for funds.
 * @throws {NetworkError} on transient failures — caller should retry.
 */
export async function chargeCard(
  pm: PaymentMethod,
  amountCents: number,
  idempotencyKey: string,
): Promise<Charge> { ... }
```

Don't write docstrings for internal helpers — the type signature and the name are enough. Don't write `@param x the x parameter` — that's noise.
