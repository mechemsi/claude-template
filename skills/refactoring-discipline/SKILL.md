---
name: refactoring-discipline
description: Use when the user asks to refactor or restructure code without changing behavior; when a planned rewrite or "big-bang" refactor is on the table; when renaming a widely-used symbol or moving a module across the codebase; when introducing an interface to replace direct concrete dependencies; when untested legacy code needs structural changes; when tests are red between intermediate refactor commits; when considering a long-lived refactor branch; when incrementally replacing a legacy subsystem; when a refactor PR is also adding behavior; when extracting a service from a controller or splitting a class along SRP lines.
---

# Refactoring Discipline

Refactoring is the *how*. The companion skill `code-smells` is the *what* (which smell maps to which technique). This one is about sequencing, the safety net, PR hygiene, and the large-scale strategies that keep mainline shippable while structure changes underneath.

## When to apply

- The user says "refactor", "clean up", "restructure", "extract", "split", "move", or "rename" without asking for behavior change
- A class/module is about to grow a feature and the existing shape resists it ("make the change easy, then make the easy change")
- A symbol is used in 20+ places and someone proposes a single-commit rename
- A legacy subsystem is being replaced and "we'll cut over in one PR" is the current plan
- Tests fail between intermediate commits on a refactor branch
- The proposed PR mixes refactoring with a behavior change ("while I was in there…")
- Code has no tests but a structural change is about to happen anyway
- A refactor branch has been alive longer than a week

## Core rule: behavior must not change, and tests must stay green between every step

Refactoring = changing structure without changing observable behavior. If observable behavior changes — a new branch, a different output, a renamed wire format — it is a feature change, not a refactor, and **must not** be mixed into the same commit or PR.

Each commit on a refactor branch must compile and pass tests. That cadence is the safety net; without it you have a rewrite-in-disguise that you cannot bisect, cannot revert in pieces, and cannot review.

## Quick reference: situation → strategy

| Situation | Strategy |
|-----------|----------|
| Code has tests, change fits in one sitting | Tiny steps: extract → rename → inline → move, commit between steps |
| Code has no tests | **Pin behavior first** with characterization tests, *then* refactor |
| Renaming/moving a widely-used symbol across the codebase | **Parallel change** (expand → migrate → contract) |
| Replacing a concrete dependency without freezing mainline | **Branch by abstraction** |
| Replacing a legacy subsystem (or service) over weeks/months | **Strangler fig** |
| Goal change you can't see a path to | **Mikado method**: attempt → revert → record prerequisite → repeat |
| Refactor "while adding a feature" | Split into two PRs: refactor first, feature second |
| Live system, can't afford a long-lived branch | Branch by abstraction + small PRs to mainline |
| Code nobody is about to touch and it has no tests | **Leave it alone** — the boy-scout rule applies *during* changes, not as a justification |

## Tiny steps

Refactoring is a sequence of mechanical, reversible moves. Each one is small enough to be obviously correct.

```
extract function → rename parameter → introduce parameter object → push the object up the call chain → inline the now-trivial caller
```

Each arrow is a commit. Each commit compiles and the tests pass. If a step turns out wrong, you revert that commit, not the whole branch.

> If you can't articulate the next step in one sentence, stop and write it down. The Mikado method exists for exactly this moment.

## No tests? Pin behavior first

Michael Feathers's framing: legacy code is code without tests. You cannot safely refactor what you cannot verify.

Before any structural change, write a **characterization test** (also called approval / golden-master test) that captures *current* behavior — bugs, quirks, and all. The test asserts what the code does, not what you wish it did.

```ts
// ❌ Refactoring untested code is a coin flip
// (no tests exist, just dive in and "clean it up")

// ✅ Capture current output as the assertion, then refactor against it
test('legacy invoice rendering — characterization', () => {
  const input = loadFixture('invoice-2024-03.json');
  const output = renderInvoice(input);
  // First run: write the snapshot. Subsequent runs: must match.
  expect(output).toMatchSnapshot();
});
```

The characterization test is not throwaway. It stays in the suite — it is the only thing standing between the refactor and a regression. If a "weird" behavior turns out to be load-bearing for some downstream consumer, the snapshot will catch the change.

## Refactor commits stay separate from feature commits

> Make the change easy, then make the easy change. — Kent Beck

Two disciplined PRs:

1. **Refactor PR.** No behavior diff. Reviewable in one pass. Merges quickly because there's nothing to argue about.
2. **Feature PR.** Behavior change, now sitting on top of a structure that fits.

