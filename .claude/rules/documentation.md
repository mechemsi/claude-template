# Documentation Rules

All project documentation lives in `claudedocs/`. Claude maintains these docs as part of the development workflow.

## When to Create Docs

| Folder | When | Who creates it |
|--------|------|----------------|
| `prds/` | Before a plan, when starting a new user-facing feature | Developer or Claude during requirements discovery |
| `plans/` | After PRD approval, before implementation | Developer or Claude during technical planning |
| `implementations/` | After a feature is shipped and working | Claude after completing implementation |
| `decisions/` | When choosing between multiple technical approaches | Developer or Claude when a decision is made |
| `runbooks/` | When a manual process is repeated more than once | Anyone who discovers the process |

PRDs answer **what** and **why**; plans answer **how**. Skip the PRD for refactors, dependency upgrades, and bug fixes — the technical plan is enough.

## File Naming

- **PRDs**: `YYYY-MM-DD-short-name.md` (e.g., `2026-04-26-notifications.md`)
- **Plans**: `YYYY-MM-DD-short-name.md` (e.g., `2026-03-28-auth-system.md`)
- **Implementations**: `YYYY-MM-DD-short-name.md` (e.g., `2026-03-28-project-setup.md`)
- **Decisions**: `NNN-short-name.md` with sequential numbering (e.g., `001-app-router.md`)
- **Runbooks**: `short-name.md` (e.g., `database-migration.md`)

When a PRD spawns a plan, give the plan the same date and short-name so the pair is easy to find.

## Required Frontmatter

Every doc must start with YAML frontmatter:

```yaml
---
title: Human-readable title
status: draft | approved | superseded | planned | in-progress | implemented | abandoned | accepted
date: YYYY-MM-DD
related: [optional list of related doc paths]
---
```

Status values by doc type:
- **PRDs**: `draft | approved | superseded`
- **Plans**: `planned | in-progress | implemented | abandoned`
- **Decisions**: `accepted | superseded | abandoned`
- **Implementations**: `implemented` (or omit)

Runbooks only need `title`.

## INDEX.md

`claudedocs/INDEX.md` is the master index. It must be updated whenever a doc is added, removed, or changes status.

Claude should read INDEX.md first when looking for project context, before scanning individual files.

## PRD Docs

A PRD must include:
- **Problem**: What is broken/missing/painful today (no solutions yet)
- **Users**: Who has this problem, in what context, how often
- **Success Criteria**: Measurable outcomes that define "this worked"
- **Scope**: In scope and out of scope (the out-of-scope list prevents creep)
- **Risks & Open Questions**: Known unknowns and decisions needed before planning

Use the boilerplate at `claudedocs/prds/_template.md`. See the `writing-prd` skill for guidance.

## Plan Docs

A plan doc must include:
- **Goal**: One sentence on what this achieves
- **Scope**: In scope and out of scope
- **Technical Approach**: How it will be built
- **Success Criteria**: Checkboxes that define "done"

If a PRD exists, link it from the plan's `related` frontmatter.

## Implementation Docs

An implementation doc must include:
- **What Was Built**: Summary of the feature
- **Key Files**: Table of important files and their purpose
- **How It Works**: Brief architecture or data flow description
- **Notes**: Gotchas, limitations, or future work

## Decision Docs (ADRs)

Follow the Architecture Decision Record format:
- **Context**: Why this decision was needed
- **Options Considered**: At least 2 options with pros/cons
- **Decision**: What was chosen
- **Rationale**: Why this option won
- **Consequences**: What changes as a result

## Runbook Docs

A runbook must include:
- **When to Use**: What triggers this process
- **Steps**: Numbered, copy-pasteable commands
- **Common Issues**: Table of problems and fixes

## Rules

- Keep docs concise — prefer tables and bullet points over paragraphs
- Link between related docs using relative paths (`../plans/auth-system.md`)
- Update `status` in frontmatter when a plan moves to implementation or is abandoned
- Never delete docs — change status to `abandoned` with a note explaining why
- Do not duplicate information that belongs in code comments or README
