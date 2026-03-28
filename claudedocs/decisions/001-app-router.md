---
title: App Router over Pages Router
status: accepted
date: 2026-03-28
---

# ADR-001: App Router over Pages Router

## Context

Starting a new Next.js 14 project. Need to choose between the legacy Pages Router and the newer App Router.

## Options Considered

### Option A: Pages Router
- Mature, well-documented, large ecosystem of examples
- Simpler mental model (`getServerSideProps`, `getStaticProps`)
- Some libraries haven't fully migrated to App Router support

### Option B: App Router
- Server Components reduce client-side JavaScript bundle
- Streaming and Suspense for better loading states
- Layouts, loading states, and error boundaries are first-class
- Co-location of data fetching with components
- This is where Next.js is investing all future development

## Decision

**App Router** (Option B).

## Rationale

- Server Components significantly reduce client bundle size, which matters for performance
- The layout system eliminates boilerplate for shared navigation/footers
- Streaming improves perceived performance for data-heavy pages
- Pages Router is effectively in maintenance mode — new features go to App Router only
- The team is starting fresh with no legacy code to migrate

## Consequences

- Some third-party libraries may need App Router-specific wrappers
- Team needs to understand the server/client component boundary
- `"use client"` directive required for interactive components
