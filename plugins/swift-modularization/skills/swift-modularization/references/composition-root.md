# Composition root (the app target)

The app/executable target is thin: it owns no business logic. Its job is to build the
object graph — instantiate `…Live` implementations, inject `any Protocol` values, and
hand the wired graph to the UI. Keep the actual wiring in one `AppComposition` area
package (the only thing that depends on every `…Live` product); the `@main` entry just
calls into it.

## Composer enums

Wiring is expressed as `Composer` enums with a static `make(...)` factory that returns an
abstraction (`any SomeProtocol`). A Composer knows the concrete types; nothing else does.
Composers can nest. Dependencies are **passed in** (initializer injection), not reached
for as globals, and built **lazily** — a dependency that needs a session is constructed
only once a session exists.

```swift
enum WebsocketComposer {
    static func make() -> any WebsocketClient { WebsocketClientLive() }
}
```

## The key/lock: a session unlocks the app

Make authentication a **compile-time gate**, not a runtime check. The authenticated graph
must be impossible to construct without an `AppSession` — the session is the *key*, the
authenticated scope's initializer is the *lock*. There is no path to the main app UI that
doesn't first produce a session.

```swift
import Session   // AppSession

/// Everything that needs an authenticated user. Its ONLY initializer takes a
/// session, so you cannot build it — or the main app view — without one.
struct AuthenticatedScope {
    let chat: any ChatService
    let connections: any ConnectionsService

    init(session: AppSession, modelContainer: any ModelContainerProtocol) {
        let bearer = BearerNetworkServiceComposer.make(session: session)
        self.chat = ChatServiceLive(network: bearer)
        self.connections = ConnectionsServiceLive(network: bearer, store: .init(container: modelContainer))
    }
}
```

The root observes the session store and switches on it. Unauthenticated → the login/
bootstrap flow; authenticated → build the scope (lazily, with the session passed in) and
show the main app. The authenticated view's initializer *requires* the scope:

```swift
enum RootComposer {
    @MainActor
    static func make() -> some View {
        RootView(
            sessionStore: SessionComposer.make(),
            // The lock: an authenticated root can only be built from a session.
            authenticatedRoot: { session in
                MainTabView(scope: AuthenticatedScope(session: session, modelContainer: ...))
            }
        )
    }
}

struct RootView<Authed: View>: View {
    let sessionStore: any SessionStore
    let authenticatedRoot: (AppSession) -> Authed
    @State private var session: AppSession?

    var body: some View {
        if let session {
            authenticatedRoot(session)        // main app — only reachable with a key
        } else {
            LoginView(store: sessionStore)    // mint/restore the session
        }
        // .task { session = try? await sessionStore.restore() } etc.
    }
}
```

Why this shape: nothing downstream re-checks "am I logged in?" — the type system already
guarantees it, because `AuthenticatedScope`/`MainTabView` can't exist without a session.
This mirrors the res-bot-ios `BootstrapUseCaseComposer`, whose authenticated repositories
are built inside a `{ session in … }` factory rather than eagerly.

For how packages are declared and depended upon, see
[package-new-package.md](package-new-package.md) and
[package-app-dependencies.md](package-app-dependencies.md).
