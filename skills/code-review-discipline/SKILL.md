---
name: code-review-discipline
description: Use when opening or reviewing a pull request; when a PR exceeds ~400 lines or 20 files; when a single PR mixes refactor and feature changes; when a PR is stuck in review for days; when review comments are dominated by drive-by nits; when an AI-generated PR is being reviewed; when a self-merged PR after pushing changes is being considered; when a "fix bug" PR description has no testing notes or rollback plan; when a code-owner approval workflow is being designed; when deciding which checks must be green before requesting review.
---

# Code Review Discipline

Code review is a two-author act. The author's job is to ship a reviewable change; the reviewer's job is to find what the author can't see. Both jobs have rules, and the discipline only works when both sides hold.

## When to apply

- Opening a PR or about to click "Request review"
- Reviewing a PR — at any size, but especially > ~400 LOC or > 20 files
- A PR description is one line ("fix bug") with no testing or rollback notes
- A PR mixes a refactor with a feature change in one diff
- Review threads dominated by `nit:` comments while correctness/security questions sit open
- The PR was generated or heavily assisted by an AI tool
- A reviewer is about to approve a PR they pushed commits to themselves
- Designing CODEOWNERS or required-review rules for sensitive paths

## PR sizing matrix

Review quality drops sharply with size. Big PRs get rubber-stamped because nobody can hold them in their head.

| Size (LOC, ignoring lockfiles/snapshots) | Reviewer effort | What this implies |
|------------------------------------------|-----------------|-------------------|
| **< 50** | < 5 min | Sweet spot for fixes and small features. Reviewable while waiting for tests. |
| **50–200** | 10–20 min | The default target. One reviewer, one pass, merged the same day. |
| **200–400** | 30–60 min | Acceptable for a single coherent change. Needs careful description and tests. |
| **400–800** | Multiple sittings | Should have been split. Reviewers will skim. Push back unless there's a real reason it can't be split. |
| **> 800** | Rubber stamp | Not actually reviewable. Reject and request a split into a sequence of smaller PRs (parallel-change pattern from `refactoring-discipline`). |

Generated code (lockfiles, snapshots, schema dumps, migrations of mass renames) doesn't count toward this budget — but only if it's clearly tagged in the description and reviewable as a separate hunk.

## Review priority order

When reading a diff, walk the layers in this order. Don't comment on layer N+1 until layer N is clean — style nits never block while correctness is unsettled.

| Priority | Layer | What to ask |
|----------|-------|-------------|
| 1 | **Correctness** | Does this do what the description says? What inputs break it? Are edge cases (empty, null, large, malformed) handled? |
| 2 | **Security** | Auth check present? Input validated? Secrets/PII handled? Defer to `security-review` for the full checklist. |
| 3 | **Tests** | Do the tests assert behavior or just call the function? Would they catch the next regression? Is anything mocked that shouldn't be? |
| 4 | **Docs** | Is the *why* recoverable from the PR description and code? Public APIs documented? ADR needed for a new architectural decision? |
| 5 | **Style** | Naming, formatting, idioms. Linter and formatter should already cover most of this — if the human is reaching for it, the tooling is missing. |

## The two-author principle

Most code change deserves two pairs of eyes. The author and the reviewer have different cognitive jobs: the author is invested in the change and blind to its assumptions; the reviewer is reading cold and notices what's missing. Skipping the reviewer step (self-merging, "trivial change") is how the same bugs ship over and over.

The discipline depends on **both** sides:

- The author who throws a 900-line "ready for review" over the wall is breaking the contract.
- The reviewer who LGTMs without reading the tests is breaking the contract.
- A culture where one side excuses the other ("it's fine, just merge it") rots fast.

## One PR = one purpose

A PR has one reason to exist. "Refactor `OrderService` and add coupon support" is two PRs squashed into one — neither part gets reviewed properly because the diff is confusing.

