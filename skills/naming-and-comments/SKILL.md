---
name: naming-and-comments
description: Use when naming a new variable, function, class, type, or file; when deciding whether a comment is needed; when reviewing a PR where names obscure intent or comments paraphrase the code; when a TODO/FIXME has no owner or date; when a boolean is named without `is`/`has`/`can`/`should`/`did`; when abbreviations like `usr`, `cfg`, `req`, `tmp`, `mgr` appear in identifiers that outlive a function body; when files are named `utils.ts`, `helpers.py`, `misc.go`, or `common.*`; when classes/types use `Manager`, `Helper`, `Util`, `Data`, or `Info` suffixes; when commented-out code is about to be committed; when writing a docstring on an internal helper.
---

# Naming and Comments

Good names eliminate the need for most comments. Comments that remain should explain **why**, never **what**.

## When to apply

- Introducing any new identifier — variable, function, class, type, file, module
- Reviewing a diff where the reader has to read the body to understand a name
- Touching a comment: it must justify itself or be deleted in the same commit
- Adding a `TODO` / `FIXME` / `HACK` / `XXX`
- Writing a docstring or JSDoc — decide first whether the API is public
- Splitting a `utils` / `helpers` / `misc` file because it has accreted unrelated responsibilities
- Renaming during a refactor (use IDE-aware rename, see `refactoring-discipline`)
- Reviewing a class/type whose name ends in `Manager`, `Helper`, `Util`, `Data`, `Info`

## Boolean naming patterns

Booleans must answer a yes/no question. Pick a prefix; never a bare adjective or noun.

| Pattern | Use for | Examples |
|---------|---------|----------|
| `is*` | State or category | `isActive`, `isAdmin`, `isEmpty` |
| `has*` | Possession / containment | `hasPermission`, `hasUnsavedChanges`, `hasChildren` |
| `can*` | Capability / permission | `canEdit`, `canPublish`, `canRetry` |
| `should*` | Recommendation / policy | `shouldRetry`, `shouldClose`, `shouldFallback` |
| `did*` | Past event / outcome | `didSucceed`, `didMount`, `didTimeout` |

Same rule, language-idiomatic casing: TS `isActive`, Python `is_active`, Go `IsActive`, Ruby `active?` (trailing `?` is the yes/no marker). Never bare `active`, `permission`, `disabled` — use `isDisabled` or invert to `isEnabled`.

## Comment decision matrix

| Situation | Comment? | Why |
|-----------|----------|-----|
| Non-obvious *why* (business rule, regulatory constraint, perf hack, vendor quirk) | ✅ Yes | The reader cannot derive intent from the code alone |
| Deliberate non-action ("intentionally synchronous", "do not retry") | ✅ Yes | Prevents future "fixes" that break a working system |
| External link (issue, RFC, ticket, vendor bug) | ✅ Yes | Anchors the change to the context that justified it |
| `TODO` / `FIXME` with owner *and* date | ✅ Yes | Trackable, owned, has a half-life |
| Paraphrase of the code (`// loop through users`, `// increment count`) | ❌ No | Adds noise, drifts when code changes |
| Restating the type signature (`@param x the x parameter`) | ❌ No | Type already says it |
| Docstring on an internal helper | ❌ No | The name and signature suffice; the helper is not a public API |
| Decorative banner (`////// SECTION //////`) | ❌ No | If the file needs banners, the file is too big — split it |
| Commented-out code "in case we need it" | ❌ No | Use git history; dead code in comments grows |
| `TODO` without owner or date | ❌ No | Will be there in five years; either commit to it or delete it |

## Naming

### Identifiers must reveal intent

If you have to read the body to understand the name, the name is wrong.

```ts
// ❌                                 ✅
const d = new Date();                 const createdAt = new Date();
const list = users.filter(u => u.a);  const activeUsers = users.filter(u => u.isActive);
function process(x) { ... }           function applyDiscount(order) { ... }
```

```python
# ❌                                  ✅
def proc(x):                          def apply_discount(order):
    ...                                   ...
items = [u for u in users if u.a]     active_users = [u for u in users if u.is_active]
```

The name is a contract with the reader: it must let them skip the body.

### Avoid abbreviations

Allowed (universally understood, no decoding): `id`, `url`, `uri`, `http`, `html`, `css`, `db`, `api`, `uuid`, `iso`, `utf`, `i18n`, `a11y`. Loop counters `i`, `j` in 3-line loops only. `e` for caught exceptions in 2-line catches.

