---
name: ci-cd-pipeline
description: Use when designing or reviewing CI/CD pipelines or GitHub Actions workflows; when auditing CI for security or quality gaps; when picking tools (gitleaks, semgrep, trivy, osv-scanner, etc.); when deciding what should fail-the-build vs warn; when shipping AI-generated code that needs harder gates than human code; when a PR slipped through with secrets, hallucinated APIs, broken migrations, or uncovered branches.
---

# CI/CD Pipelines for AI-Coded Apps

LLM-generated code ships with predictable failure modes: plausible-but-wrong logic, silently-disabled tests, hallucinated APIs, secrets pasted inline, dependencies pulled from typosquats, and "works on my laptop" defaults. **The pipeline is the only honest reviewer — if it doesn't block, it ships.**

## When to apply

- New repo getting its first CI workflow
- Existing pipeline that "works" but has obvious gaps (no SAST, no SBOM, no coverage gate)
- A bug or incident traced back to "should have been caught in CI"
- Migrating to a reusable / shared workflow across repos
- Standardising AI-coded projects on a baseline before scaling team

## Six categories of gates

Every pipeline needs coverage of these. Items marked 🔴 are non-negotiable — they fail the build.

---

### 1. Security gates 🔴

| Gate | Tool | What it catches |
|------|------|-----------------|
| Secret scanning on every push | `gitleaks` or `trufflehog` + GitHub push protection | API keys, tokens, private keys |
| SAST | `semgrep` (multi-lang), `bandit` (Py), `eslint-plugin-security`, `gosec` (Go) | Injection, unsafe APIs, hardcoded crypto |
| SCA on every PR (not just weekly) | `pip-audit`, `npm audit --audit-level=high`, `osv-scanner` | New Critical/High CVEs in deps |
| Container image scan | `trivy image` or `grype` (also scan base image) | Vulns in OS packages and app layers |
| IaC scan | `checkov`, `tfsec` | Misconfigured Dockerfiles, compose, k8s, terraform |
| Dependency Review action on PRs | GitHub `dependency-review-action` | Diff of newly-added deps + their licences/CVEs |
| SBOM on release | `syft` → SPDX/CycloneDX | Supply-chain audits |
| Build provenance | `actions/attest-build-provenance` | SLSA level 2+ |
| Pinned action SHAs (not `@v4`) | `step-security/harden-runner` | Action supply-chain attacks, blocked egress |

### 2. Correctness & maintainability 🔴

| Gate | Tool | Why |
|------|------|-----|
| Format + lint blocking | `prettier`, `ruff`, `gofmt` | AI cheerfully ignores style; the pipeline must not |
| Strict typing | `mypy --strict`, `tsc --noEmit --strict`, `go vet` | Most hallucinated APIs die here |
| Unit + integration tests both required | native runners | AI-generated unit tests often mirror buggy code; integration hits real contracts |
| Coverage floor + diff-cover | `coverage.py`, `c8`, `diff-cover` | E.g. 80% line floor + diff coverage ≥ floor. Kills "tests for new code are optional" drift |
| Mutation testing on critical modules | `mutmut`, `stryker` | Catches tests that assert nothing |
| Migration safety | Alembic / Prisma / Atlas up + down dry-run against throwaway Postgres | AI loves irreversible migrations |
| Contract / schema diff | `oasdiff` (OpenAPI), `buf breaking` (Proto), GraphQL schema diff | Block breaking changes without explicit label |
| Dead-code / unused-dep | `knip`, `ts-prune`, `vulture`, `depcheck` | Known AI slop signal |
| PR guards | size limit (≤ ~400 LOC), `CODEOWNERS`, Conventional Commits title lint, branch protection w/ required checks | Forces small reviewable PRs |
| Test-skip detector | grep diff for `@skip`, `.skip`, `xit(`, `it.only(` → fail | AI's favourite shortcut |
| Artefact hygiene | grep diff for `TODO` / `FIXME` / "Implementation left as exercise" in non-doc files → fail | AI placeholder leakage |

### 3. Scalability & performance

