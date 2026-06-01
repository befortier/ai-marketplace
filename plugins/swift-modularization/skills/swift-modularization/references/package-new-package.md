# Authoring a new package's Package.swift

A feature or infrastructure package is a SwiftPM library: one `.library` product and a
target, declaring only the dependencies it actually uses.

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DesignSystem",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "DesignSystem", targets: ["DesignSystem"])
    ],
    dependencies: [
        .package(url: "https://github.com/kean/Nuke.git", from: "12.0.0")
    ],
    targets: [
        .target(
            name: "DesignSystem",
            dependencies: [.product(name: "NukeUI", package: "Nuke")],
            resources: [.process("Resources")]
        )
    ]
)
```

- One product per package; name the product and target after the package.
- Declare only direct dependencies. For anything injected at the composition root,
  depend on the **abstraction** package, never on `…Live`.
- Add `resources:` only when the target ships assets.
