---
name: typescript-database-layer
description: Use when creating, extending, reviewing, or refactoring TypeScript backend database or repository layers. Triggers on tasks involving data access code, repository patterns, database client setup, query organization, dependency injection, or tests for backend services.
---

# TypeScript Database Layer

Build database-layer code as a staff-level TypeScript backend engineer: explicit, testable, fast to understand, easy to extend.

## Architecture

Three layers, each with one job:

```
UserService          ← business logic, product rules, workflow
    ↓ depends on
UserRepository       ← persistence: queries, row mapping, domain API
    ↓ depends on
DatabaseClient       ← infrastructure: pool, query execution, transactions
```

## When to read each reference

- Adding or modifying connection setup, pooling, transactions → read [database-client.md](database-client.md)
- Adding or modifying repository methods, row mapping, query text → read [repository.md](repository.md)
- Adding or modifying service logic, business rules, orchestration → read [service.md](service.md)

When touching multiple layers, read the relevant files in order: database-client → repository → service.

## Core principles

- Prefer simple, obvious designs over abstract frameworks.
- Keep SQL explicit — do not hide it behind excessive abstraction.
- One repository per domain boundary, not one per table.
- Inject dependencies through constructors. No service locators, no hidden globals.
- Make test seams obvious: mock the database client in repository tests, mock repositories in service tests.
- Do not swallow errors. Wrap only when adding meaningful domain context.
- Use transactions only when needed for correctness; keep scope tight.

## Common mistakes

| Mistake | Fix |
|---------|-----|
| Business logic in repository | Move to service |
| Raw SQL in service | Move to repository |
| Driver imports spread across files | Centralize in `DatabaseClient` |
| Constructing clients per request | Inject a shared pool |
| Swallowing database errors | Propagate or wrap with context |
