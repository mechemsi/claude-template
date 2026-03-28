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

## Authentication
- All protected routes check for a valid session using `getServerSession()`
- Return 401 (not 403) when no session exists
- Return 403 when session exists but lacks permission

## Pagination
- Default page size: 20, max: 100
- Use `?page=1&perPage=20` query params
- Always return `meta.total` so clients can calculate pages