| Gate | Tool / pattern |
|------|----------------|
| Build + dependency cache | `actions/cache`, `setup-node/python` cache, Docker BuildKit + registry cache (40–80% wall-clock cut) |
| Matrix builds | for supported runtimes (node/python versions, OS) |
| Reusable workflows | `workflow_call` to kill copy-paste drift across repos |
| Path filters + job fan-out | `dorny/paths-filter` so a web-only PR never waits on backend tests |
| Self-hosted runners for heavy jobs | pair with `harden-runner` and ephemeral VMs / `actions-runner-controller` |
| Preview environments on PR | Dokploy, Fly, Railway, Cloudflare Preview — reviewers test real behaviour |
| Performance budgets | Lighthouse CI (frontend), `k6`/`locust` smoke (backend), `size-limit` (bundle) |
| Flaky-test quarantine | retry + detect, open issue, **don't** silently re-run forever |

### 4. Release & runtime safety

- **Environment protection rules** with manual approval on `production`.
- **Zero-downtime migration policy**: expand-migrate-contract enforced via lint rule (no `DROP` / `ALTER TYPE` / non-nullable-without-default in one release).
- **Progressive delivery**: canary or blue/green; automated rollback on SLO breach.
- **Feature flags** for AI-heavy paths — kill-switch beats redeploy.
- **Post-deploy smoke tests** + **synthetic monitors** as a required status in the deploy workflow.
- **Runbook link required** in release notes; PR template enforces it.

### 5. AI-specific gates

- **Prompt / model registry versioned in git** — treat prompts, system messages, model IDs like code: reviewed, diffed, tagged.
- **Eval harness in CI** — small deterministic eval suite runs on every PR that touches an AI path (agent, prompt, model, tool). Block regressions, same as tests.
- **Cost + latency budgets** per endpoint, reported in PR comment. LLM spend is now a CI concern.
- **PII / prompt-injection lint** on user-input paths; red-team fixtures in the eval set.
- **Reproducibility**: pin model versions (no `gpt-4o-latest` in prod); log model + prompt hash with every response.
- **Data contracts for tool-calling**: JSON Schema validation on every LLM function-call argument before it hits business logic.

### 6. Consistency & agent governance 🔴 (for AI-coded work)

LLM agents drift in conventions (layers, names, utils, logging) faster than they drift in security. These controls act on the **input** side — before CI even runs — so the agent writes code that matches the repo instead of inventing a new shape per feature.

| Gate | Purpose |
|------|---------|
| `AGENTS.md` / `CLAUDE.md` per repo | Allowed libs, forbidden patterns, import boundaries, naming, error handling, logging shape. Auto-loaded by Claude / Cursor / Codex. |
| Gold-standard file | One canonical module exemplifying *every* rule. Agents told "new code looks like this." Individual rules = unit tests, gold standard = E2E test. |
| Do/don't examples inside rules | Concrete counter-examples kill ambiguity. Red-team each rule by trying to misinterpret it. |
| ADRs under `docs/adr/` (MADR format) | Numbered architectural decisions referenced from prompts so agents don't reinvent patterns per feature. |
| AI review bot as required check | CodeRabbit / Greptile / Qodo. Catches "duplicate of existing util", "violates module convention". Greptile ~82% catch rate vs Cursor 58% / CodeRabbit 44%. |
| Duplicate-code + complexity budgets | `jscpd` (all langs), `lizard` / `radon` (cyclomatic), `eslint-complexity`. Ratchet downward. |
| Cyclic / illegal-import detection | `madge` / `dependency-cruiser` (JS), `import-linter` (Py), Nx module-boundary rules. |
| Monorepo affected graph | Nx or Turborepo. Centralizes config, enforces module boundaries, cuts CI 40–70% by running only affected projects. |
| `pre-commit` framework (or `lefthook` / `husky`) | Format, lint, secret-scan, test-skip grep, TODO grep on staged files — same ruleset as CI. Kills ~80% of CI failures before push. |
| Pinned runtimes | `.tool-versions` (mise/asdf) + `.nvmrc` + `.python-version`. Eliminates "works on Claude's laptop". |
| EditorConfig + single formatter config | One place for Prettier/Black/gofmt settings. Prevents trivial style churn agents regenerate. |
| Conventional Commits + `commitlint` + semantic-release | Automatic SemVer, CHANGELOG, GitHub Releases. |
| PR template with AI-disclosure | `% AI-generated`, linked session/prompt, runbook link. Makes provenance auditable. |
| Renovate (grouped, auto-merge patch/minor on green) | Replaces weekly audit issue board with always-fresh PRs. |
| Commit signing required on protected branches | Branch protection rule. |
| Structured-logging contract + trace-id lint | Custom ESLint / ruff rule requiring `logger.info(event=..., **fields)` shape + mandatory `trace_id` / `request_id`. |
| Agent sandboxing in CI | When an agent generates code *inside* CI, run under `step-security/harden-runner` + ephemeral VM + egress allowlist. |
| Spec-driven PRs | Non-trivial PRs commit the plan (e.g. PRD or implementation plan) alongside code; PR template enforces the link. |

