# Claude Project Template

A batteries-included template for structuring Claude Code projects with commands, rules, skills, and subagents.

Use this as a starting point for any team that wants a consistent, well-organized Claude Code setup from day one.

---

## What's Inside

| Category | What it does |
|----------|-------------|
| **Rules** | Modular coding standards Claude follows automatically |
| **Commands** | Slash commands for common workflows (`/review`, `/deploy`, `/fix-issue`) |
| **Skills** | Auto-invoked workflows triggered by task context |
| **Agents** | Isolated subagent personas for focused, specialized work |
| **Settings** | Permission model controlling what Claude can and cannot do |
| **Docs** | Structured project documentation — plans, implementations, decisions, runbooks |

---

## Quick Start

```bash
# Clone the template
git clone git@github.com:mechemsi/claude-template.git my-project
cd my-project

# Remove git history and start fresh
rm -rf .git
git init
git add .
git commit -m "init: scaffold from claude-template"

# Customize for your project
# 1. Edit CLAUDE.md with your team's tech stack and conventions
# 2. Edit .claude/settings.json with your permission preferences
# 3. Create your CLAUDE.local.md for personal overrides (gitignored)
# 4. Start building!
```

---

## Project Structure

> **Legend:**  &nbsp; :blue_circle: Committed to git &nbsp;&nbsp; :white_circle: Gitignored (personal) &nbsp;&nbsp; :green_circle: Auto-invoked &nbsp;&nbsp; :orange_circle: Isolated subagent

```
your-project/
```

### Root Level

| File | | Description |
|------|:-:|-------------|
| `CLAUDE.md` | :blue_circle: | Team instructions — committed to git, shared with all developers |
| `CLAUDE.local.md` | :white_circle: | Personal overrides — gitignored, your local preferences |

### `claudedocs/` — Project Documentation

| File / Folder | | Description |
|---------------|:-:|-------------|
| `INDEX.md` | :blue_circle: | Master index — Claude reads this first to find relevant context |
| `plans/` | :blue_circle: | Feature specs and technical designs written before implementation |
| `implementations/` | :blue_circle: | What was built, how it works, key files and data flow |
| `decisions/` | :blue_circle: | Architecture Decision Records — why X was chosen over Y |
| `runbooks/` | :blue_circle: | Step-by-step guides for recurring operations |

### `.claude/` — Configuration

| File | | Description |
|------|:-:|-------------|
| `settings.json` | :blue_circle: | Permissions + environment config — shared team settings |
| `settings.local.json` | :white_circle: | Personal permissions — gitignored local overrides |

### `.claude/commands/` — Custom Slash Commands

| File | | Description |
|------|:-:|-------------|
| `review.md` | :blue_circle: | `/review` — Performs a structured code review |
| `fix-issue.md` | :blue_circle: | `/fix-issue` — Takes an issue number and applies a fix |
| `deploy.md` | :blue_circle: | `/deploy` — Runs a pre-deployment checklist |

### `.claude/rules/` — Modular Instruction Files

| File | | Description |
|------|:-:|-------------|
| `code-style.md` | :blue_circle: | Enforces TypeScript formatting, naming, and style conventions |
| `testing.md` | :blue_circle: | Defines how tests should be written and organized |
| `api-conventions.md` | :blue_circle: | Sets rules for REST API design and response formats |
| `documentation.md` | :blue_circle: | Defines how `claudedocs/` is structured and maintained |

### `.claude/skills/` — Auto-Invoked Workflows

| File | | Description |
|------|:-:|-------------|
| `deploy/skill.md` | :green_circle: | 6-phase deployment safety checklist — auto-invoked |
| `security-review/skill.md` | :green_circle: | Deep security audit workflow — auto-invoked |

### `.claude/agents/` — Subagent Personas

| File | | Description |
|------|:-:|-------------|
| `code-reviewer.md` | :orange_circle: | Senior engineer persona focused purely on code quality |
| `security-analyst.md` | :orange_circle: | Security engineer persona focused on vulnerability detection |

