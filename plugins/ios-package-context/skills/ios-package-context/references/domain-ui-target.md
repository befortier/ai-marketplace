# Domain UI target CLAUDE.md

The `<Domain>UI` target: small, reusable, **presentational** SwiftUI components for the
domain. Stateless — data in, no fetching, no business logic.

## What it contains

- **Blurb** — "UI target: reusable presentational SwiftUI components for <domain>."
- **File structure** — one folder per component once it grows past a single file.
- **Naming** — `…View` suffix; component-per-folder layout.
- **Gotchas** — the stateless boundary: no Store/Repository/network service here; those
  belong in the View target's ViewModel.
- **Cross-link** to `ios-view-architecture` and `swift-modularization`.

## Skeleton

```markdown
# FooUI target (ui)

UI target: small, reusable presentational SwiftUI components for the Foo domain.

- Presentational only — no networking, no business logic, no persistence.
- One folder per subview once it grows past a single file.
- IMPORTANT: avoid reaching for a Store, Repository, or network service here — those
  belong in the View target's ViewModel. These are stateless components.

See the ios-view-architecture skill for rationale + structure.
```

## Good example

The shipped `FooUI` file is ~6 lines: blurb, the one-folder-per-subview rule, the
stateless `IMPORTANT`, and the skill link.

## Gotchas worth surfacing

- The stateless rule — the single most useful thing to state here.
- That these components render value types from `FooData`, not domain services.
- Where reusable design atoms live if there is a shared `DesignSystem` package (link it).

## Anti-pattern

Documenting each component's layout or styling. SwiftUI source is self-describing; the
design tokens live in the design system. The `CLAUDE.md` only states the stateless
boundary and the folder convention.
