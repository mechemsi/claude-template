# Git & Commit Rules

## Authorship and Attribution

- **Never commit as Claude.** Commits must be authored by the human developer running the session. Do not change `user.name` / `user.email` in `git config` to anything Claude-related.
- **Never add Claude as a co-author or contributor.** Do not append `Co-Authored-By: Claude …`, `Generated-by:`, `Assisted-by:`, or any similar trailer to commit messages.
- **No tool branding in commit messages.** Do not include strings like "Generated with Claude Code", "🤖", links to Claude/Anthropic, or any other reference that identifies the AI assistant.
- **No AI signature in PR descriptions either** — same rule applies to PR titles, bodies, and review comments created via `gh`.

The commit history is a record of human decisions. Tools used to draft the change are not part of that record.

## Branching

- Branch naming: `feat/`, `fix/`, `chore/`, `docs/` prefix + short kebab-case description.
- Never commit directly to `main` — always work on a branch and open a PR.

## Commit Messages

- Use Conventional Commits: `feat:`, `fix:`, `chore:`, `docs:`, `refactor:`, `test:`, `perf:`.
- Subject line ≤ 72 characters, imperative mood ("add", not "added").
- Body (if any) explains **why**, not **what** — the diff already shows what.
- Reference issues/PRs by number when relevant (`Fixes #123`).

## What NOT to Commit

- Secrets, `.env*` files (other than `.env.example`), credentials, tokens.
- Generated build artifacts, logs, temporary scripts.
- Commented-out code — use git history instead.
- Files outside the scope of the stated change. One commit, one logical change.

## Before Committing

- Run `git status` and `git diff --staged` and review every hunk.
- Stage files explicitly by name — avoid `git add .` / `git add -A` to prevent accidentally including unrelated or sensitive files.
- Run lint/typecheck/tests locally if the change touches code.
- Never use `--no-verify` to bypass hooks. If a hook fails, fix the underlying issue.

## Amending and Rewriting

- Prefer new commits over `--amend` once a commit exists, especially after a hook failure (the failed commit was not actually created — amending would modify the previous one).
- Never force-push to `main` or any shared branch. Force-push only to your own feature branch, and prefer `--force-with-lease` over `--force`.