---

## Legend Explained

| Symbol | Category | Description |
|:------:|----------|-------------|
| :blue_circle: | **Committed to git** | Shared with the whole team. Lives in version control. |
| :white_circle: | **Gitignored (personal)** | Your private overrides. Added to `.gitignore` so they stay local. |
| :green_circle: | **Auto-invoked** | Claude automatically uses these workflows when relevant context is detected. |
| :orange_circle: | **Isolated subagent** | Runs in its own isolated context — a focused persona for a specific task. |

---

## How Each Piece Works

### CLAUDE.md — Team Instructions

The main instruction file committed to git. This is where you define your team's shared context:

- Tech stack and framework versions
- Project structure conventions
- Git workflow (branch naming, commit style, PR rules)
- Quality gates (typecheck, lint, test)

Every developer on the team gets the same baseline instructions.

### CLAUDE.local.md — Personal Overrides

Your personal preferences that don't belong in version control:

- Local dev setup (DB ports, package manager, editor)
- Personal shortcuts ("clean it up" = refactor for readability)
- File/directory exceptions (skip tests for static pages)
- Explanation verbosity preferences

Create this file yourself — it's gitignored so it won't affect teammates.

### Settings — Permission Model

**`settings.json`** (shared) defines what Claude is allowed to do:

```jsonc
{
  "permissions": {
    "allow": [
      "Bash(npm run *)",        // Any npm script
      "Bash(git status)",       // Safe git commands
      "Read(*)",                // Read any file
      "Write(src/**)",          // Write only to src/
      "Write(tests/**)"        // Write only to tests/
    ],
    "deny": [
      "Bash(rm -rf *)",        // No destructive operations
      "Write(.env*)"           // Never touch env files
    ]
  }
}
```

**`settings.local.json`** (personal) extends shared settings with local tools:

```jsonc
{
  "permissions": {
    "allow": [
      "Bash(pnpm *)",          // Local package manager
      "Bash(psql *)"           // Local database CLI
    ]
  },
  "env": {
    "DATABASE_URL": "postgresql://localhost:5433/myapp_dev"
  }
}
```

### Commands — Slash Commands

Invoke with `/command-name` in Claude Code. Each command is a markdown file that defines a structured workflow:

| Command | What it does |
|---------|-------------|
| `/review` | Reads target files, checks against rules, outputs a severity-rated report |
| `/fix-issue` | Takes an issue, traces the bug, applies a minimal fix, writes a regression test |
| `/deploy` | Runs typecheck, lint, tests, build, checks migrations, drafts PR description |

### Rules — Modular Standards

Rules are automatically loaded as context. They define the standards Claude enforces:

- **code-style.md** — TypeScript strictness, naming conventions (camelCase, PascalCase), formatting (2-space indent, single quotes, semicolons), function length limits, import grouping
- **testing.md** — Test frameworks (Vitest + Playwright), coverage targets (90%/80%/70%), naming conventions, mocking guidelines, E2E independence rules
- **api-conventions.md** — REST route structure, consistent response envelope (`{ success, data, meta }`), HTTP status codes, Zod validation, pagination defaults
- **documentation.md** — How to create and maintain docs in `claudedocs/`, naming conventions, required frontmatter, templates for each doc type

### Claudedocs — Project Documentation

Structured documentation that helps Claude (and your team) navigate the project:

| Folder | What goes here | When it's written |
|--------|---------------|-------------------|
| **plans/** | Feature specs, technical designs, scope definitions | Before starting a feature |
| **implementations/** | What was built, key files, architecture, data flow | After shipping a feature |
| **decisions/** | Architecture Decision Records (ADRs) — why X over Y | When making a significant technical choice |
| **runbooks/** | Step-by-step guides with copy-pasteable commands | When a process is repeated more than once |

**How Claude uses it:** Claude reads `claudedocs/INDEX.md` first to find relevant context. Each doc has YAML frontmatter with `title`, `status`, `date`, and `related` fields so Claude can quickly filter without reading full files.

**Naming conventions:**
- Plans and implementations: `YYYY-MM-DD-short-name.md`
- Decisions: `NNN-short-name.md` (sequential numbering)
- Runbooks: `short-name.md`

### Skills — Auto-Invoked Workflows

Skills trigger automatically when Claude detects relevant context — no slash command needed:

| Skill | Triggers when | What it does |
|-------|--------------|-------------|
| **Deploy** | Asked to deploy or prepare a release | Runs a 6-phase checklist: quality gates, DB migrations, env audit, breaking changes, release notes, sign-off |
| **Security Review** | Code touches auth, payments, or "security" appears in task | Runs a full security audit: auth checks, input validation, data exposure, secrets, dependencies, OWASP vulnerabilities |

### Agents — Isolated Subagents

Agents run in their own context with a specific persona. They see only what's given to them:

| Agent | Persona | Output |
|-------|---------|--------|
| **Code Reviewer** | Senior engineer, direct and constructive | Structured report with Critical/Warning/Suggestion findings + APPROVE/REQUEST_CHANGES verdict |
| **Security Analyst** | Security engineer, thorough and paranoid | Threat model + vulnerability report rated Critical/High/Medium/Hardening + overall risk rating |

---

## Tech Stack (Template Default)

This template is pre-configured for a common full-stack setup. Adjust to your needs:

| Layer | Technology |
|-------|-----------|
| Language | TypeScript / Node.js |
| Framework | Next.js 14 (App Router) |
| Database | PostgreSQL via Prisma ORM |
| Testing | Vitest (unit/integration) + Playwright (E2E) |
| Styling | Tailwind CSS |
| Validation | Zod |

---

## Customizing the Template

### Add a new rule

Create a file in `.claude/rules/` and register it in `settings.json`:

```jsonc
// .claude/settings.json
{
  "rules": [
    ".claude/rules/code-style.md",
    ".claude/rules/testing.md",
    ".claude/rules/api-conventions.md",
    ".claude/rules/your-new-rule.md"   // Add here
  ]
}
```

### Add a new command

Create a markdown file in `.claude/commands/`:

```markdown
# /your-command — Short Description

## Steps
1. What Claude should do first
2. Then what
3. Final step

## Usage
/your-command <argument>
```

### Add a new skill

Create a directory in `.claude/skills/` with a `skill.md`:

```
.claude/skills/your-skill/
  skill.md    # Workflow definition with triggers
```

### Add a new doc

Create a markdown file in the appropriate `claudedocs/` subfolder with frontmatter:

```markdown
---
title: Your Feature Name
status: planned
date: 2026-04-01
related: []
---

# Your Feature Name

## Goal
One sentence on what this achieves.

## Scope
...
```

Then add a row to `claudedocs/INDEX.md` so Claude can discover it.

### Add a new agent

Create a markdown file in `.claude/agents/`:

```markdown
# Agent: Your Agent Name

**Type**: Isolated subagent
**Persona**: Description of the agent's expertise

## Identity
Who this agent is and how it behaves.

## Scope
What it does and does NOT do.

## Output Format
How it structures its response.
```

---

## Setup Checklist

- [ ] Clone this template into your project
- [ ] Edit `CLAUDE.md` with your team's tech stack, structure, and conventions
- [ ] Edit `.claude/settings.json` with your team's permission preferences
- [ ] Edit `.claude/rules/` to match your coding standards
- [ ] Add `.claude/settings.local.json` and `CLAUDE.local.md` to `.gitignore`
- [ ] Create your own `CLAUDE.local.md` for personal preferences
- [ ] Customize or add commands, skills, and agents as needed
- [ ] Commit and share with your team

---

## License

MIT