```
❌ One PR: "Add coupon support (also refactored OrderService along the way)"
   - 600-line diff
   - Reviewer can't tell which lines are the feature and which are mechanical moves
   - If the feature has a bug, can't revert it without losing the refactor

✅ PR #1: "Extract PricingPolicy from OrderService" — pure refactor, mechanical, merged in a day.
   PR #2: "Add coupon discount via PricingPolicy" — small, focused, easy to review.
```

Drive-by changes ("while I was in here I also fixed…") belong in their own PR. They expand the review surface, dilute the bisect signal, and tempt reviewers to skim.

See `refactoring-discipline` for the parallel-change patterns that make this splittable in practice.

### Worked example: splitting a 900-line PR

Initial PR: `feat: add discount codes` — 900 LOC, 18 files. Three logical layers tangled in one diff:
- 400 LOC: rename `Order.amount` → `Order.subtotal`, split `OrderService` into `Pricing`/`Tax`/`Shipping` (pure refactor).
- 200 LOC: add `Discount` entity + Prisma migration.
- 300 LOC: thread discount lookup + apply-on-checkout, add tests.

Split into three PRs, merged in order: refactor → schema → feature. Each is independently revertable; bisect points at one of three logical commits, not "the discount one". The schema PR gets two reviewers (high-risk rule below); the others one each.

## Author hygiene (before clicking "Request review")

A reviewable PR is a gift to the reviewer. The author owes them all of the following:

### Self-review the diff first

Open the PR, click through every file, re-read each hunk as a stranger. Most "embarrassing" review comments are things the author would have caught on a second pass — unused imports, debug prints, commented-out code, a stray `.only` in a test. Catching them yourself costs five minutes; catching them in review costs the reviewer's attention budget.

### PR description: why, not what

The diff shows *what*. The description must explain *why*.

```
❌ Title: fix bug
   Body: Fixes the bug.

✅ Title: fix: prevent duplicate signups when email differs only in case
   Body:
   ## Problem
   Users could register the same email twice (Foo@x.com and foo@x.com) because
   the uniqueness check was case-sensitive but the normalization in send-email
   wasn't. Reported in #4127.

   ## Change
   - Normalize email to lower-case at the API boundary (Zod `.toLowerCase()`).
   - Add a Prisma migration enforcing a case-insensitive unique index.

   ## Testing
   - Added unit tests for the Zod schema (mixed-case, whitespace, IDN).
   - Added integration test that asserts duplicate POST /signup → 409.
   - Verified locally with case variants on a seeded DB.

   ## Rollback
   Revert is safe: the migration is additive (new index alongside the old).
   Drop the new index after revert; no data loss.

   ## Risk
   Low — affects signup path only; existing users are unaffected because the
   index is `CREATE UNIQUE INDEX CONCURRENTLY ... ON ... (LOWER(email))`.
```

For UI changes, attach a screenshot or short video. For schema changes, link the migration and tag the risk level (see `db-migration-safety`).

### CI must be green before requesting review

A red CI is a "do not enter" sign. Reviewers should not have to ask "is the failing test related?" If checks are red, fix them first or mark the PR as draft.

Required checks before "Ready for review":
- Linter, formatter, typecheck.
- Unit + integration tests.
- Security scan (`npm audit`, dependency audit).
- Any project-specific gate (see `ci-cd-pipeline`).

### Conventional commits, squash-friendly history

Subject ≤ 72 chars, imperative mood, conventional prefix (`feat:`, `fix:`, `refactor:`, `test:`, `docs:`, `chore:`). See `.claude/rules/git-commits.md` — including the rule that **commits and PRs must not attribute Claude or any AI tool**.

## Reviewer hygiene

### Read the description and tests first

Before the implementation. The description tells you what the author intends; the tests tell you what they think the contract is. Reading the implementation first means you're reverse-engineering both.

If the tests are weak, no amount of staring at the implementation will save the change.

### Comment levels — be explicit

