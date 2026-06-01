# Domain clusters

A domain is **one package** exposing a cluster of small **targets**, never one fat
target and never a package per module. Slice it by concern; each slice is a target +
`.library` product in the same package.

## The three slices

### `<Domain>Data`
The domain's shared core: domain models, network services (built on the `Networking`
abstraction), and data stores.

### `<Domain>UI`
Small, reusable SwiftUI components for the domain. Depends on `<Domain>Data` for the
value types it renders.

### `<Domain><Experience>` — one target per screen
Each screen/experience is its own target (its View, ViewModel, ViewState, mapper). A new
experience is a new target in the domain package, not a fatter existing one.

```swift
// Chat package
products: [
    .library(name: "ChatData", targets: ["ChatData"]),
    .library(name: "ChatUI",   targets: ["ChatUI"]),
    .library(name: "ChatView", targets: ["ChatView"]),
],
targets: [
    .target(name: "ChatData", dependencies: [.product(name: "Networking", package: "Networking")]),
    .target(name: "ChatUI",   dependencies: ["ChatData"]),
    .target(name: "ChatView", dependencies: ["ChatUI", "ChatData"]),
]
```

## Dependency direction

```
<Domain><Experience>  →  <Domain>UI  →  <Domain>Data  →  infra ABSTRACTIONS
                                                          (never …Live)
```

- An experience target depends on its domain's UI and Data targets, plus infrastructure
  abstraction products — never on `…Live`.
- Domains do not reach into other domains' internals. If two domains need the same thing,
  go through the other domain's public product, or lift the shared piece into an
  infrastructure package.
