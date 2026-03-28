# Code Style Rules

These rules are automatically applied by Claude on every task.

## TypeScript
- Always use strict TypeScript — no `any` types unless absolutely necessary (add a `// eslint-disable` comment with reason)
- Prefer `interface` over `type` for object shapes; use `type` for unions and aliases
- All functions must have explicit return types
- Use `unknown` instead of `any` for external data inputs

## Naming Conventions
| Thing           | Convention        | Example                      |
|----------------|-------------------|------------------------------|
| Variables       | camelCase         | `userData`, `isLoading`      |
| Functions       | camelCase         | `getUserById()`, `formatDate()` |
| Components      | PascalCase        | `UserCard`, `LoginForm`      |
| Constants       | SCREAMING_SNAKE   | `MAX_RETRIES`, `API_BASE_URL`|
| Files (util)    | kebab-case        | `format-date.ts`             |
| Files (component)| PascalCase       | `UserCard.tsx`               |
| Types/Interfaces| PascalCase        | `UserProfile`, `ApiResponse` |

## Formatting
- 2-space indentation
- Single quotes for strings
- Trailing commas in multi-line objects/arrays
- Max line length: 100 characters
- Always use semicolons

## Functions
- Prefer `const` arrow functions for utilities
- Use named exports (not default exports) except for Next.js pages
- Keep functions under 40 lines — extract helpers if longer
- Pure functions preferred — avoid side effects where possible

## Components
- One component per file
- Props interface defined at the top of the file
- Destructure props in the function signature
- No inline styles — use Tailwind classes only

## Error Handling
- All async functions must have try/catch or use a Result type
- Never swallow errors silently — always log or rethrow
- User-facing errors must be friendly — log technical details separately

## Imports
- Group imports: 1) Node built-ins 2) External packages 3) Internal modules
- Use path aliases (`@/components/...`) not relative `../../` paths
