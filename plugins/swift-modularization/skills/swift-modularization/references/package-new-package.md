# Authoring a package's Package.swift

A package covers one **area** (an infrastructure capability or a product domain) and
exposes its modules as **multiple library products + targets**, declaring only the
dependencies it actually uses. One product per public target; name each after its module.

## Infrastructure area (abstraction + Live)

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Networking",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "Networking", targets: ["Networking"]),
        .library(name: "NetworkingLive", targets: ["NetworkingLive"]),
    ],
    targets: [
        .target(name: "Networking"),
        .target(name: "NetworkingLive", dependencies: ["Networking"]),
        .testTarget(name: "NetworkingLiveTests", dependencies: ["NetworkingLive"]),
    ]
)
```

## Domain area (Data / UI / per-experience)

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Chat",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "ChatData", targets: ["ChatData"]),
        .library(name: "ChatUI",   targets: ["ChatUI"]),
        .library(name: "ChatView", targets: ["ChatView"]),
    ],
    dependencies: [
        .package(path: "../Networking"),
    ],
    targets: [
        .target(name: "ChatData", dependencies: [.product(name: "Networking", package: "Networking")]),
        .target(name: "ChatUI",   dependencies: ["ChatData"]),
        .target(name: "ChatView", dependencies: ["ChatUI", "ChatData"]),
    ]
)
```

- **One package per area**, named for the area; one `.library` product per public target.
- Declare only direct dependencies. For anything injected at the composition root, depend
  on the **abstraction** product (`Networking`), never on `…Live`.
- Cross-package deps reference the other area package by path and pull a specific product
  via `.product(name:package:)`.
- Add `resources:` only when a target ships assets.
