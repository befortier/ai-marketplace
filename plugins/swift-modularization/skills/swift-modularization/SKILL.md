---
name: swift-modularization
description: Conventions for structuring a Swift app into SwiftPM packages — infrastructure vs domain clusters, protocol/Live splits, dependency direction, thin composition root. Use when organizing modules, adding a feature, or deciding where code lives.
---

# Swift Modularization

## Overview

Structure a Swift app as small SwiftPM packages with a clear dependency direction
and a **thin app target** that only wires things together. There are exactly **two
package kinds** — infrastructure and domain — and everything testable is a protocol
with a `…Live` implementation injected at the composition root (pairs with
`swift-mocking`: a protocol gets an `@Mocked` mock for free).

Guiding rule: **start combined; split only when testability or DI actually demands
it.** Don't pre-shard.

## Quick Start

When adding code, first decide which kind it is:

- **Cross-cutting + domain-agnostic** (networking, sockets, storage, generated wire
  models)? → an **infrastructure** package. See [references/infrastructure-packages.md](references/infrastructure-packages.md).
- **Tied to a product domain** (its models, services, components, or a screen)? → a
  package in that **domain cluster**. See [references/domain-clusters.md](references/domain-clusters.md).
- **Wiring concrete implementations together** (app startup)? → the **composition
  root** (the app target). See [references/composition-root.md](references/composition-root.md).

## Two package kinds

### 1. Infrastructure packages

Cross-cutting technical capability, provider/domain-agnostic. **Optionally** split an
abstraction package from its implementation so consumers compile against protocols
and the concrete impl is injected only at the root:

- `Network` (protocols + request/response models) → `NetworkLive` (URLSession)
- `Websockets` (protocols) → `WebsocketsLive`
- `Bridge` / execution engine — **infrastructure**; abstract it and let domains
  implement against the abstraction. Single-package vs protocol/`Live` split is
  **TBD, decided when it's built.**
- `AssistantProto` — generated SwiftProtobuf wire models
- `ProjectFoundation` — Keychain / Core Data stores, `Sendable` utilities

Start a capability as one package; shard into `X` / `XLive` only when a real test or
DI need appears.

### 2. Domain packages (a cluster, never a monolith)

A domain is a **cluster of small packages** sliced by concern:

- `<Domain>Data` — domain models, network services, data stores (the domain's core)
- `<Domain>UI` — small reusable components for that domain
- `<Domain><Experience>` — **one package per screen/experience**
  (`ConnectionsList`, `ConnectionReconnect`, `ChatConversation`). A new experience is
  a **new package**, not a fatter existing one.

## Dependency direction

```
<Domain><Experience>  →  <Domain>UI  →  <Domain>Data  →  infra ABSTRACTIONS
                                                          (never …Live)
```

- Domains depend on infrastructure **abstractions**, never on `…Live`.
- Domains avoid reaching into other domains' internals.
- **Only the app target** depends on `…Live` packages and wires them.

## Composition root (the app target)

The app target is thin: a set of **Composer** enums that build the object graph,
injecting `Live` implementations and `any Protocol` values (the `res-bot-ios`
pattern). It contains wiring, not logic. Details + example:
[references/composition-root.md](references/composition-root.md).

## Naming

- Protocol gets the bare name; implementations are suffixed:
  `…Live` / `Remote…` / `InMemory…` / `Default…`.
- Anything testable is a protocol → gets an `@Mocked` mock (see `swift-mocking`),
  injected in tests; the `…Live`/`Default` impl is injected in production.

## Illustrative package map (target shape, not built yet)

- **Infra:** `Network`/`NetworkLive`, `Websockets`/`WebsocketsLive`, `Bridge`,
  `AssistantProto`, `ProjectFoundation`
- **Connections domain:** `ConnectionsData` · `ConnectionsUI` · `ConnectionsList` ·
  `ConnectionReconnect`
- **Chat domain:** `ChatData` · `ChatUI` · `ChatConversation`

## Common Mistakes

- **A domain monolith.** Split into `…Data` / `…UI` / `…<Experience>`; new screen =
  new package.
- **A domain depending on `…Live`.** Depend on the abstraction; only the app wires `Live`.
- **Pre-sharding `X`/`XLive`** before any test/DI need. Start combined.
- **Logic in the app target.** It's a composition root — wiring only.
- **Cross-domain reach-ins.** Go through the other domain's public surface, or lift the
  shared piece into infrastructure.

## Reference Files

| File | When to read |
|------|-------------|
| [references/infrastructure-packages.md](references/infrastructure-packages.md) | Deciding whether/when to split a capability into `X` + `XLive`; what counts as infrastructure |
| [references/domain-clusters.md](references/domain-clusters.md) | Slicing a domain into Data/UI/Experience packages |
| [references/composition-root.md](references/composition-root.md) | The thin app target + Composer wiring pattern |
