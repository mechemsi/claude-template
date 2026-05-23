---
name: agent-config-sync
description: Use when syncing, auditing, or converting Claude Code and Codex project configuration; when the user says "sync agent configs", "convert Claude project to Codex", "convert Codex project to Claude", "make this project work with both Claude and Codex", or asks to keep AGENTS.md, CLAUDE.md, .claude, .codex, .mcp.json, agents, commands, and skills aligned.
---

# Agent Config Sync

Keep Claude Code and Codex adapters aligned without pretending their config formats are identical.

## What syncs

- `CLAUDE.md` <-> `AGENTS.md` project instructions
- `.claude/agents/*.md` <-> `.codex/agents/*.toml` subagent/custom-agent definitions
- `.claude/commands/*.md` -> `.agents/skills/claude-command-*/SKILL.md` Codex workflow skills
- `.claude/skills/*/SKILL.md` <-> `.agents/skills/*/SKILL.md` project-local skills
- `.mcp.json` <-> `[mcp_servers.*]` entries in `.codex/config.toml`
- `.codex/config.toml` project defaults for Codex instruction fallback and subagent limits

## Do Not Sync Blindly

- Claude hooks and Codex hooks are not guaranteed to have the same event payloads. Keep hook scripts shared only after checking each hook's stdin schema.
- Claude permissions in `.claude/settings.json` and Codex approval rules in `.codex/rules/*.rules` use different policy languages. Convert intent, not syntax.
- Existing project-specific files win unless the user passes `--force` or explicitly asks to overwrite.

## Workflow

Run an audit first:

```bash
python3 /path/to/claudet/skills/agent-config-sync/scripts/agent_config_sync.py --target . --check
```

Apply missing adapters:

```bash
python3 /path/to/claudet/skills/agent-config-sync/scripts/agent_config_sync.py --target .
```

Overwrite stale generated adapters only when the user explicitly asks:

```bash
python3 /path/to/claudet/skills/agent-config-sync/scripts/agent_config_sync.py --target . --force
```

Convert in one direction only:

```bash
python3 /path/to/claudet/skills/agent-config-sync/scripts/agent_config_sync.py --target . --direction claude-to-codex
python3 /path/to/claudet/skills/agent-config-sync/scripts/agent_config_sync.py --target . --direction codex-to-claude
```

## Safety Rules

- Treat root `skills/` as the shared global skill source for claudet itself; do not copy it into generated projects.
- Keep project-local skills in `.claude/skills/` and `.agents/skills/` only when they reference that specific codebase.
- After syncing, inspect `git diff` and validate any generated TOML/JSON before committing.

## Common Prompts

- "Make this Claude project Codex-compatible."
- "Audit this repo for Claude/Codex config drift."
- "Convert Codex agents back into Claude agents."
- "Sync MCP and skills between Claude and Codex here."