| Prefix | Meaning |
|--------|---------|
| `nit:` | Optional. Use sparingly. |
| `suggestion:` / `consider:` | Worth thinking about; not a blocker. |
| `question:` | I don't understand — explain or fix the code so I do. |
| `blocking:` / `must-fix:` | I won't approve until this is resolved. |

Without a level, "everything is equally important", which means nothing is. The author can't tell what's actually blocking merge.

### Ask first, suggest second

```
❌ "Move this to the service layer."
✅ "question: what made you put this in the controller? It looks like service-layer logic
    (it touches three repositories) — was there a reason it stayed here?"
```

Asking surfaces context you didn't have. Suggesting before you have context is how reviewers blow up small PRs into days-long debates.

### One reviewer by default

One competent reviewer per PR. Two reviewers means each one assumes the other will catch things; bystander effect kicks in. Add a second reviewer only when explicitly required — see the high-risk rule below.

### Don't re-architect in review comments

If the design is wrong, say so once: "blocking: this entangles billing with auth in a way I think we should reverse before merging — can we discuss before you push more changes?" Don't death-by-1000-cuts the existing design across 40 inline comments.

If a real architectural disagreement surfaces, surface it as an ADR in `claudedocs/decisions/` instead of relitigating it in PR threads. PRs are the wrong forum for big decisions.

### Local checkout for non-trivial PRs

Diffs lie about behavior. For anything beyond an obvious fix, check the branch out, run the tests, exercise the feature manually. The diff doesn't show the runtime behavior; the runtime does.

## Specific concerns: reviewing AI-generated code

AI tools produce code faster than reviewers can vet. The bar goes **up**, not down.

| Red flag | What to ask |
|----------|-------------|
| Tests-pass-but-wrong: assertion that re-implements the function under test | "What requirement does this test prove? Would it fail if the function returned a constant?" |
| Hallucinated imports / API names that look plausible but don't exist | "Is `lodash.deepFreeze` actually a thing?" Verify against the actual package. |
| Pattern copy-paste that doesn't match this codebase's conventions | "Why are we using axios here when the rest of the codebase uses our `httpClient`?" |
| Over-engineered abstractions for "future flexibility" | YAGNI gate — does *this* PR's requirement need it? See `code-quality-heuristics`. |
| Defensive checks for cases the type system precludes | "The type of `id` is `string` — when can this be null?" |
| Comments explaining what (not why), often verbose | Delete; names should do the work. See `naming-and-comments`. |
| Generic error handling that swallows everything | "What error does this actually catch? What does the caller need to know?" |
| Suspiciously polished code in a domain the author doesn't usually work in | Verify the author understands what was generated — the reviewer is also reviewing the author's grasp. |

License/IP risk: in rare cases, models regurgitate training-set snippets verbatim. For anything that looks unusually crafted (a complex algorithm, a long string of magic constants), search for it. Cheap insurance.

## Review SLA

Same business day, or hand off explicitly. Stale reviews kill velocity:

- The author rebases against drift, increasing the diff's surface.
- Context evaporates — the author has moved on, the reviewer has to swap back in.
- Open PRs accumulate, hiding the actually-stuck ones.

If you can't review today, say so and tag someone who can. Silence is worse than declining.

## Approving, then requesting changes — fine

The goal is shipping correctly, not avoiding awkwardness. If you approved and then realized something is wrong, post the comment and dismiss your approval. The author would rather hear it before merge than after.

## Self-merge prohibition

Never approve a PR after pushing changes to it. The push invalidates the prior review — the reviewer signed off on a different diff. Either the original reviewer re-reviews, or a new reviewer takes over.

This rule extends to "I just fixed the typo you flagged and merged" — the typo fix may be fine, but the PR's review state is now wrong.

## Force-push during review

Avoid. If you must (rebase to resolve a conflict, squash a typo commit), leave a comment explaining what changed since the previous review pass. Reviewers should not have to diff two commit ranges to figure out what's new.

