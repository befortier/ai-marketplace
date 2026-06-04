# Infra Live target CLAUDE.md

The implementation target of an infrastructure package (`FooLive`): the concrete types
that conform to `Foo`'s protocols. Added at the composition root only.

## What it contains

- **Blurb** — "Live target (`FooLive`): concrete <capability> implementations."
- **File structure** — the impl folders (`Client/`, `Store/`, `Repository/`…), by name.
- **Naming** — the concrete type names and which abstraction protocol each conforms to.
- **Gotchas** — the must-not-regress invariants and any `@unchecked Sendable` justification
  *pointer* (the source carries the full justification); thread-safety expectations.
- **Cross-link** to the capability skill and `swift-modularization` (infra Live target).

## Skeleton

```markdown
# FooLive target (live)

Live target (`FooLive`): concrete implementations of `Foo`'s protocols for <capability>.

## File structure

- `Client/` — the concrete client and its policy stack.
- `Store/` — concrete stores conforming to the `Foo` store protocols.

## Rules

- Only the composition root depends on `FooLive`; nothing else imports it.
- <invariant that must not regress>.

See the ios-<capability> skill and the swift-modularization skill (infra Live target).
```

## Good example

Name each concrete type and the protocol it satisfies (`CoreDataUserStore — conforms to
`UserStore`; drop-in for `InMemoryUserStore`"). State invariants as rules
("streams are scope-lived: finish them only in `deinit`, never in `removeAll()`").

## Gotchas worth surfacing

- Which composition root must build/inject it, and any required setup (e.g. entity
  registration, `automaticallyMergesChangesFromParent`).
- Concurrency invariants: what guards mutable state, what must be called at-most-once.
- "Do not regress <past de-X>" if a prior cleanup must stay clean.

## Anti-pattern

A control-flow walk-through or ASCII data-flow diagram of a contract (`A → B → C →
callback → view model`). That is the single most common drift source. State that the
contract *exists* and name its entry point and consumer; let the code show the flow.
Likewise drop origin/history prose ("lifted from resy", "the E3.T1 addition is…").
