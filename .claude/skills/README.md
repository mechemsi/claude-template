# Project-Local Skills

Skills placed here are **scoped to this project only** — Claude Code auto-discovers them when a session is opened in this repo, and they do not leak into other projects on the developer's machine.

## When to put a skill here vs. in the root `skills/` library

| Place it in `.claude/skills/` (here) when… | Place it in the root `skills/` library when… |
|--------------------------------------------|----------------------------------------------|
| The skill encodes a workflow specific to this codebase (e.g. how *this* project's deploy ritual works) | The skill is a generic engineering pattern (SOLID, code smells, PRD writing) |
| It references file paths, services, or domain concepts that only exist here | It applies to any project of this kind |
| Sharing it with other projects would be confusing or harmful | Other projects on your machine would benefit from it being globally installed |

The root `skills/` library is installed user-global by `make install` from the repo root and applies to every project. This directory ships *with* the project and is checked into git.

## Skill anatomy

Each skill is a directory with a `SKILL.md` (frontmatter + body) and optional supporting files:

```
.claude/skills/my-skill/
  SKILL.md            # required — frontmatter + instructions
  references/         # optional — supporting docs, examples
  scripts/            # optional — helper scripts the skill invokes
```

The `SKILL.md` frontmatter must include `name` and `description`. The description is what Claude reads to decide whether the skill applies, so make it specific about *when* to invoke it, not just *what* it does.

See examples in the root `skills/` directory of this repo for the conventions to follow.
