---
name: make-data-layer
description: iOS data layer reference — DTO, domain model, mapper, network service, AsyncStream store, and repository conventions. Loaded by the make-data-layer agent as its knowledge base.
---

# iOS Data Layer Reference

Architecture conventions for building data layers in iOS feature packages. The `make-data-layer` agent uses these references interactively — each step loads the relevant file on demand.

## Architecture

```
Network (API)
  → Remote<Domain>Service        (async throws, returns DTO)
    → <Domain>DTO                (Decodable + Sendable + Hashable)
      → <Domain>Mapper           (DTO → Domain Model)
        → <Domain> (model)       (Sendable + Hashable)
          → Default<Domain>Repository  (coordinates service + mapper + store)
            → InMemory<Domain>Store    (actor, AsyncStream)
              → Consumer
```

## Step 1: Define the DTO

Read [references/dto.md](references/dto.md) for the full pattern.

Key rules:
- `Decodable + Sendable + Hashable` struct
- **No enums** — use `String` for type fields; convert in mapper
- Flat structure matching API response shape
- `DTO/` folder — one file per type
- Naming: `<Domain>DTO`, `<Domain>ResponseDTO`

## Step 2: Define the Domain Model

Read [references/domain-model.md](references/domain-model.md) for the full pattern.

Key rules:
- `Sendable + Hashable` struct, `Identifiable` when natural ID exists
- Can use enums with associated values (unlike DTOs)
- Normalized data only — no UI decisions
- Naming: plain domain name (`PointPassLanding`, `Quest`)

## Step 3: Create the Mapper

Read [references/mapper.md](references/mapper.md) for the full pattern.

Key rules:
- Sendable struct with `@Mocked` protocol
- Protocol: `<Domain>Mapping` / Implementation: `<Domain>Mapper`
- String→enum conversion happens here
- Typed error enum: `<Domain>MappingError`

## Step 4: Create the Network Service

Read [references/network-service.md](references/network-service.md) for the full pattern.

Key rules:
- Sendable struct, stateless
- Protocol: `<Domain>Service` / Implementation: `Remote<Domain>Service`
- Returns DTO, not domain model
- Uses Descriptor pattern for requests

## Step 5: Create the Store

Read [references/store.md](references/store.md) for the full pattern.

Key rules:
- Protocol: `<Domain>Store` / Implementation: `InMemory<Domain>Store`
- Actor-based with `AsyncStream` continuations
- Stores domain models, not DTOs
- Operations: `upsert`, `stream`, `removeAll`
- Fallible (persistent) stores throw from stream getters — never swallow open errors
- Record ↔ model conversion for persistent stores: read [references/record-mapping.md](references/record-mapping.md)

## Step 6: Create the Repository

Read [references/repository.md](references/repository.md) for the full pattern.

Key rules:
- Protocol: `<Domain>Repository` / Implementation: `Default<Domain>Repository`
- Coordinates: fetch (service) → map (mapper) → persist (store)
- Thin orchestration — no business logic
- Exposes store's stream for reactive reads

## Step 7: Generate Tests

Each reference file above contains a **Testing** section with layer-specific test patterns. Generate tests alongside each component:
- DTO: deserialization tests (see dto.md)
- Domain Model: stub factories (see domain-model.md)
- Mapper: transformation + fallback + terminal error tests (see mapper.md)
- Service: descriptor + client call verification (see network-service.md)
- Store: stream emission + replay tests (see store.md)
- Record mapping: round-trip + unknown-kind tests (see record-mapping.md)
- Repository: orchestration + error propagation tests (see repository.md)

## File Organization

```
<Domain>Data/
├── Models/
│   ├── <Domain>.swift
│   └── <Domain>+<SubType>.swift      (extensions for nested types)
├── DTO/
│   ├── <Domain>DTO.swift              (one file per type)
│   └── <Nested>DTO.swift
├── Wire/
│   ├── <Domain>Mapper.swift           (protocol + implementation)
│   └── <Domain>MappingError.swift
├── Network/
│   ├── <Domain>Service.swift          (protocol)
│   ├── Remote<Domain>Service.swift    (implementation)
│   └── Get<Resource>Descriptor.swift
├── Store/
│   ├── <Domain>Store.swift            (protocol)
│   └── InMemory<Domain>Store.swift    (actor implementation)
├── Repository/
│   ├── <Domain>Repository.swift       (protocol)
│   └── Default<Domain>Repository.swift
└── Tests/
    ├── <Domain>MapperTests.swift
    ├── Remote<Domain>ServiceTests.swift
    ├── Default<Domain>RepositoryTests.swift
    ├── InMemory<Domain>StoreTests.swift
    └── Stubs/
        ├── <Domain>+Stub.swift
        └── <Domain>DTO+Stub.swift
```

## Guidelines

- **Scan the package first.** Match existing HTTP client types, folder structure, and naming.
- **Don't over-generate.** If the feature only reads data (no persistence), skip the store and have the repository return directly.
- **One service per domain.** Don't add methods to unrelated services.
- **Protocols for everything testable.** Every dependency gets a `@Mocked` protocol.
- **Docs are one or two lines.** Doc comments state intent — no narration, no restating the signature.
