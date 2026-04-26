---
name: security-review
description: Use when asked to review code for security; before deploying auth, payment, or other sensitive code paths; when handling user input, secrets, or API endpoints; or when the word "security" appears in a task.
---

# Security Review

Perform a deep security audit of code changes or a specified module.

## Workflow

### Step 1 — Identify Scope
- If given a file: audit that file
- If given a PR/diff: audit all changed files
- If given a feature name: find all related files first

### Step 2 — Run Security Checklist

#### Authentication & Authorization
- [ ] All protected routes check session/token before processing
- [ ] Role checks happen server-side, never trust client-sent roles
- [ ] Tokens are short-lived and properly invalidated on logout
- [ ] Password reset flows are rate-limited and use secure tokens

#### Input Validation
- [ ] All user inputs are validated with Zod or equivalent
- [ ] No raw SQL queries — use Prisma ORM only
- [ ] File uploads validate MIME type AND file contents
- [ ] URL parameters are sanitized before use

#### Data Exposure
- [ ] API responses never include password hashes, tokens, or internal IDs
- [ ] Error messages don't leak stack traces or internal paths to clients
- [ ] Prisma `select` used to explicitly choose returned fields

#### Secrets & Config
- [ ] No hardcoded secrets, API keys, or credentials anywhere
- [ ] All secrets accessed via `process.env.*`
- [ ] `.env` files are in `.gitignore`

#### Dependencies
- [ ] Run `npm audit` — flag any high/critical vulnerabilities
- [ ] No packages with known CVEs in the dependency tree

#### Common Vulnerabilities
- [ ] XSS: user content is escaped before rendering
- [ ] CSRF: state-changing requests use CSRF tokens or SameSite cookies
- [ ] Rate limiting on login, signup, and password reset endpoints
- [ ] No `eval()` or `new Function()` with user-controlled input

### Step 3 — Report
Output findings grouped by severity:
- 🔴 **Critical** — exploitable vulnerability, block deploy
- 🟠 **High** — serious risk, fix this sprint
- 🟡 **Medium** — should fix, low exploitability
- 🔵 **Info** — best practice suggestion

For each finding include:
1. What the vulnerability is
2. Where it exists (file + line)
3. How it could be exploited
4. The fix with code example
