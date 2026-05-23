# Codex Project Skills

Codex scans `.agents/skills/` for project-local skills. This template keeps reusable cross-project skills in root `skills/` instead; `make install` symlinks those skills into `~/.agents/skills/` for Codex and `~/.claude/skills/` for Claude.

Use this folder only for skills that are specific to one generated project. Use `skills/agent-config-sync` to convert Claude project-local skills or commands into Codex project-local skills when needed.
