---
name: api-design
description: Use when designing or reviewing HTTP/REST endpoints; when picking method/status/URL shapes; when adding pagination, filtering, or sorting; when versioning an API; when an operation might be retried (idempotency); when an existing API is inconsistent or hard to use.
---

# API Design

Treat the API as a contract with consumers you don't control. Once shipped, breaking changes are expensive.

## When to apply

- New endpoint or new resource
- Reviewing PRs that touch the wire format
- Old API has 12 inconsistent shapes and a new one is needed
- A client retries POST and creates duplicates
- A list endpoint times out on large datasets

## REST resource modeling

A resource is a noun. Operations are HTTP methods on that noun.

```
GET    /v1/orders             list
POST   /v1/orders             create
GET    /v1/orders/{id}        retrieve
PATCH  /v1/orders/{id}        partial update
PUT    /v1/orders/{id}        replace
DELETE /v1/orders/{id}        remove

GET    /v1/orders/{id}/items  sub-resource list
POST   /v1/orders/{id}/items  add item
```

Avoid:
- Verbs in URLs: `/getOrder`, `/createOrder` — the method is the verb.
- Mixing styles: `/orders` then `/order/{id}` — pick singular *or* plural and stay consistent (collections plural is the norm).
- Unbounded nesting: 3 levels max. Past that, expose the inner resource at the top level with a filter.

## HTTP method semantics

| Method | Safe? | Idempotent? | Body? | Use for |
|--------|-------|-------------|-------|---------|
| GET    | yes   | yes         | no    | retrieve |
| HEAD   | yes   | yes         | no    | metadata only |
| OPTIONS| yes   | yes         | no    | CORS / capabilities |
| POST   | no    | no          | yes   | create / non-idempotent action |
| PUT    | no    | yes         | yes   | replace whole resource |
| PATCH  | no    | no*         | yes   | partial update |
| DELETE | no    | yes         | optional | remove |

*PATCH idempotency depends on payload semantics. JSON-Merge-Patch is idempotent; deltas typically aren't.

## Status codes — be specific

```
200 OK                  — success with body
201 Created             — POST that produced a resource (include Location header)
202 Accepted            — async work queued
204 No Content          — success without body (DELETE)
301/302                 — redirects
400 Bad Request         — malformed JSON, missing required field
401 Unauthorized        — no/invalid auth
403 Forbidden           — authed but not allowed
404 Not Found           — resource missing
409 Conflict            — concurrent modification, version mismatch
422 Unprocessable Entity — validation failed (good, machine-readable)
429 Too Many Requests   — rate limited (include Retry-After)
500 Internal Server Error — unexpected
502/503/504             — gateway / unavailable / timeout
```

Don't use `200 { error: ... }`. The status code IS the error signal. Clients should be able to branch on `response.ok` alone.

## Idempotency

POSTs that create resources or charge money MUST support idempotency keys. Otherwise a network retry creates duplicates.

```http
POST /v1/charges
Idempotency-Key: a1b2c3d4-...

{ "amountCents": 1000, "card": "..." }
```

Server stores `(idempotency_key → response)` for at least 24h. If the same key arrives again, return the original response, don't process again.

PUT, DELETE are idempotent by HTTP definition — let the framework handle retries.

## Versioning

Pick one strategy and stick to it. The two acceptable choices:

1. **URL path** (`/v1/orders`, `/v2/orders`) — explicit, easy to route, ugly for long-lived APIs.
2. **Header** (`Accept: application/vnd.acme.v2+json`) — clean URLs, harder to debug in browsers.

URL-path versioning is the default for most teams.

Never:
- Bump the major version for a non-breaking change.
- Run more than 2 major versions in production simultaneously.
- Assume "we'll never need v2" — leave room.

## Pagination

| Style | When | Tradeoff |
|-------|------|----------|
| **Offset** (`?page=2&perPage=20`) | Static, small datasets | Slow on large data, drifts during writes |
| **Cursor** (`?cursor=abc&limit=20`) | Live data, large sets | Can't jump to page N |
| **Time-based** (`?before=2026-04-01`) | Event streams | Only works with monotonic time field |

Cursor pagination is the safer default. Return `nextCursor` in the response, not in headers.

```json
{
  "data": [ ... ],
  "page": {
    "nextCursor": "eyJpZCI6MTAwfQ",
    "hasMore": true
  }
}
```

Always cap `limit` (default 20, max 100). Unbounded pagination is a DoS vector.

## Filtering, sorting, sparse fields

Standard query-string conventions:

```
GET /v1/orders?status=paid&customerId=u_123
GET /v1/orders?sort=-createdAt              (- = descending)
GET /v1/orders?fields=id,status,total       (sparse fieldset)
GET /v1/orders?include=customer,items       (sideloading)
```

Don't reinvent SQL in query params. If consumers need GraphQL-level flexibility, use GraphQL.

## Error envelope

A consistent error shape, always. (See also `.claude/rules/api-conventions.md` for the project's exact envelope.)

```json
{
  "error": {
    "code": "INSUFFICIENT_FUNDS",
    "message": "Card was declined for funds.",
    "details": { "available": 50, "requested": 100 },
    "requestId": "req_abc123"
  }
}
```

- `code`: stable, SCREAMING_SNAKE, machine-readable. Clients branch on this, never on `message`.
- `message`: human-readable. May be localized.
- `details`: structured context.
- `requestId`: present on every response (success or error) — supports cross-team triage.

## Authentication

- Bearer tokens in `Authorization: Bearer <token>`. Never in query strings (logged everywhere).
- API keys: rotate-able, revocable, per-environment, scoped.
- Cookies for browser sessions only; never cross-origin without CSRF protection.

## Rate limiting

Return:
```http
HTTP/1.1 429 Too Many Requests
Retry-After: 60
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 0
X-RateLimit-Reset: 1714123456
```

Per-user or per-key, not per-IP (NATs share IPs).

## Backwards compatibility

Within a major version, never:
- Remove a field
- Rename a field
- Change a field's type
- Make an optional field required
- Tighten validation on existing fields

Always safe:
- Add a new optional field
- Add a new endpoint
- Loosen validation
- Add a new value to an enum *if* clients are documented to ignore unknown values (otherwise this is breaking too)

## Documentation

OpenAPI / JSON Schema is non-negotiable for any API consumed by code you don't control. Generate clients from it; treat the schema as the contract.

## Common mistakes

- 200 OK with `{ error: ... }` body — clients can't branch cleanly.
- POST that creates a resource without an idempotency key — retries duplicate.
- Offset pagination over a write-heavy dataset — clients see duplicates and skips.
- Returning stack traces in error bodies — info leak.
- Versioning by adding a `?v2=true` flag — avoid; it's a footgun for caches and logs.

## Related

- `error-handling` — domain errors map to HTTP status + envelope at the boundary.
- `12-factor-app` — config (URLs, secrets) via env vars; no hardcoded endpoints.
- `.claude/rules/api-conventions.md` — project-specific envelope, validation, and pagination defaults.
