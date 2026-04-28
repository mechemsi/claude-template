# Project Plugins

Plugins are first-class in Claude Code as of 2026 and are invoked as `/plugin:command`. A plugin can bundle several related capabilities (slash commands, agents, skills, MCP servers, hooks) under one namespace, so a teammate cloning the repo gets the whole bundle wired up at once.

## Layout

Each plugin is a directory:

```
.claude/plugins/<plugin-name>/
  plugin.json           # required — name, description, exposed surface
  commands/             # optional — slash commands → /plugin-name:command
  agents/               # optional — subagent definitions
  skills/               # optional — model-invokable skills
  hooks/                # optional — lifecycle scripts
  .mcp.json             # optional — bundled MCP servers
```

## When to make a plugin vs. drop files in `.claude/`

| Plugin when… | Loose files in `.claude/` when… |
|--------------|---------------------------------|
| Several related capabilities ship together (e.g. a "vercel" bundle with deploy command, log-analyzer agent, and Vercel MCP) | A single command, agent, or hook stands alone |
| The bundle is reusable across multiple projects | The capability is one-off and project-specific |
| You want a clean namespace (`/vercel:deploy`, not a generic `/deploy` that collides) | Naming collisions aren't a concern |

## Example skeleton

`.claude/plugins/example/plugin.json`:

```json
{
  "name": "example",
  "description": "Example plugin showing the bundle layout.",
  "version": "0.1.0"
}
```

Then `/plugin:example:hello` would invoke `commands/hello.md` inside this plugin.

## Conventions

- One plugin per directory; the dir name is the plugin namespace.
- Keep `plugin.json` minimal — let the contents of `commands/`, `agents/`, etc. speak for themselves.
- A plugin should have a single coherent purpose. If it's growing in three directions, split it.
