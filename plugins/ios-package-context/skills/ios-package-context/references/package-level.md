# Package-level CLAUDE.md

The file at `Packages/Foo/CLAUDE.md`, one level above the targets. It orients an agent to
the package as a whole and hands them off to the right target file. Keep it short — the
targets carry the working detail.

## What it contains

- **Blurb** — package kind (infra or domain) and what area it owns, in one line.
- **Targets + direction** — the targets it exposes and which way dependencies point.
- **Hand-off** — "each target owns its own `CLAUDE.md`; read the one for the target you're
  editing."
- **A few package-wide gotchas** — the rules that apply across all its targets (dependency
  direction, no cross-domain reach, no composition here).
- **Cross-link** to `swift-modularization`.

Do not describe any target's internals here — that is the target file's job.

## Skeleton

```markdown
# Foo package (domain)

Domain package. Slices into targets: `FooData` → `FooUI` → `FooView`.

- Each target owns its own `CLAUDE.md`; read the one for the target you're editing.
- Targets depend downward only; never depend on another domain's internals — go
  through its public product.
- Depend on infra **abstractions** (`Bar`), never `BarLive`.
- IMPORTANT: composition does not live here. Packages expose initializers and defer
  wiring + navigation upward.

See the swift-modularization skill (domain package) for boundary rationale + structure.
```

## Good example (domain)

A real domain package file is ~10 lines: the slice header, the dependency-direction
bullets, the "no composition here" rule, and the skill link. That is the whole job.

## Gotchas worth surfacing

- The target slice order (`Data → UI → View`) and the abstraction-not-Live rule.
- "Composition defers upward" — packages never wire themselves.
- For an infra package, name the abstraction/`Live` target pair and note that consumers
  compile only against the abstraction.

## Anti-pattern

Listing every file in every target at the package level. That detail belongs in each
target's own `CLAUDE.md`; the package file only routes.
