# API Design Conventions

All API routes follow these conventions consistently.

## Route Structure
```
/api/v1/[resource]          GET (list), POST (create)
/api/v1/[resource]/[id]     GET (single), PUT (replace), PATCH (update), DELETE
```

## Response Format
All responses use a consistent envelope:

```typescript
// Success
{
  "success": true,
  "data": { ... },          // single resource
  "meta": {                 // only on list responses
    "total": 100,
    "page": 1,
    "perPage": 20
  }
}

// Error
{
  "success": false,
  "error": {
    "code": "USER_NOT_FOUND",    // machine-readable, SCREAMING_SNAKE
    "message": "User not found", // human-readable
    "details": { ... }           // optional extra context
  }
}
```

## HTTP Status Codes
| Situation             | Code |
|----------------------|------|
| Success (GET/PATCH)  | 200  |
| Created (POST)       | 201  |
| No content (DELETE)  | 204  |
| Bad request          | 400  |
| Unauthorized         | 401  |
| Forbidden            | 403  |
| Not found            | 404  |
| Conflict             | 409  |
| Validation error     | 422  |
| Server error         | 500  |

## Validation
- Use Zod schemas for all request body validation
- Validate at the route handler level before calling any service
- Return 422 with field-level errors for validation failures

```typescript
const schema = z.object({
  email: z.string().email(),
  name: z.string().min(2).max(100),
})

const result = schema.safeParse(req.body)
if (!result.success) {
  return res.status(422).json({
    success: false,
    error: {
      code: 'VALIDATION_ERROR',
      message: 'Invalid request data',
      details: result.error.flatten()
    }
  })
}
```

## API Gate (shared-secret header)

Every endpoint under `/api/**` is gated by a shared-secret header. This runs **before** session/role checks so that a leaked session alone is not enough to reach the API.

- Header name: `X-API-Secret`
- Source of truth: `process.env.API_SECRET` (set per-environment, never committed)
- Failure mode: respond `401` with `error.code = 'MISSING_API_SECRET'` and no body details
- Comparison: constant-time (`crypto.timingSafeEqual`) — never `===`
- Enforcement: a single middleware applied to the whole `/api` tree. Per-route opt-in is forbidden — the default is "gated", and exceptions live in one whitelist.

```ts
// src/server/middleware/api-gate.ts
import { timingSafeEqual } from 'node:crypto'

const expected = Buffer.from(process.env.API_SECRET ?? '')

export function checkApiSecret(headerValue: string | undefined): boolean {
  if (!expected.length || !headerValue) return false
  const got = Buffer.from(headerValue)
  if (got.length !== expected.length) return false
  return timingSafeEqual(got, expected)
}
```

Whitelist (no secret required):
- `/api/health` — liveness probe used by the load balancer
- Anything else must be explicitly added with a comment explaining why

If `API_SECRET` is unset at boot, the server must refuse to start. Silent fallback to "no gate" is forbidden.

## Authentication
- All protected routes check for a valid session using `getServerSession()` **after** the API gate has passed
- Return 401 (not 403) when no session exists
- Return 403 when session exists but lacks permission

## Pagination
- Default page size: 20, max: 100
- Use `?page=1&perPage=20` query params
- Always return `meta.total` so clients can calculate pages
