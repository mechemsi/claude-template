<!--
Drop into `.github/PULL_REQUEST_TEMPLATE.md`.

Implements SKILL.md §6 governance gates:
  - PR template with AI-disclosure (% AI-generated, prompt link, runbook)
  - Spec-driven PRs (link the plan/PRD/ADR alongside code)
  - Runbook link required in release notes / PR template
-->

## Summary

<!-- 1–3 bullets on what changed and why. -->

## Linked spec

<!-- Required for non-trivial PRs. Skip for refactors / dep bumps / typo fixes. -->
- Spec / PRD / plan / ADR:
- Issue:

## AI provenance

<!-- Required by SKILL.md §6 — makes provenance auditable. -->
- % AI-generated (rough): __%
- Tool / agent (e.g. Claude Code, Cursor, Copilot, Codex):
- Session or prompt link (if shareable):

## Test plan

- [ ] Unit tests pass locally
- [ ] Integration tests pass locally
- [ ] Manually verified the golden path
- [ ] Manually verified at least one edge case
- [ ] Reviewed the diff for hallucinated APIs / fabricated identifiers

## Runbook & rollback

<!-- Required for PRs that change runtime behaviour. -->
- Runbook link:
- Rollback plan:
- Feature flag (if any):

## Pre-merge checklist

- [ ] PR title is Conventional Commits format (`feat:`, `fix:`, `chore:` …)
- [ ] PR is under the size limit (~400 LOC)
- [ ] No `.skip` / `it.only` / `xit(` / `fit(` left behind
- [ ] No `TODO` / `FIXME` / "left as exercise" in non-doc files
- [ ] Lockfile updated and committed if dependencies changed
- [ ] Migrations are expand-migrate-contract safe (or none added)
- [ ] CHANGELOG / release notes updated if user-facing
- [ ] Branch-protection required checks all green
