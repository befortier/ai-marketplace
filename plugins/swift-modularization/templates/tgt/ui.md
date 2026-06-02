UI target: small, reusable presentational SwiftUI components for this domain.

- Presentational only — no networking, no business logic, no persistence.
- One folder per subview once it grows past a single file.
- IMPORTANT: Avoid reaching for a Store, Repository, or network service here — those belong in the View target's ViewModel. These should be stateless components.

See ios-view-architecture skill for rationale + structure.
