# Database Client Layer

## Responsibility

This layer owns the raw mechanics of talking to the database. Its job is to manage the connection pool, expose a small query or transaction interface, and act as the single place where low-level database concerns live.

A good database client layer is intentionally boring: easy to understand, stable, and rarely changed. It wraps the underlying driver and presents a narrow API the rest of the codebase can depend on consistently.

**This layer does not know:**
- What a user, account, or domain object is
- Any business rule or product decision
- What the application is trying to accomplish

## What belongs here

- Connection pooling and lifecycle
- Transaction entry points (`withTransaction`)
- Basic query/logging hooks and timing
- Retry behavior (if the architecture calls for it)
- Converting raw driver responses into shapes repositories can consume

## What does not belong here

Domain-aware logic of any kind. If the code knows what a "user" or "account" is, it has leaked into the wrong layer.

## Design goal

Consistency and replaceability. Repositories should depend on a stable `DatabaseClient` interface rather than raw driver imports. That means:

- Repositories can be tested by mocking the client — no live database required.
- Driver swaps, pooling changes, or instrumentation updates stay localized here.

A bad version of this layer looks like raw driver imports spread across many repositories, each constructing its own client. That creates duplication, inconsistent error handling, and painful future changes.

## Example

```ts
import { Pool } from 'pg';

export interface DatabaseClient {
  query<T>(sql: string, params?: readonly unknown[]): Promise<readonly T[]>;
}

export class PostgresDatabaseClient implements DatabaseClient {
  constructor(private readonly pool: Pool) {}

  async query<T>(
    sql: string,
    params: readonly unknown[] = [],
  ): Promise<readonly T[]> {
    const result = await this.pool.query<T>(sql, [...params]);
    return result.rows;
  }
}
```

This layer does one thing: execute queries through a shared pool. It does not know what a user is, what "active" means, or what the business is trying to accomplish.

## Adding transaction support

```ts
export interface DatabaseClient {
  query<T>(sql: string, params?: readonly unknown[]): Promise<readonly T[]>;
  withTransaction<T>(fn: (client: DatabaseClient) => Promise<T>): Promise<T>;
}
```

Keep `withTransaction` on the interface so repositories can accept it and remain testable. The transaction scope and client lifecycle stay entirely within this layer.

## Testing

Mock `DatabaseClient` in repository tests. The interface is narrow and easy to stub:

```ts
const mockDb: DatabaseClient = {
  query: vi.fn().mockResolvedValue([{ id: '1', email: 'a@example.com', status: 'pending' }]),
};
```

No live database needed for repository-level tests.
