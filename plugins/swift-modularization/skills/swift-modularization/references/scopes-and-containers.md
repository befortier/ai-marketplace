# Scopes and containers

Composers are stateless factories (see [composition-root.md](composition-root.md)). But a
real app has state with a *lifetime* — a session, a live socket subscription, an in-memory
cache that exists only while the user is signed in. That state lives in **scopes** and
**containers**, not in composers.

Three roles, kept distinct:

| Role          | Kind                       | Holds state? | Lifetime                                  |
|---------------|----------------------------|--------------|-------------------------------------------|
| **Composer**  | `enum` + `static make`     | No           | None — builds and forgets                 |
| **Scope**     | object (the graph)         | Yes          | A lifecycle phase (signed-out / signed-in)|
| **Container** | `Sendable` state holder¹   | Yes          | Owned by a scope; lives and dies with it  |

¹ Containers have their own skill — **`ios-container`** — for the full rules and example.

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

> **Moved.** The container concept now has its own dedicated skill: **`ios-container`**.
> It covers the full definition, rules, decision guide, and a worked example grounded in
> the User package's store. See that skill for everything about containers.

In one line for context here: a **container** holds and organizes a domain's scope-lived
in-memory state (an in-memory store/cache, or a subscription held for the duration of a
scope). It does no composition and has no functions; it is `Sendable`, holds only the
root-level state (not stateless/composed dependencies like a repository), and guards any
mutable state behind a `Mutex`. The scope owns its containers and tears them down with it.

For the rules, the "do I need a container?" decision guide, and the worked example, use the
**`ios-container`** skill.

## Choosing: composer vs. scope vs. container

- **Build something and hand it off, keeping nothing?** → a **composer**.
- **A lifetime boundary tied to a session / app phase, the root for that phase's flows?**
  → a **scope**.
- **Live in-memory state (subscription, store, cache) that must exist only within a phase
  and vanish when it ends?** → a **container** (see the **`ios-container`** skill), owned
  by that scope.

Composers stay stateless; scopes and containers are where state and lifetime live.
