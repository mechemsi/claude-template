---
name: writing-prd
description: Use when the user wants to "build", "add", "implement", or "design" a new feature; when a request is described in user-facing terms ("we want users to..."); when scope is fuzzy or stakeholders aren't aligned; before a technical plan is written. Skip for pure refactors, bug fixes, and tooling changes.
---

# Writing a PRD (Product Requirements Document)

A PRD answers WHAT we're building and WHY, before a plan answers HOW. It prevents wasted technical work on unclear or mis-scoped requirements.

## When to write a PRD

- New user-facing feature
- Significant change to existing user behavior
- Cross-team feature with multiple stakeholders
- Scope or success metrics are unclear

**Skip a PRD when:** the change is internal-only (refactor, dependency upgrade, fix), or scope is one or two files with obvious user impact.

## Output location

PRDs live in `claudedocs/prds/` using the naming convention `YYYY-MM-DD-short-name.md`. A blank starter exists at `claudedocs/prds/_template.md`.

After the PRD is approved, a corresponding plan is written in `claudedocs/plans/` and linked via the `related` frontmatter field.

## Required sections

Every PRD must contain these sections in this order:

### 1. Problem
What is broken, missing, or painful **today**? One paragraph. Avoid jumping to solutions.

> ❌ "We need to add OAuth login."
> ✅ "New users abandon signup at 38% on the email-confirmation step. Magic-link reliability is the top cited reason in support tickets (n=42 last quarter)."

### 2. Users
Who has this problem? Be specific — "users" alone isn't enough. Name the persona, their context, and how often they hit the problem.

### 3. Success Criteria
How will we know this worked? **Measurable** outcomes preferred over qualitative ones.

> ✅ "Signup-to-active-user conversion improves from 62% to ≥75% within 30 days."
> ❌ "Users find it easier to sign up."

Each criterion should be checkable: a number, a yes/no, or a checklist item.

### 4. Scope
- **In scope** — bullet list of behaviors/screens/flows this PRD covers.
- **Out of scope** — explicit list of things deliberately NOT in this version. The out-of-scope list is often more valuable than the in-scope list because it prevents scope creep.

### 5. Risks & Open Questions
- Known unknowns (auth library compatibility, third-party SLA, etc.)
- Decisions that need stakeholder input before the plan can proceed

## Frontmatter

```yaml
---
title: Human-readable feature name
status: draft | approved | superseded
date: YYYY-MM-DD
related: [list of plan/decision/implementation paths once they exist]
---
```

`status` lifecycle:
- `draft` — written, not yet approved
- `approved` — stakeholders agreed; ready for plan + implementation
- `superseded` — replaced by a newer PRD (link to it via `related`)

## Process

1. **Discover** — ask clarifying questions about problem, users, success metrics. Don't assume.
2. **Draft** — write the PRD using the 5 required sections. Keep it short (1 page if possible).
3. **Review** — surface open questions explicitly. Wait for human approval before changing status to `approved`.
4. **Hand off to plan** — create `claudedocs/plans/YYYY-MM-DD-short-name.md`, link the PRD in its `related` frontmatter, and update `claudedocs/INDEX.md`.

## Common mistakes

- **Solutioning in the Problem section** — describes the fix, not the user pain.
- **Vague success criteria** — "improve UX" cannot be verified at completion.
- **Missing out-of-scope list** — every PRD without one will grow during implementation.
- **Skipping straight to the plan** — a plan answers HOW; without a PRD, you may build the wrong thing efficiently.

## Related

- `claudedocs/prds/_template.md` — boilerplate to copy.
- `.claude/rules/documentation.md` — documentation conventions and INDEX upkeep.
- After approval, hand off to `claudedocs/plans/` (technical design).
