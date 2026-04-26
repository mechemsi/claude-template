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
