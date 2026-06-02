Data target: domain models + data access for this domain. Folders: `Model/`, `Mapper/`, `Network/`, `Store/`, `Repository/`, `Container/`.

- Models are `Sendable + Hashable` value types — no UI, no DTOs leaking out.
- A protocol and its `Default*`/`Remote*`/`InMemory*` implementation live in SEPARATE files.
- DTOs live in `Network/` alongside the service that uses them.
- Tests in `Tests/<Target>Tests`: cover mappers and repositories; mock collaborators with `@Mocked` (swift-mocking skill).
- IMPORTANT: no SwiftUI here, and no networking/business logic that belongs in a view or composer.

See the swift-modularization skill (data target) and the ios-data-layer skill for rationale + structure.
