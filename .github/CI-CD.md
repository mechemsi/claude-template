# CI / CD reference workflows

This directory ships a **reusable CI workflow** that downstream projects can call from their own repos. It implements the canonical jobs documented in [`skills/ci-cd-pipeline/SKILL.md`](../skills/ci-cd-pipeline/SKILL.md) (`## Canonical jobs`).

## Files

| Path | Purpose |
|---|---|
| `workflows/_ci.yml` | The reusable workflow (`on: workflow_call`). Implements `pr-guards`, `secret-scan`, `dep-review`, `lint`, `typecheck`, `sast`, `sca`, `dead-code`, `test-unit`, `test-integration`, `coverage-gate`, `build`. |
| `actions/setup-node/action.yml` | Composite action for package-manager-aware Node setup (npm / pnpm / yarn). |
| `workflows/ci-example-caller.yml.example` | Sample caller — copy as `.github/workflows/ci.yml` in your project. |

## Consuming from your project

```yaml
# .github/workflows/ci.yml in YOUR repo
name: ci
on:
  pull_request:
  push:
    branches: [main]

jobs:
  ci:
    uses: mechemsi/claude-template/.github/workflows/_ci.yml@<sha>
    with:
      node-version: '20'
      package-manager: pnpm
      coverage-floor: 80
    secrets:
      CODECOV_TOKEN: ${{ secrets.CODECOV_TOKEN }}
```

Replace `@<sha>` with a pinned commit SHA of this repo. Per the skill rule "Pinned action SHAs", `@main` is not acceptable for production.

## Required project scripts

The reusable workflow assumes these `package.json` scripts exist:

| Script | Used by | Required? |
|---|---|---|
| `lint` | `lint` job | yes |
| `typecheck` | `typecheck` job | yes |
| `test:unit` | `test-unit` job | yes |
| `test:integration` | `test-integration` job | only if `run-integration-tests: true` |
| `build` | `build` job | only if `run-build: true` |

If any are missing, the corresponding job fails. Toggle off via `with:` inputs (`run-integration-tests: false`, etc.) if your project doesn't have them yet.

## Branch-protection required status checks

Configure these as required in your repo's branch protection rules:

```
ci / pr-guards
ci / secret-scan
ci / lint
ci / typecheck
ci / test-unit
ci / test-integration
ci / coverage-gate
ci / sast
ci / sca
ci / dead-code
ci / build
```

(Job slugs are prefixed with the caller job name — `ci` in the example above.)

## Inputs

| Input | Type | Default | What it controls |
|---|---|---|---|
| `node-version` | string | `'20'` | Node major version |
| `package-manager` | string | `pnpm` | One of `npm` / `pnpm` / `yarn` |
| `coverage-floor` | number | `80` | Line floor + diff-cover threshold (%) |
| `pr-size-limit` | number | `400` | Max changed lines before `pr-guards` fails |
| `run-integration-tests` | boolean | `true` | Toggle the `test-integration` job |
| `run-dead-code` | boolean | `true` | Toggle the `dead-code` job (knip) |
| `run-build` | boolean | `true` | Toggle the `build` job |

## Secrets

| Secret | Required? | Purpose |
|---|---|---|
| `CODECOV_TOKEN` | optional | Upload merged lcov to Codecov; skipped when unset |

## What's *not* in the reusable workflow yet

These canonical jobs from the skill need a follow-up PR — they're documented but not implemented here:

- `migrate-check` — Prisma up/down dry-run against throwaway Postgres.
- `schema-diff` — `oasdiff` / `buf breaking` / GraphQL schema diff.
- `docker-build-scan` — buildx + `trivy image` against the resulting image.
- `iac-scan` — `checkov` + `tfsec`.
- `sbom` / `provenance` — release-only.
- AI-specific (`ai-eval`, `ai-cost-budget`, `prompt-injection-lint`, `tool-call-schema`).
- Scheduled audit workflow (issue-managing, never fails build).

These belong in a separate `_release.yml` and `_audits.yml` to keep PR feedback fast.

## Pinning actions

Every `@vN` reference in `_ci.yml` and `actions/setup-node/action.yml` must be replaced with a full commit SHA before this is used in production. Configure Renovate (`renovate.json` — TODO in this repo) with `extends: ["helpers:pinGitHubActionDigests"]` to pin and keep current.
