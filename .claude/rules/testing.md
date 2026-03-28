# Testing Rules

All new features and bug fixes must include tests.

## Test Framework
- **Unit tests**: Vitest (`tests/unit/`)
- **Integration tests**: Vitest + test DB (`tests/integration/`)
- **E2E tests**: Playwright (`tests/e2e/`)

## What to Test
- Every new utility function → unit test
- Every API route → integration test
- Every critical user flow → E2E test
- Every bug fix → regression test that would have caught it

## Unit Test Structure
```typescript
import { describe, it, expect, vi } from 'vitest'
import { myFunction } from '@/lib/my-module'

describe('myFunction', () => {
  it('returns expected value for valid input', () => {
    expect(myFunction('valid')).toBe('expected')
  })

  it('throws for invalid input', () => {
    expect(() => myFunction('')).toThrow('Input cannot be empty')
  })

  it('handles edge case: null input', () => {
    expect(myFunction(null)).toBeNull()
  })
})
```

## Naming Conventions
- Test files: `*.test.ts` or `*.spec.ts`
- Test names: plain English, describe behavior not implementation
  - ✅ `'returns null when user is not found'`
  - ❌ `'test getUserById null case'`

## Mocking
- Mock external services (email, payment, 3rd party APIs) — never call them in tests
- Mock the DB in unit tests; use a real test DB for integration tests
- Use `vi.mock()` at the top of the file

## Coverage Goals
- Utilities: 90%+
- API routes: 80%+
- Components: 70%+
- Don't chase coverage numbers — test behavior, not lines

## E2E Test Rules (Playwright)
- Tests must be independent — no shared state between tests
- Use `data-testid` attributes for selectors, not CSS classes
- Clean up created data after each test