```ts
// ❌                          ✅
const usr = getUsr(id);        const user = getUser(id);
const cfg = loadCfg();         const config = loadConfig();
class UserMgr { ... }          class UserService { ... }
```

`usr`, `cfg`, `req`, `res`, `acc`, `tmp`, `mgr`, `svc`, `mod`, `obj`, `ctx` are not allowed in names that live longer than a function body. Inside a 5-line function, `ctx` is fine; on a class field, it isn't.

### Function naming: verbs first

Functions do things; the first word is the verb. `getUser`, `findUser`, `createUser`, `updateUser`, `deleteUser`, `formatDate`, `parseAmount`, `validateEmail`. Predicates: `isValidEmail`, `hasAccess`.

Pick a `find` vs `get` convention for the project — typically `get` throws when missing, `find` returns `T | null` — and apply it consistently. Mixing them is a footgun: callers don't know whether to expect `null` or an exception.

### Class / type naming: nouns

Concepts are nouns. `User`, `Order`, `PaymentGateway`, `InvoiceRenderer`. Suffixes like `Manager`, `Helper`, `Util`, `Object`, `Data`, `Info`, `Wrapper` are usually a sign the type lacks a clear responsibility — see `solid-principles` (SRP).

```ts
// ❌                       ✅
UserData                    User
UserInfo                    UserProfile (if it's a slice) or just User
UserManager                 UserService (or split — what does it actually do?)
StringUtil                  Specific verb-name: capitalize(), slugify()
OrderHelper                 Specific responsibility: OrderPriceCalculator
RequestWrapper              AuthenticatedRequest (if that's what it is)
```

If you can't think of a non-`Helper` name, the class probably shouldn't exist — its methods belong on the type whose data they use (see `code-smells` → Feature Envy).

### Avoid noise words

`Data`, `Info`, `Manager`, `Helper`, `Util`, `Object`, `Wrapper`, `Stuff`, `Things` add no information. They survive renames because nobody can think of anything better, not because they're correct. Push back: what does the type *do*?

### Domain names beat type names

`userId: string` is fine. `user: string` (when you mean the ID) is a bug magnet. The name should reflect the *concept*, not the storage type. Branded IDs and value objects make the concept explicit and let the compiler help — see `domain-modeling`.

### Negation: avoid double negatives

`isEnabled = !isDisabled` is clearer than `isNotDisabled`. `!isNotDisabled` melts brains. Pick the positive form; invert at the call site when needed.

### Plurals

Collections plural, singles singular, maps named by value indexed by key: `user` (single), `users` (collection), `usersById: Map<UserId, User>`, `usersByEmail: Map<string, User>`.

### File naming

Per-language convention varies (TS components `PascalCase.tsx`, TS utilities `kebab-case.ts`, Python `snake_case.py`, Go `snake_case.go`). The cross-language rule is *consistency within a project* — don't mix `userdata.py` + `user-data.ts` + `UserData.tsx` in one repo. Defer the specific choice to project rules; this skill enforces "pick one and apply it everywhere".

### No file is `utils.ts`, `helpers.py`, `misc.go`, or `common.*`

Anti-names. They tell the reader nothing, attract unrelated functions, grow until nobody dares touch them.

```
❌ src/utils.ts            ✅ src/format-date.ts
❌ src/helpers.py          ✅ src/slugify.py
❌ pkg/common/common.go    ✅ pkg/timeutil/parse.go
```

If a file genuinely groups small related helpers, name it after the *domain* they share (`date-utils.ts`) — not `utils`. If they're unrelated, split the file.

## Comments

### Default: write none

If a comment paraphrases the code, delete it. The name does the work.

```ts
// ❌ Useless — names already say it
// Loop through users
for (const user of users) { ... }
// Increment count by 1
count++;
// Returns the user's full name
function getFullName(user: User): string { ... }
```

A paraphrasing comment doubles maintenance cost (now two things must agree) without adding signal.

### Write a comment when (and only when)

1. **The *why* is non-obvious** — business rule, regulatory constraint, performance hack, vendor quirk.

   ```ts
   // Stripe charges in cents — never multiply by 100 here, it's already in cents.
   await stripe.charge(amountCents);
   ```

2. **A deliberate non-action matters.** Prevents well-meaning "fixes" that break a working system.

   ```ts
   // Intentionally synchronous: the audit log must complete before we return.
   db.audit.insertSync(event);
   ```

