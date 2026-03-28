---
title: Auth System
status: planned
date: 2026-03-28
related: []
---

# Auth System

## Goal

Implement JWT-based authentication with role-based access control (RBAC) for the application.

## Scope

### In Scope
- Email/password login and registration
- JWT token issuance and validation
- Role-based route protection (admin, user, guest)
- Password reset flow with secure tokens
- Session management via HTTP-only cookies

### Out of Scope
- OAuth/social login (future phase)
- Multi-factor authentication (future phase)
- API key management

## Technical Approach

- Use `next-auth` v5 with Prisma adapter
- Store sessions in PostgreSQL
- Middleware-based route protection in `src/middleware.ts`
- Zod schemas for all auth-related request validation

## Data Model

```prisma
model User {
  id        String   @id @default(cuid())
  email     String   @unique
  password  String
  role      Role     @default(USER)
  sessions  Session[]
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt
}

enum Role {
  ADMIN
  USER
  GUEST
}
```

## API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| POST | `/api/v1/auth/register` | Create new account |
| POST | `/api/v1/auth/login` | Authenticate and issue token |
| POST | `/api/v1/auth/logout` | Invalidate session |
| POST | `/api/v1/auth/reset-password` | Request password reset |
| PUT | `/api/v1/auth/reset-password` | Set new password with token |

## Success Criteria

- [ ] Users can register, login, and logout
- [ ] Protected routes return 401 without valid session
- [ ] Admin routes return 403 for non-admin users
- [ ] Password reset emails are sent and tokens expire after 1 hour
- [ ] All auth endpoints have integration tests
