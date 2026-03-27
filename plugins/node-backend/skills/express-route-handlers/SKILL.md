---
name: express-route-handlers
description: Use when writing or reviewing Express route handlers, middleware, or router setup in TypeScript — especially when handling request body parsing, authentication tokens, or external API integration.
---

# Express Route Handlers

Write Express handlers that fail loudly at the boundary, not silently downstream.

## Core principles

- Validate input at the boundary. TypeScript casts on `req.body` provide no runtime safety.
- Validate decoded token payloads. A cast after `jwt.verify` is not a type guard.
- Inject external dependencies (token exchangers, API clients) via constructor or function parameter — never import them directly in a handler.
- Keep handlers thin: validate → call dependency → respond. Business logic belongs in a service.

## Request body validation

Never cast `req.body` directly to a typed shape. The body is `unknown` at runtime.

```ts
// ❌ TypeScript is satisfied but a number slips through at runtime
const { code } = req.body as { code?: string };
if (!code) { ... }  // truthy number passes this guard

// ✅ Validate the type explicitly
const { code } = req.body as Record<string, unknown>;
if (!code || typeof code !== 'string') {
  res.status(400).json({ error: 'Missing or invalid code' });
  return;
}
```

## JWT payload validation

`jwt.verify` returns `string | JwtPayload`. A cast to `{ userId: string }` is not a runtime guarantee.

```ts
// ❌ Unsafe — payload.userId is undefined if the token shape changes
const payload = jwt.verify(token, secret) as { userId: string };
return payload.userId;

// ✅ Validate the decoded shape
const payload = jwt.verify(token, secret);
if (typeof payload !== 'object' || payload === null || typeof (payload as Record<string, unknown>).userId !== 'string') {
  throw new Error('Invalid token payload');
}
return (payload as { userId: string }).userId;
```

## Dependency injection

Make handlers testable by injecting external clients rather than importing them directly.

```ts
// ✅ Injected — testable with vi.fn()
interface AuthRouterDeps {
  users: IUserRepository;
  jwtSecret: string;
  tokenExchanger: (code: string) => Promise<GoogleTokenResult>;
}
export function createAuthRouter(deps: AuthRouterDeps): Router { ... }
```

## Reference files

| File | When to read |
|------|-------------|
| `references/request-validation.md` | Validating nested or complex request bodies |
| `references/jwt-handling.md` | Full JWT middleware pattern with module augmentation |

## Common mistakes

| Mistake | Fix |
|---------|-----|
| `req.body as { field: string }` | Cast to `Record<string, unknown>`, then `typeof` check |
| `jwt.verify(...) as { userId }` | Validate decoded shape before accessing fields |
| Importing API clients directly in handler | Inject via deps parameter |
| Logging raw `err` object | Log `err instanceof Error ? err.message : String(err)` |
