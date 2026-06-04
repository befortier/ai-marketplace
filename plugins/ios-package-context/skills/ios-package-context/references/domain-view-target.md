# Domain View / Experience target CLAUDE.md

A `<Domain><Experience>` (View) target: one feature/screen — its View, ViewModel,
ViewState, NavigationRequest, and Mapper. Composes the domain's UI + Data behind a
ViewModel and defers navigation upward.

## What it contains

- **Blurb** — "View target: the <experience> feature/screen. Composes Foo's UI + Data."
- **File structure** — `View`, `ViewModel`, `ViewState`, `NavigationRequest`, `Mapper/`
  (protocol + `Default*` split). For a multi-screen engine, the `Views/{Controls,
  Components,Phases}` tree (one entity per file).
- **Naming** — `…View` / `…ViewModel` / `…ViewState` / `…NavigationRequest`; one entity
  per file; ViewStates + Actions are `Sendable, Hashable`.
- **Gotchas** — defer navigation upward (expose `NavigationRequest`, never self-navigate);
  no composition/graph wiring here (the ViewModel *receives* deps); the exit contract.
- **Cross-link** to `ios-view-architecture` and `swift-modularization`.

## Skeleton

```markdown
# FooDetail target (view)

View target: the Foo detail feature/screen. Composes Foo's UI + Data behind a ViewModel.

## File structure

- `View`, `ViewModel`, `ViewState`, `NavigationRequest`, `Mapper/` (protocol + `Default*`).

## Rules

- ViewModel owns state and handles actions; map domain → `ViewState`; model
  loading/failure states.
- Defer navigation upward: expose a `NavigationRequest`; the composer decides where it goes.
- IMPORTANT: no composition or dependency-graph wiring here — the ViewModel receives its
  dependencies, it does not build them.

See the ios-view-architecture skill for rationale + structure.
```

## Good example

The shipped View-target file is ~7 lines: blurb, the file-role list, the
defer-navigation rule, the no-composition `IMPORTANT`, and the skill link.

## Gotchas worth surfacing

- The exit contract: which `NavigationRequest` cases this screen bubbles.
- `Sendable, Hashable` on ViewState/Action (an easy regression to `Equatable`-only).
- For an engine/multi-screen target: the `Views/` folder layout and one-entity-per-file —
  but point at the `ios-view-architecture` engine variant for the pattern, don't restate it.

## Anti-pattern

Dense engine-pattern prose (one VM / one state enum / content-enum walk-through) inside
the `CLAUDE.md`. That pattern is the `ios-view-architecture` skill's job — link it. The
`CLAUDE.md` names the final file structure and the navigation/composition boundaries only.
