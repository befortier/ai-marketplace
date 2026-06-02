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

## Composers are stateless

A Composer is a pure factory: an `enum` (never instantiable) whose `make(...)` builds and
returns a value, then forgets it. It holds **no stored properties and no state** — the
graph it builds is owned by the caller (a [scope or container](scopes-and-containers.md)),
not by the Composer. If you find yourself wanting a Composer to *remember* what it built,
you don't want a Composer — you want a scope or a container.

- `enum FooComposer { static func make(...) -> any Foo }` — yes.
- A `class`/`struct` Composer with stored deps it hands out repeatedly — no; that's a
  scope or container wearing a Composer's name.

## Defer composition to the app

Composition lives in the **app target** (or a dedicated `AppComposition` package), never
inside feature packages. A feature package exposes its abstractions and `…Live` types and
stays ignorant of how it's wired. Only the composition root imports the `…Live` modules
and knows the concrete graph. This keeps features free of each other and free of the
infrastructure choices made above them.

## Debug vs. release composition

A Composer is the one place allowed to vary the graph by build configuration. Branch on
`#if DEBUG` *inside* the Composer and return the **same abstraction** from both arms — the
debug arm decorates the real value (attaches a logger/recorder), the release arm returns
it plain. Callers can't tell the difference; only the Composer knows.

```swift
#if DEBUG
import DebugTools

enum URLSessionComposer {
    static func make() -> any NetworkClient {
        // Debug builds wrap the real client in a recorder/logger decorator.
        RecordingNetworkClient(wrapped: URLSession.shared)
    }
}
#else
enum URLSessionComposer {
    static func make() -> any NetworkClient {
        URLSession.shared
    }
}
#endif
```

The decorator (`RecordingNetworkClient`) conforms to the same protocol it wraps, so the
debug instrumentation is invisible to everything downstream. Keep the `#if DEBUG` fence in
the Composer — never leak build-configuration checks into feature code.