GitHub's "compare since your last review" is a partial mitigation, not a license to force-push freely.

## Author follow-through

Every review comment gets a resolution. Three valid outcomes:

1. **Addressed** — change made, link the commit, mark resolved.
2. **Deferred** — agreed but out of scope, ticket linked, resolved.
3. **Disagreed** — explain why, leave thread open for the reviewer to close or push back.

Silently closing a thread without response is bad form. The reviewer wasted time writing the comment; the author owes a one-line reply.

## CODEOWNERS and high-risk paths

For sensitive areas, require a designated owner's approval:

- Auth and session handling.
- Billing, payment, money-touching code.
- Database schema, migrations, ORM models.
- IAM, permissions, role-checking.
- Public API contracts (versioned endpoints, SDK surfaces).
- CI/CD config, deploy scripts, infrastructure-as-code.
- The `CODEOWNERS` file itself (the meta-rule).

Watch for the single-point-of-failure pattern where one person owns 80% of the codebase. CODEOWNERS exists to gate sensitive paths, not to centralize all reviews on one bottleneck.

### Two reviewers for high-risk changes

Schema migrations, security-sensitive code, IAM/permissions, payment paths, public-API contracts, infra/deploy config — require two reviewers. The first catches obvious problems; the second catches what the first missed in their domain. The combinatorics of these areas are unforgiving — one wrong index, one missing auth check, one mis-scoped role grant ships a CVE.

## Reverts

A revert is a forward change with the same review bar as any other PR. Don't self-merge a revert without a reviewer unless production is on fire and oncall has explicitly judged it acceptable. Even then, post-incident, the revert gets a retroactive review.

The temptation to "just revert it, we'll review later" is how reverts introduce their own bugs.

## Common mistakes

- **PRs over 400 LOC accepted without splitting.** Reviewers can't hold them in their head; bugs ship under cover of size.
- **Refactor mixed with feature.** Reviewers can't separate mechanical moves from new behavior; bisect points at the wrong commit.
- **Nits blocking when correctness/security are still open.** Inverts the priority order; signals the reviewer skipped the layers that matter.
- **Ignoring the description and tests, going straight to the implementation.** The author told you what they meant — read it.
- **"LGTM" with no evidence of reading.** Approval-as-formality is approval-as-noise. The next reviewer assumes someone vetted it; nobody did.
- **Self-approving after pushing changes.** The push invalidates the prior review. Get a fresh pair of eyes.
- **Ignoring red CI while waiting for a human reviewer.** A reviewer should never be the first to notice a failing test.
- **No rollback plan for risky PRs.** Schema, infra, and deploy changes need an explicit "how do we get back" paragraph.
- **CODEOWNERS that funnel everything through one person.** That person becomes the bottleneck, then the burnout, then the bus factor.
- **Force-pushing during review without a comment.** Reviewers can't trust their previous read of the branch; they re-read everything or skip.
- **Treating AI-generated PRs with a lower review bar.** Faster generation, same defect rate, weaker author intuition — review *harder*, not less.
- **Relitigating architectural decisions in PR comments.** PRs are the wrong forum for big decisions; surface them as ADRs.

## Related

- `refactoring-discipline` — one PR = one purpose; refactor PRs are reviewable in one pass.
- `security-review` — the security checklist this skill defers to during the priority-2 layer.
- `testing-architecture` — read the tests first; tests-as-spec is the reviewer's friend.
- `db-migration-safety` — schema PRs are high-risk and require two reviewers.
- `ci-cd-pipeline` — required-checks gates that must be green before review starts.
- `code-quality-heuristics` — DRY/KISS/YAGNI gates apply at review time, not just authoring time.
- `code-smells` — the vocabulary reviewers use to name what's wrong without re-architecting in comments.
- `.claude/rules/git-commits.md` — commit and PR hygiene the author inherits, including the no-AI-attribution rule.
