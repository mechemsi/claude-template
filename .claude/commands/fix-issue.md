# /fix-issue — Fix a GitHub Issue

Given an issue number or description, locate the bug and apply a fix.

## Steps
1. Read the issue description provided by the user
2. Search the codebase for relevant files (`grep`, file reads)
3. Reproduce the logic of the bug mentally — trace the data flow
4. Propose a fix with explanation
5. Apply the fix
6. Write or update a test that would catch this regression
7. Run `npm run typecheck` and `npm run test` to verify
8. Summarize what was changed and why

## Usage
```
/fix-issue #42
/fix-issue "Login button does nothing when email is empty"
```

## Rules
- Do not change unrelated code
- Keep the fix minimal and focused
- Add a comment if the fix is non-obvious
