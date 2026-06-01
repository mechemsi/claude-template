# Pull Request Rules

## Copilot review loop

If the repo has the GitHub Copilot reviewer enabled, after opening a PR
**wait for the Copilot review, then triage and address it before
merging**. Its feedback is useful signal and regularly catches real bugs.

**Timing:** the review typically lands **a few minutes** (~2–5 min) after
`gh pr create` — not the ~30s GitHub advertises. **Poll** for it (every
~30s) rather than assuming a fixed delay; a single short sleep will miss
it.

### Steps

1. **Open the PR** with `gh pr create` as usual.
2. **Poll for the review** (~2–5 min, every ~30s), then fetch:
   ```bash
   gh pr view <N> --json reviews --jq '.reviews[] | select(.author.login | test("copilot|Copilot"; "i"))'
   gh api repos/<owner>/<repo>/pulls/<N>/comments --jq '.[] | select(.user.login | test("copilot|Copilot"; "i")) | {path, line, body}'
   ```
3. **Handle an errored review.** Copilot sometimes posts a review whose
   body is `Copilot encountered an error and was unable to review this
   pull request.` with **no** comments. That is **not** a real review —
   re-request it and poll again:
   ```bash
   gh pr edit <N> --add-reviewer Copilot          # re-requests the bot
   # then poll reviews again, ignoring any body matching "encountered an error"
   ```
   A fresh, non-error review usually arrives a few minutes after the
   re-request. Don't treat the error placeholder as "reviewed".
4. **Triage each comment.** Apply judgment — Copilot is helpful but not
   always right.
   - Fix when: legitimate bug, security issue, accessibility gap, real
     maintainability concern, factual inaccuracy in docs.
   - Skip when: stylistic nit that disagrees with project convention,
     suggestion that contradicts an explicit design decision, request for
     tests of behavior outside scope.
   - When skipping, still **resolve the thread** so the PR isn't visually
     noisy, and note in the resolution comment why.
5. **Push fixes** to the PR branch (no force-push if branch protection
   forbids it — add new commits or merge from main).
6. **Resolve threads** via GraphQL once the underlying comment is
   addressed:
   ```bash
   # Get unresolved thread IDs
   gh api graphql -f query='{ repository(owner:"<owner>", name:"<repo>") {
     pullRequest(number:<N>) { reviewThreads(first:50) {
       nodes { id isResolved comments(first:1) { nodes { author { login } } } }
     }}}}' --jq '.data.repository.pullRequest.reviewThreads.nodes[]
                | select(.isResolved == false)
                | "\(.id) by \(.comments.nodes[0].author.login)"'

   # Resolve each
   gh api graphql -f query='mutation($id: ID!) {
     resolveReviewThread(input:{threadId:$id}) { thread { isResolved } }
   }' -F id=<THREAD_ID>
   ```
7. **Recheck mergeability** after pushing fixes — branches stacked on this
   one may need rebase or retarget. A pushed fix retriggers CI **and** can
   prompt a fresh Copilot pass, so re-poll both before merging.
8. **Then merge** (per the user's earlier authorization, or ask if it's a
   fresh task).

## What counts as "relevant"

| Comment type | Default action |
|---|---|
| Security issue (creds, injection, SSRF, etc.) | **Fix** |
| Accessibility gap (missing aria-label, keyboard trap, etc.) | **Fix** |
| Bug (off-by-one, wrong regex, dead code path) | **Fix** |
| Inaccurate docs (wrong file path, broken link, stale claim) | **Fix** |
| Test coverage gap on a real branch | **Fix or note as follow-up** |
| Missing error case the project actually handles | **Fix** |
| Stylistic preference (naming, comment phrasing) | Skip if it disagrees with `.claude/rules/code-style.md` |
| "Consider extracting" without concrete need | Skip — YAGNI |
| Suggested test against external network/services | Skip and note (CI can't be flaky on this) |

## Stacked PRs

When PR B is stacked on PR A:

1. Merge A first.
2. **Retarget B to `main`**: `gh api repos/<o>/<r>/pulls/<B> -X PATCH -f base=main`
3. **Rebase B on `main`** locally to drop A's now-duplicated commits — or, if branch protection blocks force-push, **merge `main` into B** to bring it forward.
4. Recheck Copilot review on B (it may add new comments after the rebase/merge).

## When NOT to wait for Copilot

Skip the wait + triage loop only when:
- The PR is a tiny doc-only typo fix the user explicitly wants merged immediately.
- The PR is a hot-fix and the user has flagged it as urgent.
- The repo has Copilot disabled (no `copilot-pull-request-reviewer` review appears after ~8 min, even after one re-request — see step 3).

In all other cases, the wait is worth it — it catches real bugs (credential leaks, loose host matching, stale UI state, empty-arg shell calls).

## Permissions notes

- `resolveReviewThread` requires write access to the PR's repo.
- The `gh api` calls use the user's `gh auth login` token automatically.
- Pushing fixes follows the existing branch-protection rules — assume force-push is forbidden on `feat/*` and `fix/*` branches and use forward-only commits.
