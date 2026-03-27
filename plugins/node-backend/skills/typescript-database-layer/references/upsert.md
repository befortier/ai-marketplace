# Upsert Pattern

## The problem with SELECT + INSERT/UPDATE

```ts
// ❌ Non-atomic — two round trips, fragile under concurrency
const existing = db.prepare('SELECT id FROM users WHERE google_id = ?').get(googleId);
if (existing) {
  db.prepare('UPDATE users SET ... WHERE google_id = ?').run(...);
  return existing.id;
}
const id = crypto.randomUUID();
db.prepare('INSERT INTO users ...').run(id, ...);
return id;
```

This is non-atomic and makes two round-trips. Use the database's native upsert instead.

## SQLite (better-sqlite3)

Use `INSERT ... ON CONFLICT DO UPDATE ... RETURNING id` to insert-or-update in one atomic statement and get the persisted id back regardless of which branch ran:

```ts
upsertUser(googleId: string, email: string, ...): string {
  const newId = crypto.randomUUID();

  const row = this.db.prepare(`
    INSERT INTO users (id, google_id, email, encrypted_access_token, encrypted_refresh_token)
    VALUES (?, ?, ?, ?, ?)
    ON CONFLICT(google_id) DO UPDATE SET
      encrypted_access_token = excluded.encrypted_access_token,
      encrypted_refresh_token = excluded.encrypted_refresh_token,
      updated_at = datetime('now')
    RETURNING id
  `).get(newId, googleId, email, encryptedAccess, encryptedRefresh) as { id: string };

  return row.id;
}
```

`RETURNING id` gives back the existing id on conflict, or the new id on insert. Requires SQLite 3.35+ (available in better-sqlite3 ≥9).

## PostgreSQL

```ts
const rows = await this.db.query<{ id: string }>(`
  INSERT INTO users (id, email, updated_at)
  VALUES ($1, $2, now())
  ON CONFLICT (email) DO UPDATE SET updated_at = now()
  RETURNING id
`, [newId, email]);
return rows[0].id;
```

## Also: always use explicit column lists in SELECT

```ts
// ❌ Fragile — schema changes break the cast silently
db.prepare('SELECT * FROM users WHERE id = ?').get(id) as UserRow

// ✅ Explicit — cast stays correct as schema evolves
db.prepare('SELECT id, google_id, email, encrypted_access_token, encrypted_refresh_token FROM users WHERE id = ?').get(id) as UserRow
```
