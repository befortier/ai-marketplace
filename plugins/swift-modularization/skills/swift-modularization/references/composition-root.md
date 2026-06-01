# Composition root (the app target)

The app/executable target is **thin**: it owns no business logic. Its job is to build
the object graph — instantiate `…Live` implementations, inject `any Protocol` values,
and hand the wired graph to the UI. Everything else lives in packages.

## Composer enums

Wiring is expressed as `Composer` enums with a static `make(...)` factory that returns
an abstraction (`any SomeProtocol`). A Composer knows the concrete types; nothing else
does. Real example from the reference project:

```swift
import User
import Bootstrap
import Authentication
import NetworkKit
import Websockets
import ProjectFoundation

enum BootstrapUseCaseComposer {
    static func make(
        modelContainer: any ModelContainerProtocol,
        websocketClient: any WebsocketClient
    ) -> any BootstrapUseCase {
        let tokenStore = TokenStoreFile()
        return BootstrapUseCaseLive(
            tokenStore: tokenStore,
            userRepository: { userSession in
                let bearer = BearerNetworkServiceComposer.make(userSession: userSession)
                let store = UserStoreLive(container: modelContainer)
                return UserRepositoryLive(networkService: bearer, userStore: store)
            }
        )
    }
}
```

Note: the Composer returns `any BootstrapUseCase` (an abstraction), wires `…Live`
types (`BootstrapUseCaseLive`, `UserRepositoryLive`, `UserStoreLive`), and composes
other Composers (`BearerNetworkServiceComposer`). Composers can nest.

## Package layout

Feature packages live under a `Packages/` directory and are referenced by path; the
executable target depends on the package products and excludes the `Packages` dir from
its own sources:

```swift
// swift-tools-version: 6.0
let package = Package(
    name: "MyApp",
    platforms: [.iOS(.v17)],
    products: [.executable(name: "MyApp", targets: ["MyApp"])],
    dependencies: [
        .package(path: "App/Packages/Network"),
        .package(path: "App/Packages/Websockets"),
        .package(path: "App/Packages/ProjectFoundation"),
        .package(path: "App/Packages/Connections"),
        .package(path: "App/Packages/Chat")
    ],
    targets: [
        .executableTarget(
            name: "MyApp",
            dependencies: ["Network", "Websockets", "ProjectFoundation", "Connections", "Chat"],
            path: "App",
            exclude: ["Packages"]
        )
    ]
)
```

## What belongs here vs. not

- **Here:** Composer enums, `…Live` instantiation, environment/config selection,
  app entry point, root navigation scaffolding.
- **Not here:** networking, business logic, data mapping, view logic — those live in
  the relevant infrastructure or domain packages. If you're writing an `if` about
  product behavior in the app target, it's in the wrong place.
