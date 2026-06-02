# Scopes and containers

Composers are stateless factories (see [composition-root.md](composition-root.md)). But a
real app has state with a *lifetime* — a session, a live socket subscription, an in-memory
cache that exists only while the user is signed in. That state lives in **scopes** and
**containers**, not in composers.

Three roles, kept distinct:

| Role          | Kind                  | Holds state? | Lifetime                                  |
|---------------|-----------------------|--------------|-------------------------------------------|
| **Composer**  | `enum` + `static make`| No           | None — builds and forgets                 |
| **Scope**     | object (the graph)    | Yes          | A lifecycle phase (signed-out / signed-in)|
| **Container** | `final class`/actor   | Yes          | Owned by a scope; lives and dies with it  |

## Lifecycle scopes

A **scope** is a lifetime boundary for a phase of the app. The fundamental two are the
**signed-out** scope and the **signed-in** scope, and the thing that separates them is the
session: the signed-in scope *owns* an `AppSession`, the signed-out scope does not.

A scope is the root from which every sub-view and sub-flow of that phase is built. You do
not reach across scopes — a signed-in flow is constructed from the signed-in scope and has
the session in hand by construction.

This is the **key/lock gate**. The signed-in scope's initializer *requires* a session
value, so it is unconstructable without one — there is no code path to the authenticated
graph without a session:

```swift
// Signed-out scope: the only producer of a session.
let bootstrap = Bootstrap.make()

switch phase {
case .signedOut:
    SignedOutView()                              // built from the signed-out scope
case .authenticated(let session):
    let scope = AuthenticatedComposition(session: session)  // the lock
    RootView(chat: scope.chatContainer, connections: scope.connectionsService)
}
```

Creating the signed-in scope **opens** the phase; releasing it **closes** the phase and
tears down everything it owns. Sign-out is just "drop the signed-in scope": its containers,
subscriptions, and caches go with it. Nothing leaks into the next session.

## Containers

A **container** holds the live, in-memory data a domain needs *within a scope* — a socket
subscription, an `@Observable` store, a cache built on sign-in. Unlike a composer (which
forgets) and like a scope (which has a lifetime), a container is a stateful reference type:
a `final class`, often `@MainActor @Observable` or an `actor`.

A container is **created with its scope and destroyed with it**. It is owned by the scope,
held as a stored property, and injected into the flows/views that need it. When the scope
goes away, the container deinits — its subscription cancels, its store empties.

```swift
/// Owns the authenticated chat state: the live socket subscription and the
/// in-memory message store. Created when the signed-in scope is built (i.e. on
/// authentication); torn down when that scope is released (sign-out).
@MainActor
final class ChatContainer {
    let store: any ChatStore                 // in-memory, scope-lived
    private let subscription: Task<Void, Never>

    init(session: AppSession, socket: any WebsocketClient, store: any ChatStore) {
        self.store = store
        // Live subscription bound to this container's lifetime.
        self.subscription = Task { await store.consume(socket.messages(for: session)) }
    }

    deinit { subscription.cancel() }         // dies with the scope
}
```

The scope builds its containers (via composers) and owns them:

```swift
struct AuthenticatedComposition {            // the signed-in scope
    let session: AppSession
    let chatContainer: ChatContainer

    init(session: AppSession) {
        self.session = session
        let socket = WebsocketClientComposer.make(session: session)
        self.chatContainer = ChatContainer(
            session: session,
            socket: socket,
            store: InMemoryChatStore()
        )
    }
}
```

## Choosing between the three

- **Build something and hand it off, keeping nothing?** → a **composer**.
- **A lifetime boundary tied to a session / app phase, the root for that phase's flows?**
  → a **scope**.
- **Live in-memory state (subscription, store, cache) that must exist only within a phase
  and vanish when it ends?** → a **container**, owned by that scope.

Composers stay stateless; scopes and containers are where state and lifetime live.
