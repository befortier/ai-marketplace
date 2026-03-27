# Repository Layer

## Responsibility

This layer encapsulates persistence concerns for a specific domain boundary. Its job is to translate between the application's domain-oriented needs and the database's storage-oriented representation.

A repository exposes methods that make sense to the rest of the backend — `getById`, `findByEmail`, `create`, `updateStatus`, `listActiveForAccount` — rather than leaking SQL mechanics or driver details upward.

## What belongs here

- Query execution (via `DatabaseClient`)
- Row-to-domain mapping
- SQL text and query constants
- Persistence-level correctness (transactional grouping of writes, not-found handling)
- Normalization between database conventions and domain conventions (e.g., snake_case → camelCase)

## What does not belong here

Business logic: permission checks, workflow sequencing, state transition rules, product decisions. If the code knows *when* something should happen, not just *how* to persist it, it belongs in the service layer.

## Design rules

- **One repository per domain boundary**, not one per table. Anemic per-table repositories that do nothing but forward calls add noise without structure.
- **Intention-revealing method names**: `getById`, `findByEmail`, `listActiveForAccount`. Never `execute`, `run`, or `doQuery`.
- **Keep SQL close**: Inline queries are fine for simple cases. For larger codebases, extract query constants to the top of the file or a sibling `queries.ts`. Either way, the repository owns the text.
- **Explicit row types**: Define a separate type for the raw database row. Map it to the domain type in `mapRow`. This makes both representations visible and the mapping testable.

## Example

```ts
export type User = {
  id: string;
  email: string;
  status: 'pending' | 'active';
};

type UserRow = {
  id: string;
  email: string;
  status: 'pending' | 'active';
};

export interface UserRepository {
  getById(id: string): Promise<User | null>;
  updateStatus(id: string, status: User['status']): Promise<User>;
}

export class PostgresUserRepository implements UserRepository {
  constructor(private readonly database: DatabaseClient) {}

  async getById(id: string): Promise<User | null> {
    const rows = await this.database.query<UserRow>(
      `
        SELECT id, email, status
        FROM users
        WHERE id = $1
      `,
      [id],
    );

    const row = rows[0];
    return row ? this.mapRow(row) : null;
  }

  async updateStatus(id: string, status: User['status']): Promise<User> {
    const rows = await this.database.query<UserRow>(
      `
        UPDATE users
        SET status = $1
        WHERE id = $2
        RETURNING id, email, status
      `,
      [status, id],
    );

    return this.mapRow(rows[0]);
  }

  private mapRow(row: UserRow): User {
    return {
      id: row.id,
      email: row.email,
      status: row.status,
    };
  }
}
```

The repository owns user persistence. It knows how to query the `users` table and map rows into domain objects, but it does not decide when a user should be activated.

## Testing

Mock `DatabaseClient`. Assert the query text, parameters, and row mapping behavior:

```ts
describe('PostgresUserRepository', () => {
  it('returns null when user not found', async () => {
    const db: DatabaseClient = { query: vi.fn().mockResolvedValue([]) };
    const repo = new PostgresUserRepository(db);

    const result = await repo.getById('missing-id');

    expect(result).toBeNull();
  });

  it('maps row to domain type', async () => {
    const row = { id: '1', email: 'a@example.com', status: 'pending' };
    const db: DatabaseClient = { query: vi.fn().mockResolvedValue([row]) };
    const repo = new PostgresUserRepository(db);

    const result = await repo.getById('1');

    expect(result).toEqual({ id: '1', email: 'a@example.com', status: 'pending' });
  });
});
```

Use a real test database only when the test outcome depends on SQL semantics (e.g., constraint behavior, RETURNING clauses, complex joins).

## Interface vs concrete class

Define a `UserRepository` interface when the repository is consumed by services or handlers that need isolated tests. This is almost always the right call. The interface makes mock injection explicit and keeps service tests free of database concerns.

## Upsert

Writing an insert-or-update? Read [references/upsert.md](references/upsert.md) — the SELECT + conditional INSERT/UPDATE pattern is non-atomic and has a well-known correct alternative.
