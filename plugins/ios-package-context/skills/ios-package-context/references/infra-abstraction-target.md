# Infra abstraction target CLAUDE.md

The abstraction target of an infrastructure package (`Foo` in the `Foo`/`FooLive` pair):
protocols plus plain request/response models, no concrete implementation. Consumers
compile only against this target.

## What it contains

- **Blurb** — "abstraction target (`Foo`): protocols and plain models for <capability>."
- **File structure** — the protocol groups / model clusters, by folder.
- **Naming** — protocol names, where the `Live` counterpart lives (`FooLive`).
- **Gotchas** — what must NOT appear here (no networking, no concrete deps, no SwiftUI);
  the import rule (consumers import `Foo`, never `FooLive`); `@Mocked` defaults if used.
- **Cross-link** to `swift-modularization` (infra abstraction target) and the relevant
  capability skill (e.g. `ios-network-layer`).

## Skeleton

```markdown
# Foo target (abstraction)

Abstraction target (`Foo`): protocols and plain request/response models for <capability>.

## File structure

- `Models/` — plain `Codable & Hashable & Sendable` value types.
- `FooProtocol.swift` — the `@Mocked` protocol consumers inject.

## Rules

- No networking, no persistence, no SwiftUI — those belong in `FooLive`.
- Consumers import `Foo` only; never `FooLive` (that is the composition root's job).
- `@Mocked` is applied to the protocol so test targets inject a `FooMock`.

See the swift-modularization skill (infra abstraction target).
```

## Good example

A real abstraction file names each model with its conformances in one line
(`TokenPair.swift — { token, refreshToken }, Codable & Hashable & Sendable`), names the
protocol and where its Live impl lives, and lists the no-X rules. It does **not** explain
how refresh works — that contract's mechanics live in the code and the skill.

## Gotchas worth surfacing

- The `Foo` / `FooLive` naming and the import-only-the-abstraction rule.
- Apple framework name collisions (don't name a target `Network`).
- Where the concrete impl lives, by target name — so the reader can jump there.

## Anti-pattern

Documenting how the protocol's methods behave. The abstraction declares a contract; the
behaviour is in `FooLive`. Name the protocol; don't narrate it.