3. **External context** — issue, RFC, ticket, regulator, vendor bug.

   ```ts
   // Workaround for https://github.com/nodejs/undici/issues/1234 — remove when fixed.
   ```

4. **TODOs / FIXMEs with owner *and* date.** Format: `TODO(owner, YYYY-MM-DD): what and why`.

   ```ts
   // ❌ Will be there in five years.
   // TODO: clean this up

   // ✅ Owned, dated, has a half-life.
   // TODO(alex, 2026-04-26): replace with new pricing engine after Q3 launch.
   // FIXME(team-payments, 2026-05-01): race condition under high concurrency.
   ```

   Without both fields, it's noise; reject in review.

### Maintain or delete

A wrong comment is worse than no comment — it actively misleads. When you change code, update or delete the comment in the same commit. Reviewers must reject PRs where the diff and the comments disagree (see `code-review-discipline`).

### Don't commit commented-out code

Use git history. Dead code in comments hides intent and grows.

```ts
// ❌                              ✅
// const oldRate = 0.18;           const rate = 0.21;
// const oldRate = 0.20;
const rate = 0.21;
```

If the old value matters, write a one-line comment explaining *why it changed* and let git remember the rest.

### Documentation comments (JSDoc / docstrings)

Required only for **public APIs** (exported from a module's barrel / public package) and only when the function name + types aren't enough.

```ts
/**
 * Charges the given payment method. Idempotent on `idempotencyKey`.
 *
 * @throws {InsufficientFundsError} when the card is declined for funds.
 * @throws {NetworkError} on transient failures — caller should retry.
 */
export async function chargeCard(pm: PaymentMethod, amountCents: number, idempotencyKey: string): Promise<Charge> { ... }
```

Don't write docstrings for internal helpers — the name and signature carry the load. Don't write `@param x the x parameter` — that's noise, and IDEs already show the type.

### Decorative banners are noise

`////// HELPERS //////` and similar section dividers signal that the file is doing too many things. Split it. See the project rule on file structure for thresholds.

## Common mistakes

- **Bare booleans (`active`, `permission`, `disabled`)** — fail the yes/no test; reader can't tell the truthy direction at the call site.
- **`Manager` / `Helper` / `Util` types** — almost always a Single Responsibility violation in disguise; the methods belong on the type whose data they use.
- **Abbreviations in long-lived names (`usr`, `cfg`, `req`, `mgr`)** — save 3 characters, cost every reader 2 seconds forever.
- **`utils.ts` / `helpers.py` / `misc.go` / `common.*` files** — accrete unrelated functions, become bug-prone, never get split.
- **Comments that paraphrase the code (`// loop through users`)** — doubled maintenance cost, zero added information.
- **Commented-out code committed "just in case"** — git already remembers; the comment hides current intent.
- **`TODO` without owner or date** — guarantees the TODO will outlive the project.
- **Docstrings on internal helpers** — boilerplate that drifts from the implementation; the type signature already says it.
- **Comments that contradict the code after a refactor** — actively mislead; the wrong comment is worse than no comment.
- **`Data` / `Info` suffixes (`UserData`, `OrderInfo`)** — hide what the type actually represents; usually the right name is just `User` or `OrderSummary`.
- **Mixing file-naming conventions in one project** (`userdata.py` + `user-data.ts` + `UserData.tsx`) — readers can't predict where a file lives.
- **Find-and-replace renames instead of IDE-aware rename** — silently corrupts comments, strings, and unrelated identifiers; see `refactoring-discipline`.

## Related

- `code-smells` — Primitive Obsession, Long Method, Feature Envy, etc. Smells are *what* to refactor; this skill is what to *name* during and after.
- `solid-principles` — `Manager` / `Helper` suffixes are SRP violations in disguise; the right name follows the right responsibility.
- `domain-modeling` — branded IDs, value objects, domain primitives so identifier names match domain concepts (`UserId`, `Money`, `EmailAddress`).
- `code-quality-heuristics` — naming is half of YAGNI/KISS in practice; a name that needs a comment to be understood is a sign of a missing abstraction.
- `refactoring-discipline` — IDE-aware renames keep comments and call sites in sync; hand-edit renames don't.
- `code-review-discipline` — naming and comment quality is a first-class review concern; reject PRs where the diff and the comments disagree.
- `.claude/rules/naming-and-comments.md` — the project-level rule this skill generalizes; per-project overrides (specific casing conventions, allowed domain abbreviations) live there.
