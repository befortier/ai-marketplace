# Domain Data target CLAUDE.md

The `<Domain>Data` target: the domain's shared core — domain models, mappers, network
services (on the `Networking` abstraction), and stores. No SwiftUI, no view logic.

## What it contains

- **Blurb** — "Data target: domain models + data access for <domain>."
- **File structure** — the standard folders: `Model/`, `Mapper/`, `Network/`, `Store/`,
  `Repository/`, `Container/` (include only those present).
- **Naming** — `DefaultXxx` for repositories, `XxxMapper` for mappers, etc.
- **Gotchas** — the no-SwiftUI / no-view-business-logic boundary; proto/wire edge if this
  is the wire→domain mapping seam.
- **Cross-link** to `ios-data-layer` and `swift-modularization`.

## Skeleton

```markdown
# FooData target (data)

Data target: domain models + data access for the Foo domain. Folders: `Model/`,
`Mapper/`, `Network/`, `Store/`, `Repository/`.

- IMPORTANT: no SwiftUI here, and no networking/business logic that belongs in a view
  or composer.
- Wire→domain mapping is the proto edge — keep wire types out of the rest of the app.

See the ios-data-layer skill for rationale + structure.
```

## Good example

The shipped `FooData` file is ~5 lines: the blurb, the folder list, the no-SwiftUI
`IMPORTANT`, and the skill link. That is the target — resist adding model field
descriptions or mapper internals.

## Gotchas worth surfacing

- The proto/wire boundary: this target maps wire DTOs to domain models; wire types must
  not leak upward.
- `AsyncStream` store lifetime if a store is scope-lived.
- The `Default`-prefix repository naming.

## Anti-pattern

Listing every model's fields or narrating a mapper's transform. The model files say what
the fields are; the skill says how mappers are shaped. The `CLAUDE.md` only names the
folders and the boundary rule.
