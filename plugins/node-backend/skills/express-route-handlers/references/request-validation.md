# Request Body Validation

## Why `req.body` casts are unsafe

Express types `req.body` as `any`. TypeScript will accept any cast without complaint, meaning shape mismatches (wrong type, missing field, extra fields) pass compilation and fail silently at runtime.

## Simple field validation

```ts
const { code } = req.body as Record<string, unknown>;
if (!code || typeof code !== 'string') {
  res.status(400).json({ error: 'Missing or invalid code' });
  return;
}
// code is now narrowed to string
```

## Nested / multi-field validation

For more than 2-3 fields, use Zod at the boundary rather than manual `typeof` checks:

```ts
import { z } from 'zod';

const CreateEventBody = z.object({
  title: z.string().min(1),
  start: z.string().datetime(),
  end: z.string().datetime(),
});

router.post('/events', (req, res) => {
  const result = CreateEventBody.safeParse(req.body);
  if (!result.success) {
    res.status(400).json({ error: result.error.flatten() });
    return;
  }
  // result.data is fully typed and validated
});
```

## Pattern: parse-then-pass

Keep Zod schemas at the route layer. Never pass `req.body` directly into a service — parse first, pass the typed result:

```ts
const body = CreateEventBody.parse(req.body);  // throws on invalid
await eventService.create(userId, body);
```
