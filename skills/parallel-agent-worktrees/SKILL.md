---
name: parallel-agent-worktrees
description: Use when about to dispatch a long-running agent task that will modify files and the user wants to keep editing the main checkout; when planning to run two or more agents in parallel on the same repo and worried about file-edit collisions; when reviewing a PR or running a risky/experimental edit without losing current uncommitted state; when bisecting a bug across branches; when comparing two implementations side-by-side; when a destructive operation (large refactor, dependency upgrade, codemod) needs an escape hatch.
---

# Parallel Agent Worktrees

Git worktrees let one repo have multiple working directories at once, each on its own branch, sharing a single `.git` directory. They are the right primitive for parallel agent work — each agent gets a private filesystem, branches don't collide, and the main checkout stays usable.

This skill standardises the convention: worktrees live under `.worktrees/<slug>/` in the repo root, hidden by the leading dot, gitignored, and never committed.

## When to use

- Dispatching a long-running agent task and you want to keep editing in the main checkout
- Running 2+ agents in parallel on the same repo
- Reviewing a teammate's PR locally without stashing current work
- Trying a risky edit that might be discarded
- Bisecting a bug while keeping the main checkout on the working state

## When not to use

- Single-shot edit that completes in seconds — overhead not worth it
- Read-only exploration — no isolation needed
- Task modifies files outside git (e.g. `~/.config/...`) — worktrees only isolate repo state

## Convention

| Item | Value | Why |
|---|---|---|
| Directory | `.worktrees/<slug>/` at repo root | Hidden via leading dot, lives next to the project for easy `cd` |
| `.gitignore` | Must contain `.worktrees/` | Worktree contents must never be committed |
| Slug | `<type>-<short-description>` (e.g. `feat-billing-rewrite`, `fix-flaky-auth-test`) | Matches branch naming; readable in `git worktree list` |
| Branch | One branch per worktree, never shared | Git refuses to check out one branch in two worktrees |

## One-time per repo: ensure `.gitignore` covers `.worktrees/`

Before creating the first worktree:

```bash
grep -qxF '.worktrees/' .gitignore || echo '.worktrees/' >> .gitignore
git add .gitignore && git commit -m "chore: gitignore .worktrees/"
```

If the repo was scaffolded from `claude-template`, this is already done.

## Lifecycle

### Create

```bash
# new branch from main
git worktree add .worktrees/feat-billing-rewrite -b feat/billing-rewrite main

# existing branch (e.g. reviewing a PR)
git worktree add .worktrees/review-pr-123 origin/feat/that-pr-branch
```

### Set up the worktree's environment

Worktrees share `.git` but **not** gitignored files. `node_modules/`, `.env`, `.venv/`, build artifacts — none of those exist in the new worktree. After creation:

```bash
cd .worktrees/feat-billing-rewrite
cp ../../.env .env             # or symlink: ln -s ../../.env .env
<package-manager> install      # npm/pnpm/yarn install, or cargo build, etc.
```

Cost mitigations when this is expensive:
- pnpm uses a content-addressable store — worktrees get hardlinks, not copies
- Rust: shared `target/` via `CARGO_TARGET_DIR`
- Heavy installs amortise once you reuse worktrees rather than re-creating

### Hand the worktree to the agent

Dispatch the agent with the worktree path as its working directory. Each agent then:
- Edits files only inside `.worktrees/<slug>/`
- Runs its own dev server / tests without colliding with the main checkout (use distinct ports)
- Commits to its own branch

### Deliver

The branch lives in the shared `.git`, so from the main checkout:

```bash
git log feat/billing-rewrite
git diff main..feat/billing-rewrite
gh pr create --head feat/billing-rewrite
```

### Clean up

```bash
git worktree remove .worktrees/feat-billing-rewrite
git branch -d feat/billing-rewrite      # -D if abandoning unmerged work
```

If a worktree directory was deleted manually, prune the dangling registration:

```bash
git worktree prune
```

## Running multiple agents in parallel

```bash
# Agent A
git worktree add .worktrees/feat-billing-rewrite -b feat/billing-rewrite main

# Agent B
git worktree add .worktrees/fix-flaky-auth-test -b fix/flaky-auth-test main
```

Both agents have their own checkout, their own `node_modules/`, their own dev server port. They cannot edit each other's files. They share the same database unless isolated separately (see gotchas).

When both finish, two PRs land independently.

## Gotchas

| Gotcha | Why | Fix |
|---|---|---|
| `git checkout <branch>` fails — "already used in another worktree" | Git enforces "one worktree per branch" | Use `-b` to create a new branch, or `git worktree remove` the other |
| Agent's tests pass but break in main | Worktrees share the database; test data leaked | Per-worktree DB: `DATABASE_URL=postgres://.../app_<slug>` |
| `.env` not present in the worktree | `.env` is gitignored, so it doesn't get checked out | Copy or symlink after `worktree add`; consider `direnv` |
| Two dev servers fight over port 3000 | Each worktree runs its own | Set `PORT=3001`, `PORT=3002` per worktree |
| Hooks behave inconsistently | Husky's `.husky/` is shared via git but each worktree needs its own `node_modules/.bin` | Run install in each worktree |
| Disk fills up | Many worktrees × heavy `node_modules` × build outputs | Use pnpm; remove finished worktrees promptly |
| IDE indexes project files twice | LSP, search, file-watchers may scan `.worktrees/` too | Add `.worktrees/` to your IDE's exclude list (separate from `.gitignore`) |

## Anti-patterns

- **Committing `.worktrees/` contents** — defeats the point, bloats the repo
- **Putting worktrees outside the repo** (`~/tmp/wt-billing/`) — loses the convention; harder for agents and humans to find
- **Reusing a slug** — `git worktree add` fails; pick distinct names
- **Running `git worktree add` from inside a worktree** — works, but creates relative-path confusion; do it from the main checkout

## Quick reference

```bash
git worktree add .worktrees/<slug> -b <branch> <base>   # create new branch
git worktree add .worktrees/<slug> <existing-branch>    # check out existing
git worktree list                                       # audit
git worktree remove .worktrees/<slug>                   # remove after delivery
git branch -d <branch>                                  # then drop the branch
git worktree prune                                      # tidy stale registrations
```
