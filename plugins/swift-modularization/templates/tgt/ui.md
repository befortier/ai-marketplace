UI target: small, reusable presentational SwiftUI components for this domain.

- Presentational only — no networking, no business logic, no persistence.
- One folder per subview once it grows past a single file.
- Render value types from the Data target; take inputs/closures in, send events out.
- IMPORTANT: never reach for a Store, Repository, or network service here — those belong in the View target's ViewModel.

See the swift-modularization skill (ui target) and the ios-view-architecture skill for rationale + structure.
