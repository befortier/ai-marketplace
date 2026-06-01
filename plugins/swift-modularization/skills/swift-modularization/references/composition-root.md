# Composition root (the app target)

The app/executable target is thin: it owns no business logic. Its job is to build the
object graph — instantiate `…Live` implementations, inject `any Protocol` values, and
hand the wired graph to the UI.

## Composer enums

Wiring is expressed as `Composer` enums with a static `make(...)` factory that returns
an abstraction (`any SomeProtocol`). A Composer knows the concrete types; nothing else
does. Composers can nest.

```swift
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

The Composer returns an abstraction (`any BootstrapUseCase`), wires `…Live` types, and
composes other Composers. For how packages are declared and depended upon, see
[package-new-package.md](package-new-package.md) and
[package-app-dependencies.md](package-app-dependencies.md).
