# File and Module Structure

Code is read more than written. Small, single-purpose files in clearly-organized folders make a codebase navigable years later.

## File Size

| Limit | Threshold | Action |
|-------|-----------|--------|
| Soft  | 200 lines | Reconsider — likely doing more than one thing |
| Hard  | 400 lines | Must split before merge, no exceptions |

A 400-line file is a code smell. Hard exceptions: generated code, schema files, test fixtures, lock files, vendored snapshots.

## One Concept Per File

- One React/Vue component per file
- One service / one class per file
- One route handler per file (or one resource's CRUD bundle)
- Pure utility helpers can group, but only if they share a domain (e.g. `date-utils.ts`, not `helpers.ts`)

A file's name must tell the reader what's inside. `utils.ts`, `helpers.ts`, `misc.ts`, `common.ts` are anti-names.

## Folder Layout

Default to **folder-per-feature** (vertical slicing) for application code. Default to **folder-per-layer** only at framework-imposed boundaries.

```
✅ Folder-per-feature                   ❌ Folder-per-layer (for app code)
src/                                    src/
  auth/                                   controllers/
    auth-service.ts                         auth.ts
    auth-routes.ts                          billing.ts
    auth-types.ts                         services/
    auth.test.ts                            auth.ts
  billing/                                  billing.ts
    billing-service.ts                    types/
    billing-routes.ts                       auth.ts
    billing-types.ts                        billing.ts
```

Vertical slicing keeps changes local: editing "auth" touches one folder, not five.

## Module Boundaries

A folder = a module. Each module has:
- A **public surface**: what's exported from `index.ts` (barrel) or the named entry file.
- An **internal surface**: everything else. Never imported from outside the module.

```ts
// src/auth/index.ts — public API
export { authService } from './auth-service';
export type { Session, User } from './auth-types';

// src/auth/_internal.ts or src/auth/internal/  — not exported
```

Outside the module, only `import { x } from '@/auth'` is allowed. Reaching into `@/auth/_internal.ts` is a violation.

## Naming Conventions for Files

| Kind | Convention | Example |
|------|------------|---------|
| Component | PascalCase | `UserCard.tsx` |
| Hook | camelCase, `use` prefix | `useAuth.ts` |
| Service / utility | kebab-case | `auth-service.ts`, `format-date.ts` |
| Types-only | `*.types.ts` or `*-types.ts` | `auth.types.ts` |
| Tests | adjacent `*.test.ts` or `tests/` mirror | `auth-service.test.ts` |

Don't mix conventions within the same project. Pick one and stick to it.

## Imports

- Group order: 1) Node built-ins, 2) external packages, 3) internal `@/...` aliases, 4) relative.
- Blank line between groups.
- No relative imports across modules. Use the alias.
- No `import * as X` for first-party code — be explicit.

```ts
// ✅
import { readFile } from 'node:fs/promises';

import { z } from 'zod';

import { authService } from '@/auth';

import { formatTotal } from './format';

// ❌ — reaching across modules with relatives
import { authService } from '../../auth/auth-service';
```

## Co-location

Keep things that change together close together:
- Tests next to the code they test (or in a parallel `tests/` mirror — pick one).
- Component CSS module next to the component.
- Route handler next to its validators and types.

## When to Split a File

A file is doing too much when:
- It exceeds 200 lines.
- The first 30 lines of imports + types feel like prelude.
- One section needs different unit tests than another.
- Two functions in it never call each other and depend on disjoint types.

## When NOT to Split

- Don't split a 60-line file into 5×15-line files. Cohesion matters.
- Don't extract a single-use helper into its own file just for "modularity".
- Don't create folders with one file inside.
