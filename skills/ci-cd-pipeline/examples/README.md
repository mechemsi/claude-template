# CI/CD Pipeline Examples

Copy-pasteable starting points for the canonical jobs defined in [`../SKILL.md`](../SKILL.md).

## Design rule: language/framework-neutral

Every example here works regardless of stack. Commands that vary by ecosystem (`npm test`, `pytest`, `go test`, `cargo test`, …) are passed as `workflow_call` inputs or environment variables — never hardcoded. The point of canonical job names is that the same `_ci.yml` works for a Node service, a Python API, and a Go CLI, with branch-protection required-status-checks identical across all three.

Tools chosen below are themselves multi-ecosystem on purpose:

| Tool | Why it's neutral |
|------|------------------|
| `gitleaks` | Reads raw bytes, scans any file type |
| `semgrep` (`p/ci`) | Auto-detects language, ships rulesets for ~30 |
| `osv-scanner` | Reads npm, pip, cargo, go.mod, gem, composer, gradle, maven lockfiles |
| `diff-cover` | Reads Cobertura or LCOV — every test runner can emit one |
| `trivy` | Container layers, not language-specific |
| `dependency-review-action` | GitHub-side; works for any ecosystem with a dependency graph |

Where a gate is genuinely language-specific (dead-code via `knip` / `vulture` / `depcheck`, dead-code via `ts-prune`), the example leaves a clearly-labelled placeholder for the consumer to override.

## Files

| File | Gate from SKILL.md | Pattern |
|------|---------------------|---------|
| [`_ci.yml`](./_ci.yml) | All 12 §"Always required" jobs | Reusable `workflow_call` template — the main file. Call from each repo with language-specific commands as inputs |
| [`secret-scan.yml`](./secret-scan.yml) | §1 secret scanning | Standalone gitleaks workflow — drop into a repo that's not ready for the full reusable yet |
| [`scheduled-audit.yml`](./scheduled-audit.yml) | §"Audit wiring B" — scheduled-issue-tracking | Idempotent: opens / updates / closes one labelled GitHub issue per audit category. Plug in any scanner |
| [`pr-template.md`](./pr-template.md) | §6 AI-disclosure + spec-driven PRs | Drop into `.github/PULL_REQUEST_TEMPLATE.md` |

## Pipeline flow per file

Plain-text flows — no rendering required, readable in any viewer.

### `_ci.yml` — full PR-blocking wave

10 jobs run in parallel; only `coverage-gate` and `build` have real `needs:` edges. Every other gate is independent so failures surface immediately and reruns don't drag the rest of the pipeline.

```
on: pull_request, push
  │
  └──► [parallel, independent]
         pr-guards, secret-scan, lint, typecheck,
         test-unit, test-integration, sast, sca,
         dep-review, dead-code

       [after test-unit]        ──► coverage-gate
       [after lint + typecheck] ──► build

       all required checks green ──► merge allowed
```

Branch-protection required-status-checks must list every job above — see SKILL.md "Branch-protection required status checks".

### `secret-scan.yml` — standalone gate

One job, one purpose. Independent runner so it can be a required check even before the rest of `_ci.yml` is adopted.

```
on: push, pull_request
  │
  └──► checkout (fetch-depth: 0)
         │
         └──► gitleaks-action
                ├── secret found ──► fail build
                └── clean        ──► pass
```

Pair with GitHub's repo-side Push Protection (Settings → Code security → Secret scanning). Push protection blocks at `git push` time; this workflow catches anything that slips past it.

### `scheduled-audit.yml` — issue lifecycle (always exits 0)

The job is a no-op as far as CI status is concerned. The labelled GitHub issue is the actionable artefact. `/issues?label=audit` becomes the team's standing audit board: one row per audit category per repo.

```
on: schedule (cron weekly), workflow_dispatch
  │
  └──► run scanner → findings.txt
         │
         ├── findings.txt non-empty
         │     ├── existing labelled issue ──► update issue body
         │     └── no existing issue       ──► open new issue
         │
         ├── findings.txt empty
         │     ├── existing labelled issue ──► close + 'no findings' comment
         │     └── no existing issue       ──► no-op
         │
         └──► exit 0  (always — the labelled issue is the signal)
```

### Why `scheduled-audit.yml` looks different — two wirings

The same scanner (osv-scanner, trivy, semgrep, …) runs in **both** wirings depending on what you're trying to catch. Different trigger, different failure semantics — never mix them.

```
Pattern A — PR-gate (block the build)
  on: pull_request, push
    └──► scan PR diff
           ├── findings    ──► exit non-zero  ──► PR cannot merge
           └── no findings ──► continue

Pattern B — scheduled (issue is the signal, never fails)
  on: schedule, workflow_dispatch
    └──► scan whole repo / lockfile / image
           ├── findings    ──► open/update labelled issue ──► exit 0
           └── no findings ──► close issue if exists      ──► exit 0
```

Use **A** for findings introduced by the diff (block them landing). Use **B** for findings about the repo as a whole that need triage rather than immediate fix (outdated deps, license drift, base-image vulns, dead-code accumulation). Most repos need both — `_ci.yml` wires Pattern A, `scheduled-audit.yml` wires Pattern B.

## How to consume `_ci.yml` from a downstream repo

`.github/workflows/ci.yml`:

```yaml
name: CI
on:
  pull_request:
  push:
    branches: [main]

jobs:
  ci:
    uses: <org>/<template-repo>/.github/workflows/_ci.yml@<sha>
    with:
      lint-cmd: "npm run lint"
      typecheck-cmd: "npm run typecheck"
      test-unit-cmd: "npm test -- --coverage"
      test-integration-cmd: "npm run test:integration"
      build-cmd: "npm run build"
      coverage-floor: 80
      coverage-report: "coverage/cobertura-coverage.xml"
```

Same workflow, different ecosystem — every input swaps, every job name stays:

```yaml
    with:
      lint-cmd: "ruff check ."
      typecheck-cmd: "mypy --strict src/"
      test-unit-cmd: "pytest --cov=src --cov-report=xml tests/unit"
      test-integration-cmd: "pytest tests/integration"
      build-cmd: "python -m build"
      coverage-floor: 80
      coverage-report: "coverage.xml"
```

```yaml
    with:
      lint-cmd: "golangci-lint run ./..."
      typecheck-cmd: "go vet ./..."
      test-unit-cmd: "go test -race -coverprofile=cover.out ./..."
      test-integration-cmd: "go test -tags=integration ./..."
      build-cmd: "go build ./..."
      coverage-floor: 80
      coverage-report: "cover.out"
```

The `branch-protection required-status-checks` list (`pr-guards`, `secret-scan`, `lint`, `typecheck`, `test-unit`, `test-integration`, `coverage-gate`, `sast`, `sca`, `dead-code`, `build`) is identical across all three — that's the whole point of canonical names.

## Action pinning

References use `<sha>` placeholders. Resolve to a current 40-char commit SHA before use; never commit `@v4`-style refs (SKILL.md §1, "Pinned action SHAs"). Use Renovate or Dependabot to keep the SHAs current.

## Out of scope here

Worked examples for genuinely ecosystem-bound gates — `oasdiff` (OpenAPI), `buf breaking` (Proto), Lighthouse CI (frontend), `stryker`/`mutmut` (mutation testing) — live in their tool's own docs. Adding them here would force a stack choice this directory deliberately avoids.