```
❌ One PR: "Add coupon support (also refactored OrderService along the way)"
   - 600-line diff
   - Mixes mechanical moves with new logic
   - Reviewer can't tell which lines are the actual feature
   - If the feature has a bug, can't revert it without losing the refactor

✅ PR #1: "Extract PricingPolicy from OrderService" — pure refactor, mechanical, merged in a day.
   PR #2: "Add coupon discount via PricingPolicy" — small, focused, easy to review.
```

If a reviewer has to read carefully to follow a refactor PR, the PR is too big or it's mixing concerns.

## Parallel change for code structure (expand → migrate → contract)

Same shape as `db-migration-safety`'s expand-contract, applied to code. Use it for renaming a public function, changing a signature, or replacing a type that is used widely.

| Phase | What happens |
|-------|--------------|
| **Expand** | Add the new shape alongside the old. Both work. |
| **Migrate** | Move call sites one at a time (or in batches). Mainline stays green throughout. |
| **Contract** | Once no caller references the old shape, delete it. |

### Worked example: renaming a public function

```ts
// ── Phase 1: Expand ──────────────────────────────────────────────
// Old name still works. New name added.
export function getUserById(id: string): Promise<User> {
  return findUserById(id);
}
export function findUserById(id: string): Promise<User> {
  // real implementation
}

// ── Phase 2: Migrate ─────────────────────────────────────────────
// Call sites switch to findUserById, one PR per area of the codebase.
// Each PR is small, mechanical, and independently mergeable.

// ── Phase 3: Contract ────────────────────────────────────────────
// Once `git grep getUserById` returns zero results, delete the alias.
// (Optionally: add a deprecation warning during phase 2.)
```

The mainline is shippable at every commit. Compare to the naive approach:

```ts
// ❌ Big-bang rename in one PR
// - 87 files changed
// - merge conflicts with everyone else's branches
// - if reverted, must revert all 87 files
// - bisect is useless: every commit on the branch is broken
```

## Branch by abstraction

Long-lived structural change without a long-lived feature branch.

The pattern, in five steps:

1. **Identify** the thing being changed (a class, module, or subsystem).
2. **Introduce an abstraction** in front of it — an interface that describes what callers actually need.
3. **Switch call sites** to depend on the abstraction (still backed by the old implementation). Mainline still ships.
4. **Build the new implementation** behind the abstraction. Toggle with a feature flag or config.
5. **Retire** the old implementation once the new one is proven. Optionally collapse the abstraction.

### Worked example

```ts
// Starting point: code reaches into a concrete SmtpEmailer.
class OrderService {
  async place(o: Order) {
    await new SmtpEmailer().send(o.email, '...');  // hard-coded
  }
}

// ── Step 1: introduce abstraction (mainline stays green) ──
interface Emailer { send(to: string, body: string): Promise<void>; }
class SmtpEmailer implements Emailer { /* unchanged */ }

class OrderService {
  constructor(private emailer: Emailer = new SmtpEmailer()) {}
  async place(o: Order) { await this.emailer.send(o.email, '...'); }
}

// ── Step 2: build the new implementation behind the same interface ──
class SesEmailer implements Emailer { /* new */ }

// ── Step 3: switch via config / feature flag ──
const emailer: Emailer = process.env.EMAILER === 'ses' ? new SesEmailer() : new SmtpEmailer();

// ── Step 4: once SES is proven in prod, delete SmtpEmailer ──
// Keep the Emailer interface (it's useful for tests) or inline if only one impl remains.
```

At no point did mainline stop being shippable. There was no two-week rebase war.

## Strangler fig

Branch-by-abstraction is for *within* a codebase. Strangler fig is for *replacing a system* — typically across process or service boundaries. Named for the strangler fig vine that grows around a host tree until the host is consumed.

1. Stand up the new system next to the old.
2. Route a slice of new functionality through the new system.
3. Progressively shift existing functionality off the old system, one capability at a time.
4. When the old system serves no traffic, delete it.

The old and new run in parallel for as long as it takes. Each capability migrated is a small, reversible change. The point at which "we cut over" never arrives — the old system is empty by the time you delete it.

Distinct from branch-by-abstraction in scope: strangler fig replaces a *system*; branch-by-abstraction replaces an *implementation*.

## Mikado method (when you can't see the path)

For refactors where the goal is clear but the route is not:

1. Attempt the goal change directly.
2. Observe what breaks (compile errors, failing tests, missing dependencies).
3. **Revert.** Do not try to fix forward.
4. Record the breakage as a prerequisite in a graph.
5. Pick a leaf prerequisite, do *that* refactor, commit.
6. Repeat from step 1. The graph shrinks; eventually the goal is a leaf.

```
Goal: remove the global `currentUser`
├── X depends on currentUser via init()
│   └── init() depends on Y constructed at boot
│       └── Y reads currentUser in constructor
└── Z depends on currentUser via a static helper
    └── static helper called from 12 sites
```

