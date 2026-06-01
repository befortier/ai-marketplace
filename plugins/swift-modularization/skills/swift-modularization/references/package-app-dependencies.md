# Maintaining the app target's Package.swift

The app is the executable target and the composition root: it depends on the feature and
infrastructure packages (including the `…Live` implementations) and wires them together.

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MyApp",
    platforms: [.iOS(.v17)],
    products: [.executable(name: "MyApp", targets: ["MyApp"])],
    dependencies: [
        .package(path: "App/Packages/Network"),
        .package(path: "App/Packages/Websockets"),
        .package(path: "App/Packages/Connections"),
        .package(path: "App/Packages/Chat")
    ],
    targets: [
        .executableTarget(
            name: "MyApp",
            dependencies: ["Network", "Websockets", "Connections", "Chat"],
            path: "App",
            exclude: ["Packages"]
        )
    ]
)
```

- Local packages are referenced by path under a `Packages/` directory.
- The app target is the only place that depends on `…Live` packages.
- Exclude the `Packages/` directory from the app target's own sources.
- Add a dependency here whenever a new package needs to be wired into the app.
