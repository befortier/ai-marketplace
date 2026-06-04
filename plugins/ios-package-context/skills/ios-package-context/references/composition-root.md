# Composition-root package CLAUDE.md

The session-gated composition-root package (e.g. `AppComposition`): the only package that
depends on every `…Live` product and wires the object graph. Feature packages stay
ignorant of how they are wired.

This package's `CLAUDE.md` is allowed to be the **largest** in the app, because its job —
the scope/container/composer wiring — is genuinely project-specific and not fully captured
by a generic skill. But it still names structures and rules, not behaviour walk-throughs.

## What it contains

- **Blurb** — "the session-gated composition root: the only package that depends on every
  `…Live` product and wires the graph."
- **File structure** — `Scopes/`, `Bootstrap/`, per-feature composer folders, by name.
- **Naming** — `…Composer`, `…Scope`, `…Container`.
- **The three roles** — name (not re-teach) Composer / Scope / Container and what each
  holds; defer the *how* to `ios-composition` and `ios-container`.
- **Gotchas** — composition lives ONLY here; scopes are `Sendable`, no functions, no
  mutable state; where each `…Live` is added.
- **Cross-link** to `ios-composition`, `ios-container`, `swift-modularization`.

## Skeleton

```markdown
# AppComposition

The session-gated composition root: the only package that depends on every `…Live`
product and wires the object graph. Feature packages stay ignorant of how they are wired.

## Cross-links

- `ios-composition` — composers, the session gate, debug-vs-release graphs.
- `ios-container` — the `Sendable` holder of a domain's scope-lived in-memory state.

## File structure

- `Bootstrap/` — app come-up and root view.
- `Scopes/` — `AuthenticatedScope`, signed-out scope.
- `<Feature>/<Feature>Composer.swift` — per-feature wiring + navigation routing.

## Rules

- Composition lives ONLY here — never in feature packages.
- A scope is `Sendable`, has no functions, and no mutable state (all `let`, built once).
- `…Live` products are added here and nowhere else.

See the ios-composition and ios-container skills.
```

## Good example

The shipped root file names the scopes, lists the composer folders, and cross-links the
two composition skills before stating the hard rules (scope is Sendable / no functions /
no mutable state). It points the reader at the skills for the *why*.

## Gotchas worth surfacing

- "Composition lives only here" — the load-bearing invariant.
- The scope hard rules (Sendable, no functions, no mutable state).
- Which navigation requests this root routes (the seam between features and the app).

## Anti-pattern

Re-teaching what a composer or container *is* from scratch. Those are the `ios-composition`
and `ios-container` skills' jobs. This file names the concrete scopes/composers/containers
in *this* app and links the skills for the pattern.