---

## Audit wiring: PR-blocking vs scheduled-issue-tracking

Audits run with **two distinct wirings**. A repo usually needs both. Pick the right one per audit type — the difference is which event triggers the workflow and what "failure" means.

### A. PR-blocking gates (fail the build)

- **Triggers:** `pull_request`, `push` to protected branches.
- **Job behaviour:** scan only the PR diff (or the new state). If a new Critical/High finding lands, **fail the build** so the PR can't merge.
- **Examples:** gitleaks on staged content, semgrep on changed files, `npm audit` against the new lockfile, container scan on the PR-built image, schema-diff on the new OpenAPI doc.
- **Why:** stops *new* findings from landing. Targeted, actionable, owned by the PR author.

### B. Scheduled audits (manage GitHub issues, **never fail the build**)

- **Triggers:** `schedule:` (e.g. weekly cron) + `workflow_dispatch`.
- **Job behaviour:**
  - Scan the whole codebase / lockfile / image set.
  - If findings exist → **open or update** a single labelled GitHub issue per audit category. Idempotent: same title + label → update; new run → bump the body with the latest report.
  - If findings are gone → **close** the previously-opened issue.
  - The job itself **always exits 0**. The issue is the signal.
- **Why:** scheduled-job failures create noise without an actionable PR. Issues are actionable and form a live dashboard. The `/issues` view with the `audit` label becomes the team's standing audit board.

### Where to apply pattern B (not pattern A)

Use scheduled-issue-tracking for findings that:

