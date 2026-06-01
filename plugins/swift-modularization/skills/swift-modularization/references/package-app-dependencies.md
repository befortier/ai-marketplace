# Maintaining the app target's Package.swift

The app is the executable target and the composition root: it depends on the area
packages and wires them together. It is the **only** place that pulls the `…Live`
products.

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MyApp",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.executable(name: "MyApp", targets: ["MyApp"])],
    dependencies: [
        .package(path: "App/Packages/Networking"),
        .package(path: "App/Packages/Websockets"),
        .package(path: "App/Packages/Connections"),
        .package(path: "App/Packages/Chat"),
    ],
    targets: [
        .executableTarget(
            name: "MyApp",
            dependencies: [
                .product(name: "NetworkingLive", package: "Networking"),
                .product(name: "WebsocketsLive", package: "Websockets"),
                .product(name: "ConnectionsView", package: "Connections"),
                .product(name: "ChatView", package: "Chat"),
            ],
            path: "App",
            exclude: ["Packages"]
        )
    ]
)
```

- Local packages are referenced by path under a `Packages/` directory; pull specific
  products with `.product(name:package:)`.
- The app target is the only place that depends on `…Live` products.
- Exclude the `Packages/` directory from the app target's own sources.
- Add a dependency here whenever a new area package needs to be wired into the app.

In practice the app pulls only one product directly — a single `AppComposition` area
package that re-exports the wired graph — and `AppComposition` is the one place that
depends on every `…Live` product. See [composition-root.md](composition-root.md).
