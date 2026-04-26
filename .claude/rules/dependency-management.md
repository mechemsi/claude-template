# Dependency Management

Every dependency is a long-term liability. Bugs, security issues, breaking changes, supply-chain attacks, and bundle size all become your problem.

## When to Add a Dependency

A new dep is justified only when **all** are true:

1. The functionality is genuinely complex (date math, cryptography, parsing).
2. Rolling your own would take significantly longer than learning the library and managing its lifecycle.
3. The library is well-maintained: recent commits, multiple maintainers, semver discipline, >100k weekly downloads or backed by a known org.
4. The license is compatible with the project (no AGPL in proprietary code, no GPL in MIT-licensed libs you redistribute).

If the answer to **any** of these is no — write it yourself.

## Anti-Patterns

| Anti-pattern | Example | Why bad |
|--------------|---------|---------|
| Tiny utility deps | `is-odd`, `left-pad`, `is-number` | Trivial code, supply-chain risk, slows install |
| One-feature mega-frameworks | Pulling in `lodash` for one `groupBy` | Use `lodash-es` named imports or write 5 lines |
| Abandoned packages | Last commit 3+ years ago | Unfixed CVEs, no Node-version updates |
| Pre-1.0 packages in production | `^0.x.y` | Breaking changes are allowed at any minor bump |

## Lockfile Discipline

- The lockfile (`package-lock.json` / `pnpm-lock.yaml` / `yarn.lock`) **must** be committed.
- Never delete and regenerate without intent — that's a silent dep upgrade for every package.
- Lockfile conflicts in PRs: regenerate from `main`'s lockfile + the PR's `package.json`, don't merge by hand.
- CI must use `--frozen-lockfile` (or `npm ci`), never `npm install`.

## Version Pinning

Default to caret (`^`) for libraries you trust to follow semver. Pin exactly (`x.y.z`) for:
- Anything pre-1.0
- Build tooling that breaks subtly between minor versions (some bundlers, transpilers)
- Anything where a known recent regression exists

Never use `*` or `latest`.

## Security

- Run `npm audit` (or `pnpm audit`) on every PR. Fix high/critical before merge.
- Subscribe to GitHub Dependabot or equivalent for automated CVE alerts.
- Treat new transitive deps with suspicion when they appear in lockfile diffs — investigate.

## Dependency Hygiene Checks Before Merge

- [ ] Does the lockfile diff make sense? (Transitive churn explained?)
- [ ] Any new top-level dep — is the license OK?
- [ ] `npm audit` clean for high/critical?
- [ ] Bundle size impact understood (for frontend)?

## When Removing a Dependency

- Run a project-wide search for direct imports.
- Check transitive use — another dep might still need it.
- After removal, regenerate the lockfile and rerun the test suite.
- Don't leave the entry in `package.json` "in case we need it later" — that's YAGNI.

## Dev vs Runtime Dependencies

`dependencies` ship to production. `devDependencies` don't.

- Type packages (`@types/*`), test runners, linters, build tools → `devDependencies`.
- Anything imported from a file that ships to prod → `dependencies`.
- Misclassification breaks production install, or worse, ships unused tooling.

## Pnpm / Yarn / npm

Pick one and document it in `CLAUDE.md`. Mixing package managers in the same repo creates inconsistent lockfiles and CI confusion. The package manager is part of the project's contract.
