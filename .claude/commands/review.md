# /review — Code Review

Perform a thorough code review of the specified file or recent changes.

## Steps
1. Read the target file(s) or run `git diff HEAD~1` for recent changes
2. Check against `.claude/rules/code-style.md`
3. Check against `.claude/rules/api-conventions.md`
4. Look for:
   - Security issues (SQL injection, XSS, hardcoded secrets)
   - Performance bottlenecks (N+1 queries, missing indexes, large loops)
   - Type safety gaps (any types, unchecked nulls)
   - Missing or inadequate error handling
   - Test coverage gaps
5. Output a structured report:
   - 🔴 **Critical** — must fix before merge
   - 🟡 **Warning** — should fix, explains why
   - 🟢 **Suggestion** — optional improvement
6. For each issue, show the problematic code and a corrected version

## Usage
```
/review src/server/auth.ts
/review  # reviews staged git changes
```