- Already exist in the codebase (you don't want to gate the next unrelated PR on them).
- Need triage/decision rather than immediate fix (e.g. "outdated dep — upgrade across 3 services this sprint").
- Cover concerns that are about the repo as a whole, not the diff.

Specific audits to wire as scheduled issue-trackers:

- Dependency vulnerabilities (`pip-audit`, `npm audit`, `osv-scanner`) — across the full lockfile, not just diff.
- Outdated dependencies (`npm outdated`, `pip list --outdated`).
- License drift / compliance.
- Container base-image vulns (rebuild + scan weekly even if no app changes).
- Dead-code / unused-dep accumulation reports.
- SBOM diff against the previous release.
- Cyclomatic-complexity / duplicate-code budgets when ratcheting (report drift, don't break builds mid-sprint).

### Issue lifecycle (idempotent)

```
issue title:   "Audit: <category> — <project>"
issue labels:  ["audit", "automated", "<category>"]

on each scheduled run:
  if findings:
    if existing open issue with this title+label: update body (replace)
    else: create new issue
  else:
    if existing open issue with this title+label: close with comment "✅ no findings on <date>"
```

Use a helper such as `peter-evans/create-issue-from-file` or a small `gh issue` wrapper. The board ends up with one row per audit category per project: open issues = current debt, closed issues = recently-resolved debt with provenance.

### One-line summary

| Trigger | Finding | No finding |
|---------|---------|------------|
| PR / push (gate) | **Fail the build** | Continue |
| Scheduled (dashboard) | Open/update issue, exit 0 | Close issue, exit 0 |

## Auditing an existing pipeline

Use this as a checklist when reviewing a project's CI. For each row, mark the project's status: ✅ in place, **add** to introduce, **review** if uncertain, **—** if not applicable.

| # | Gap | Status |
|---|-----|--------|
| 1 | Secret scanning (gitleaks / trufflehog + GitHub push protection) | |
| 2 | SAST per language (semgrep + bandit / eslint-security / gosec) | |
| 3 | SCA on every PR (`pip-audit`, `npm audit`, `osv-scanner`) — not just weekly cron | |
| 4 | Container image scan on built images (trivy / grype) — also scan base | |
| 5 | IaC scan (checkov / tfsec) on Dockerfile, compose, k8s, terraform | |
| 6 | Dependency Review action on PRs (license + CVE diff) | |
| 7 | SBOM generated on release (syft → SPDX/CycloneDX) | |
| 8 | Build provenance (`actions/attest-build-provenance`, SLSA ≥ 2) | |
| 9 | Pinned action SHAs (no `@v4`) + `step-security/harden-runner` | |
| 10 | Format + lint as **blocking** check | |
| 11 | Strict typing (`mypy --strict`, `tsc --noEmit --strict`, `go vet`) | |
| 12 | Unit + integration tests both required | |
| 13 | Coverage gate + diff-cover (per-PR diff coverage ≥ floor) | |
| 14 | Mutation testing on critical modules (`mutmut` / `stryker`) | |
| 15 | Migration safety (up + down dry-run against throwaway DB) | |
| 16 | Contract / schema diff (`oasdiff`, `buf breaking`, GraphQL schema diff) | |
| 17 | Dead-code & unused-dep scan (`knip`, `ts-prune`, `vulture`, `depcheck`) | |
| 18 | PR size guard + `CODEOWNERS` + Conventional Commits title lint | |
| 19 | Test-skip detector (grep diff for `@skip`, `.skip`, `xit(`, `it.only(`) | |
| 20 | Artefact-hygiene grep (TODO/FIXME/"left as exercise" in non-doc files) | |
| 21 | Build + dependency cache (40–80% wall-clock savings) | |
| 22 | Matrix builds for supported runtime versions / OS | |
| 23 | Reusable `workflow_call` shared across repos | |
| 24 | Path filters + per-surface job fan-out | |
| 25 | Self-hosted runners for heavy jobs (with harden-runner) | |
| 26 | Preview environments on PR | |
| 27 | Performance budgets (Lighthouse CI / k6 / size-limit) | |
| 28 | Flaky-test quarantine (retry + open issue, not silent re-run) | |
| 29 | Environment protection rules + manual approval on production | |
| 30 | Expand-migrate-contract enforced via lint | |
| 31 | Progressive delivery (canary / blue-green) + automated rollback | |
| 32 | Feature flags for AI-heavy paths | |
| 33 | Post-deploy smoke tests + synthetic monitors as required status | |
| 34 | Runbook link required in release notes / PR template | |
| 35 | Prompt / model registry versioned in git | |
| 36 | AI eval harness in CI (deterministic, blocks regressions) | |
| 37 | Cost + latency budgets per AI endpoint, reported in PR | |
| 38 | PII / prompt-injection lint + red-team fixtures in eval set | |
| 39 | Pinned model versions (no `*-latest` in prod); model + prompt hash logged per response | |
| 40 | JSON Schema validation on every LLM tool-call argument | |
| 41 | `AGENTS.md` / `CLAUDE.md` per repo (allowed libs, naming, layers, logging) | |
| 42 | Gold-standard file (one canonical module exemplifying every rule) | |
| 43 | ADR directory `docs/adr/` (MADR format) | |
| 44 | AI review bot as required check (Greptile / CodeRabbit / Qodo) | |
| 45 | Duplicate-code + cyclomatic complexity budgets (jscpd, lizard, radon) | |
| 46 | Cyclic / illegal-import detection (madge, dependency-cruiser, import-linter) | |
| 47 | Monorepo affected graph (Nx / Turborepo) — only build/test what changed | |
| 48 | `pre-commit` framework (or lefthook / husky) — same ruleset as CI | |
| 49 | Pinned runtimes (`.tool-versions` / `.nvmrc` / `.python-version`) | |
| 50 | EditorConfig + single-source formatter config | |
| 51 | Conventional Commits + commitlint + semantic-release | |
| 52 | Renovate (grouped, auto-merge patch/minor on green) | |
| 53 | PR template with AI-disclosure (% AI-generated, prompt link, runbook) | |
| 54 | Commit signing required on protected branches | |
| 55 | Structured-logging lint rule (event + fields + trace_id) | |
| 56 | Agent sandboxing in CI when agents run inside CI (harden-runner + ephemeral) | |
| 57 | Spec-driven PRs (plan/PRD committed alongside code, enforced by template) | |

Output the table marking each row's status, then prioritise the gaps using the adoption order below — don't try to fix all of them in one PR.

## Minimum viable baseline — adoption order

Don't try to add all 60+ gates at once. This order maximises return per hour spent.

1. **Gitleaks + push protection** — one hour, stops the worst leaks.
2. **Semgrep + language-specific SAST** — one PR, pre-written rulesets.
3. **Per-PR SCA** (`pip-audit`, `npm audit`, `osv-scanner`) — upgrade weekly audit to per-PR.
4. **Coverage gate + diff-cover** + grep-in-diff for test-skip and TODO.
5. **Trivy on Docker build + SBOM upload.**
6. **Reusable `workflow_call` pipeline** shared across repos.
7. **Preview environments + Lighthouse / k6 budgets.**
8. **AI eval harness + prompt/model registry** (only if the repo has AI paths).
9. **Drop `AGENTS.md` / `CLAUDE.md` + ADR seed + gold-standard file + PR template** into every new project (or inherit from a template repo).
10. **`pre-commit` + pinned runtimes** — one PR per repo. Immediate CI-failure drop (~80%).
11. **AI review bot** as required check — pick one (Greptile for context, CodeRabbit for UX).
12. **Nx / Turborepo** in monorepos — affected graph + module-boundary lint.
13. **Conventional Commits + semantic-release + Renovate** — via reusable `workflow_call`.
14. **Duplicate-code + complexity budgets** — tune to current code, ratchet down.
15. **Structured-logging lint + AI-disclosure PR template.**
16. **Agent sandboxing** (`harden-runner` + ephemeral runner) for repos where agents run inside CI.

Everything above is boring, well-trodden, and low-cost. Skipping any of it on AI-coded apps is the same bet as shipping without tests — just slower to notice.

## Common mistakes

- **Treating SAST/SCA as warnings.** Anything not gated is decoration. Security findings must fail the build (with a documented exception path).
- **Coverage % without diff-cover.** New code can land at 0% while overall % stays comfortable.
- **Re-running flaky tests forever.** Hides real bugs and trains the team to ignore red.
- **`@v4` action references** — supply-chain risk. Pin SHAs.
- **One mega `ci.yml`.** Path-filter and split per surface so a docs-only PR doesn't run the backend test suite.
- **Adopting all 60 gates day one** — pipeline becomes a 30-minute slog, team starts disabling checks. Use the adoption order.
- **No `AGENTS.md` / `CLAUDE.md`** — agents drift the repo's conventions every PR; your reviewers spend their time on style, not logic.
- **Self-hosted runners without `harden-runner`** — runner becomes a foothold the moment a malicious dep lands.

## Related

- `security-review` — companion skill for code-level security audit (this skill is pipeline-level).
- `dependency-management` rule — what gets installed; this skill is what gets *checked*.
- `error-handling`, `logging-observability` — paired with §6 lint rules (structured logs, trace IDs).
- `12-factor-app` — release/runtime context for §4.
- `testing-architecture` — coverage gate and mutation testing depth come from here.
