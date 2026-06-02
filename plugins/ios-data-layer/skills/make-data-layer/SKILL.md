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
- Repository: orchestration + error propagation tests (see repository.md)

## File Organization

A data-layer package uses one top-level folder per responsibility. Each protocol and its
default/Live implementation live in **separate files** — never combined in one file.

```
<Domain>Data/
├── Model/                             # Domain models (Sendable + Hashable structs)
│   ├── <Domain>.swift
│   └── <Domain>+<SubType>.swift      (extensions for nested types)
├── Mapper/                            # DTO → Domain Model translation
│   ├── <Domain>Mapping.swift          (protocol)
│   ├── <Domain>Mapper.swift           (implementation)
│   └── <Domain>MappingError.swift
├── Network/                           # API service + request descriptors
│   ├── <Domain>Service.swift          (protocol)
│   ├── Remote<Domain>Service.swift    (implementation)
│   └── Get<Resource>Descriptor.swift
│   └── <Domain>DTO.swift             (wire DTO, lives alongside its service)
├── Store/                             # In-memory state (AsyncStream actor)
│   ├── <Domain>Store.swift            (protocol)
│   └── InMemory<Domain>Store.swift    (actor implementation)
├── Repository/                        # Orchestration: service → mapper → store
│   ├── <Domain>Repository.swift       (protocol)
│   └── Default<Domain>Repository.swift
├── Container/                         # Scope-lived state holder (see ios-container skill)
│   └── <Domain>Container.swift        (Sendable struct, Mutex-guarded mutable state)
└── Tests/
    ├── <Domain>MapperTests.swift
    ├── Remote<Domain>ServiceTests.swift
    ├── Default<Domain>RepositoryTests.swift
    ├── InMemory<Domain>StoreTests.swift
    └── Stubs/
        ├── <Domain>+Stub.swift
        └── <Domain>DTO+Stub.swift
```

### Folder responsibilities

| Folder | Holds | Key rule |
|---|---|---|
| `Model/` | Domain model structs | `Sendable + Hashable`; no UI, no DTOs |
| `Mapper/` | Protocol + impl + error type | One file per type; never combine protocol + impl |
| `Network/` | Protocol + impl + descriptors + DTO | Protocol and `Remote` impl in separate files |
| `Store/` | Protocol + actor impl | Protocol and `InMemory` impl in separate files |
| `Repository/` | Protocol + default impl | Protocol and `Default` impl in separate files |
| `Container/` | Scope-lived state holder | Created on auth scope open; torn down with scope |

> **Protocol/impl separation rule:** every protocol (`<Domain>Service`, `<Domain>Store`, etc.)
> lives in its own file. Its default or Live implementation lives in a second, separate file.
> Never put a protocol and its conforming type in the same file.

## Guidelines

- **Scan the package first.** Match existing HTTP client types, folder structure, and naming.
- **Don't over-generate.** If the feature only reads data (no persistence), skip the store and have the repository return directly.
- **One service per domain.** Don't add methods to unrelated services.
- **Protocols for everything testable.** Every dependency gets a `@Mocked` protocol.