Process: tackle leaves first (the static helper sites), then the helper itself, then Y's constructor, then init, then the goal. Each step is a tiny, green commit on mainline.

The discipline is the *revert*. Without it, you accumulate half-finished work, lose track of which prerequisites you've discovered, and end up on a long-lived broken branch.

## Refactor vs rewrite

Default to refactor. Rewrites lose the embedded knowledge of every bug fix the original accumulated — the weird `if` on line 412 was probably a regulator's edge case from 2019, not stupidity.

Rewrite is the fallback when:

- The abstraction itself is wrong (not just the code is ugly).
- The technology has been deprecated and refactoring forward isn't possible.
- Cost-of-change for the next year of features genuinely exceeds rewrite cost — and someone has done the math.

If the only argument for rewrite is "the code is hard to read", the answer is refactor.

## When NOT to refactor

- No tests + no time + no behavior change request + no upcoming feature in this area = leave it alone. Churn for its own sake is yak-shaving.
- The boy-scout rule ("leave the code cleaner than you found it") applies *during* a change you were already making, not as a standalone reason to open a refactor PR.
- Speculative refactoring "to make it easier to add X later" when X is not on any roadmap — YAGNI.

## IDE-aware refactorings beat hand-edits

Prefer "rename symbol", "extract method", "move file" from a language server / IDE over find-and-replace.

Hand-edits silently:

- Rename strings inside comments and unrelated identifiers (`UserID`, `oldUserId`, `GetUserId` may all match a sloppy regex).
- Miss usages in string-based DI (route registries, reflection, decorators).
- Break test names that referenced the old symbol by string.
- Skip files outside your editor's open buffer.

The IDE refactoring uses the AST. The find-and-replace uses regex. They are not equivalent.

## PR hygiene for refactors

A good refactor PR:

- Compiles and passes tests at every commit (not just at the tip).
- Has zero behavior diff. CI smoke tests confirm this.
- Reads as a sequence of small, named steps in commit titles ("Extract X", "Move Y", "Rename Z").
- Is reviewable in 10–15 minutes. Larger means split it.
- Touches one logical structural change. Renaming + extracting + moving in one PR is three PRs squashed.

Reviewer red flags: a commit titled "wip", a commit that fixes a previous commit on the same branch (squash it), or a diff where the same line appears in both `-` and `+` with whitespace-only changes mixed in.

## Common mistakes

- **Mixing refactor and feature in one commit.** Reviewers can't separate mechanical moves from new behavior; bisect can't blame the right line.
- **Refactoring without tests.** No safety net = every change is a leap of faith. Pin behavior first.
- **Long-lived refactor branch.** Drifts from main, accumulates merge conflicts, becomes a rebase nightmare. Use branch-by-abstraction or parallel change to keep work on mainline.
- **Big-bang rewrite to "fix everything at once".** Loses embedded knowledge, blocks all other work, ships late or never.
- **Find-and-replace instead of an IDE-aware rename.** Silently corrupts comments, strings, and unrelated symbols.
- **Refactoring code nobody is about to touch.** The change has no upside, only the risk of breaking something subtle. Yak-shaving.
- **Skipping the characterization-test step on legacy code.** "I'll be careful" is not a safety net.
- **Calling a behavior-changing PR a "refactor".** Misleading title means reviewers skim. Bugs ship.
- **Reverting partway through a Mikado attempt and forgetting which prerequisites you'd already discovered.** Write the graph down — text file, sticky notes, anywhere persistent.
- **Treating the abstraction in branch-by-abstraction as permanent.** Sometimes the right move at step 5 is to inline the abstraction once only one implementation is left.
- **Squashing all the tiny refactor commits before merging.** You lose the bisect granularity that made the tiny steps worth it. Merge-commit the branch with history intact (or at most squash *related* steps).

## Related

- `code-smells` — the *what* of refactoring (which smell, which technique). This skill is the *how*.
- `solid-principles` — most large refactors converge toward SOLID; SRP and DIP are the most common targets.
- `testing-architecture` — the safety net this discipline relies on. Characterization tests and ports/adapters make refactors tractable.
- `code-quality-heuristics` — DRY/KISS/YAGNI judgments that decide *whether* to refactor before pulling the trigger.
- `db-migration-safety` — parallel change in code is the same pattern as expand → migrate → contract in schema. The two reinforce each other when a refactor crosses the storage boundary.
- `layered-architecture` — extracting business logic from controllers into services is the canonical structural refactor; this skill is how to do it without breaking mainline.
- `code-review-discipline` — refactor PRs are reviewable in one pass only because of the discipline this skill enforces.
- `naming-and-comments` — most extract/move/rename steps demand a fresh name; pick it well at the moment of the refactor.
