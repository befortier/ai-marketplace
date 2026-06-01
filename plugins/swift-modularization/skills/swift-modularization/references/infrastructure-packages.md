# Infrastructure packages

## What counts as infrastructure

A cross-cutting technical capability that is provider- and domain-agnostic — nothing
about it is specific to a product feature. Examples: HTTP networking, web sockets,
persistence/Keychain, shared `Sendable` utilities.

If a type only makes sense within one product domain, it is not infrastructure — it
belongs in that domain's `…Data` target.

## One package per capability

An infrastructure capability is **one package, named for the area**, exposing one or
more library targets — not a separate package per module. The `Networking` package
exposes the `Network` and `NetworkLive` products; the `Persistence` package exposes
`CoreDataStore` and `CoreDataStoreLive`.

## The abstraction / `Live` split

Infrastructure that other code must inject as a dependency is split into two **targets**
in that package: an **abstraction** target (the protocols plus plain request/response
models) and a **`Live`** target (the concrete implementation, depending on the
abstraction). Each is its own `.library` product. Consumers compile only against the
abstraction product; the `Live` product is added only at the composition root, so
nothing else can depend on it and tests substitute a mock.

- `Networking` package → `Network` (protocols + models) + `NetworkLive` (URLSession)
- `Websockets` package → `Websockets` + `WebsocketsLive`

```swift
products: [
    .library(name: "Network", targets: ["Network"]),
    .library(name: "NetworkLive", targets: ["NetworkLive"]),
],
targets: [
    .target(name: "Network"),
    .target(name: "NetworkLive", dependencies: ["Network"]),
]
```

## When to split (and when not to)

The split is driven by injection need. If other code must inject this capability as a
dependency, give it the abstraction + `Live` target pair. If nothing needs to inject it
(e.g. pure `Sendable` utilities), a single target is enough. Add the `Live` target when a
real consumer or test requires injection, not speculatively — but it stays a target in
the same area package either way.
