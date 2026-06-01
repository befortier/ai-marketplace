# Domain clusters

A domain (Connections, Chat, Reservation, Venues, …) is a **cluster of small
packages**, never one fat package. Slice it by concern:

## The three slices

### `<Domain>Data`
The domain's shared core: domain models, network services (built on the `Network`
abstraction), and data stores (Keychain / Core Data, built on `ProjectFoundation`).
Everything else in the domain depends on this.

### `<Domain>UI`
Small, reusable SwiftUI components for the domain — cards, rows, badges. No screen
owns these; multiple experiences reuse them. Depends on `<Domain>Data` for the value
types it renders.

### `<Domain><Experience>` — one package per screen
Each screen/experience is its **own package**: `ConnectionsList`,
`ConnectionReconnect`, `ChatConversation`. It contains that screen's View, ViewModel,
ViewState, and mapper.

**A new experience is a new package** — never grow an existing experience package to
host a second screen.

## Dependency direction (within and out of the cluster)

```
<Domain><Experience>  →  <Domain>UI  →  <Domain>Data  →  infra ABSTRACTIONS
                                                          (never …Live)
```

- An experience depends on its domain's UI and Data, plus infrastructure
  **abstractions** (`Network`, `Websockets`, …) — never on `…Live`.
- Domains do **not** reach into other domains' internals. If two domains need the same
  thing, either go through the other domain's public surface, or lift the shared piece
  down into an **infrastructure** package.

## Naming inside a domain

- Protocols take the bare name (`UserRepository`, `ConnectionStore`).
- Implementations are suffixed: `…Live` (real), `Remote…` (network-backed),
  `InMemory…` (test/preview), `Default…`.
- Every protocol that's exercised in tests gets an `@Mocked` mock — see the
  `swift-mocking` skill.

## Reference project mapping

In `res-bot-ios`, domains like `Reservation`, `Venues`, `User`, `Authentication`, and
`Onboarding` are each their own SwiftPM package under `ResyPro/Packages/…`, with view
+ composition code organized by feature. The same slicing applies here, just named
per the app's domains (Connections, Chat).
