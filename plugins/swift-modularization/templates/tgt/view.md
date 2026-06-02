View target: a feature/screen. Composes this domain's UI + Data behind a ViewModel.

- Files: `View`, `ViewModel`, `ViewState`, `NavigationRequest`, `Mapper/` (protocol + `Default*` in separate files).
- ViewModel owns state and handles actions; map domain → `ViewState`, modelling loading/failure states.
- Defer navigation upward: expose a `NavigationRequest`; the composer decides where it goes.
- IMPORTANT: no composition or dependency-graph wiring here — the ViewModel receives its dependencies, it does not build them.

See the swift-modularization skill (view target) and the ios-view-architecture skill for rationale + structure.
