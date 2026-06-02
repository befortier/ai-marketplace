---
name: container
description: Defines the container pattern — a Sendable holder (no functions, mutable state behind a Mutex) that holds a domain's scope-lived in-memory state, either an in-memory store/cache or a scope-duration subscription. A container holds the store; the store (e.g. UserStore, which has functions) is the held state, not the container. Use when creating or adding a container, deciding where to hold in-memory state, holding a subscription or store for a scope's lifetime, or deciding whether a dependency must be held in memory versus composed on access. Also applies when discussing Sendable state holders, Mutex-protected mutable state, or what a container may and may not do.
---

# Container Pattern

A **container** is the `Sendable` *holder* of a domain's scope-lived in-memory state. It
has no functions, does no composition, and keeps any mutable state behind a `Mutex`. It is
a holder, not a wiring mechanism.

The container holds the **store**; **the store is not the container.** This is the one
distinction to keep straight:

- A **container** is the holder — `Sendable`, no functions, mutable state behind a `Mutex`.
- A **store** (e.g. `UserStore`, which *has* functions `upsert` / `stream` / `removeAll`)
  is the scope-lived state *held by* a container. The store is owned by the signed-in scope
  and finished on scope-teardown `deinit`. A store is **never** "a container"; it is the
  state a container holds.

A container exists for exactly one reason: some state has a *lifetime* and must be **held**
in memory for that lifetime. The container is what holds it. Everything that is stateless —
a repository, a use case, a service struct — is *not* held; it is composed on access.

## What a container is

A container holds the root-level, in-memory state (the store) a domain needs while a scope
is alive. Two canonical shapes for that held state:

- **An in-memory store / cache** — e.g. the current-user store that holds the signed-in
  `User` and fans it out to observers.
- **A held subscription** — e.g. a socket subscription that must be kept alive for the
  duration of the scope and released when the scope ends.

The held state itself is a `Sendable` scope-lived state holder, which may be an
`@Observable` class, an `actor`, or a `Mutex`-protected `struct` — all three are valid.

## Rules

A container MUST follow every rule below. These are not guidelines; a type that breaks any
of them is not a container.

1. **Holds and organizes in-memory state.** Its entire job is to *hold* the root-level
   state for a domain — an in-memory store/cache, or a scope-duration subscription.
2. **Does NOT handle composition.** Wiring up dependencies is a composer's job, not a
   container's. A container receives what it holds; it does not build a graph.
3. **Does NOT store composed dependencies.** Store *only* the root-level dependency that
   genuinely needs a container to hold it (the state). Do **not** store stateless,
   composed dependencies. A repository is a stateless struct — do **not** store it. Store
   the **store** instead, and compose the repository on access in the main app later.
4. **Does NOT have functions.** A container is a holder of state, not a behavior surface.
   It exposes the held state; it does not add methods of its own.
5. **Is `Sendable`.** A container is shared across the scope's flows and concurrency
   domains; it must be `Sendable`.
6. **Mutable state is protected via a mutex.** Any mutable state the container holds is
   guarded by a `Mutex` (Swift `Synchronization`). No unsynchronized `var`.

## Decision guide — do I need a container?

Ask one question: **does this thing carry in-memory state with a lifetime?**

| The dependency is…                                         | Hold it in a container? |
|------------------------------------------------------------|-------------------------|
| An in-memory store / cache (holds values in memory)        | **Yes** — this is the held state |
| A subscription that must stay alive for the scope          | **Yes** — hold it for the scope's duration |
| A stateless repository (a struct, no held state)           | **No** — compose on access |
| A stateless use case / service struct                      | **No** — compose on access |
| Anything you build, hand off, and forget                   | **No** — that's a composer's output |

Two quick rules that fall out of this:

- **If it's a `struct` with no held state, it is not container material.** It is composed
  on access. The `UserRepository` is exactly this — a stateless protocol whose default
  implementation is a struct. You do **not** store it; you store the `UserStore` it reads
  from and build the repository when accessed.
- **If it holds values in memory or holds a live subscription, it is container material.**
  The `UserStore` / `InMemoryUserStore` is exactly this — it holds the current user and a
  set of live continuations for the scope's lifetime.

### Smells that mean you've built the wrong thing

- Your "container" has methods that *do* work (mapping, fetching, policy) → that behavior
  belongs in a repository or use case, not a container (rule 4).
- Your "container" reaches out and constructs its own dependencies → that's composition;
  move it to a composer (rule 2).
- Your "container" stores a repository, a use case, or a service struct → you're storing a
  composed, stateless dependency; store the underlying *state* instead and compose the
  stateless thing on access (rule 3).
- Your "container" has a bare `var` mutated from more than one place → unsynchronized
  mutable state; put it behind a `Mutex` (rule 6).

## Worked example — grounded in the User package

The User package gives us both sides of the line.

### The held state — `UserStore` (hold this)

`UserStore` is the scope-lived state a container *holds* — it is **not** itself a container.
It *has* functions (`upsert` / `stream` / `removeAll`), holds the current user in memory,
and fans it out to observers. It has a lifetime (the signed-in scope) and must be *held* so
observers keep receiving updates; it is owned by the signed-in scope and finished on
scope-teardown `deinit`.

```swift
// User package — the store: the scope-lived state a container holds (NOT a container).
@Mocked
public protocol UserStore: Sendable {
    func upsert(_ user: User) async
    func stream(replayCurrentValue: Bool) async -> AsyncStream<User?>
    func removeAll() async
}
```

Its `UserLive` implementation, `InMemoryUserStore`, is an `actor` holding `currentUser` and
a dictionary of `AsyncStream` continuations — live, in-memory, scope-lived state. An
`actor` is one valid `Sendable` state-holder kind; an `@Observable` class or a
`Mutex`-protected `struct` would be equally valid. This store is the thing a container
exists to hold — the container holds it, it is not the container.

### The stateless dependency — `UserRepository` (do NOT hold this)

`UserRepository` is a stateless protocol; its default implementation is a struct that is
thin orchestration over the store and service. It carries no in-memory state of its own.

```swift
// User package — stateless. NOT container material; compose it on access.
@Mocked
public protocol UserRepository: Sendable {
    @discardableResult
    func loadCurrentUser() async throws -> User
    func currentUserStream(replayCurrentValue: Bool) async -> AsyncStream<User?>
}
```

Do **not** store a `UserRepository` in a container. Store the `UserStore` (the state), and
compose the repository when the app accesses it — it's a cheap struct over the held store.

### The container — holds the store and a scope-duration subscription

A container for the user domain holds the `UserStore` (the in-memory state, the thing
held) and a subscription it keeps alive for the scope's lifetime. It is `Sendable`, has no
functions of its own, does no composition, and guards its mutable state behind a `Mutex`.

```swift
import Synchronization

/// Holds the user domain's scope-lived state: the in-memory `UserStore` and the
/// subscription that keeps it fed for as long as the scope is alive. Created on
/// authentication; released — cancelling the subscription — when the scope ends.
///
/// Holds the STORE (state), not a repository: `UserRepository` is a stateless
/// struct, so it is composed on access in the app, never stored here.
public struct UserContainer: Sendable {
    /// The in-memory state this container exists to hold.
    public let store: any UserStore

    /// Mutable state shared across concurrency domains, behind a `Mutex`. The
    /// `Mutex` is `~Copyable`, so it lives in a small `Sendable` reference box the
    /// subscription task can capture and keep mutating after `init` returns.
    private let mutable: Box

    private final class Box: Sendable {
        struct State {
            var subscription: Task<Void, Never>?
            var lastSeen: [User.ID: User] = [:]
        }
        let state = Mutex(State())
    }

    /// Receives the store and the already-composed input it feeds from. It does
    /// NOT compose them itself (rule 2) and stores only the store, not a
    /// composed repository (rule 3).
    public init(store: any UserStore, updates: AsyncStream<User>) {
        self.store = store
        let mutable = Box()
        self.mutable = mutable
        let task = Task { [store, mutable] in
            for await user in updates {
                // Mutates the same Mutex-guarded state after init, from a
                // different path than the one that seeded it: a true shared write,
                // which is exactly why the Mutex is required.
                let isNew = mutable.state.withLock {
                    $0.lastSeen.updateValue(user, forKey: user.id) == nil
                }
                if isNew { await store.upsert(user) }
            }
            // Stream ended: clear the held task so the scope can tell it is no
            // longer live — another write to the same guarded state.
            mutable.state.withLock { $0.subscription = nil }
        }
        // The seeding write from init, racing the loop's writes above.
        mutable.state.withLock { $0.subscription = task }
    }
}
```

The `Mutex` is load-bearing, not decorative: `subscription` and `lastSeen` are written
from two paths (init's seeding write and the subscription task's per-update writes) on
different concurrency domains. A bare `var` would be a data race.

Notes tying this back to the rules:

- **Holds state, no functions (rules 1, 4):** the container exposes `store`; it adds no
  methods of its own. The subscription is held, not called.
- **No composition (rule 2):** `store` and `updates` are passed in. The container does not
  build them.
- **Holds the store, not the repository (rule 3):** `UserRepository` is stateless, so it is
  absent here — composed on access in the app from the held `store`.
- **`Sendable` (rule 5):** the struct is `Sendable`; everything it holds is `Sendable`.
- **Mutex (rule 6):** the mutable `state` (subscription + cache) lives behind a `Mutex`
  from `Synchronization`, written from more than one concurrency domain.

> Note on isolation: a `Sendable` scope-lived state holder can be an `@Observable` class,
> an `actor`, or a `Mutex`-protected `struct` — all three are valid kinds. The repo's
> `InMemoryUserStore` uses `actor` isolation for its *own* internals; the container above
> uses a `Mutex`; an `@Observable` model the UI observes is the third. The container rule
> is specifically about the container's mutable state: when a container itself holds a
> mutable `var`, that `var` goes behind a `Mutex`.

## Where the container lives

Containers are created and owned by a **scope** and built (never composed in-place) from
composers. The container does the holding; the scope owns the container; composers build
the stateless pieces. The User container above is constructed inside the authenticated
scope — the same place `AuthenticatedComposition` builds the rest of the signed-in graph —
and released when that scope is torn down on sign-out.

## Cross-links

- **Composition** → the `ios-composition` skill. Composers are the stateless factories
  that build dependencies; a container never composes (rule 2). When you need to *build*
  something, that's a composer's job.
- **Scope / Bootstrap** → `AppComposition/CLAUDE.md` (the scope and bootstrap docs). The
  scope is the lifecycle boundary that *owns* the session and owns the containers for its
  phase. A container lives inside a scope and is torn down with it.

## Checklist

- [ ] The container holds in-memory state with a lifetime (a store/cache or a held
      subscription)
- [ ] It does **no** composition — what it holds is passed in
- [ ] It stores only the root-level state, **not** any stateless/composed dependency
      (no stored repositories, use cases, or service structs)
- [ ] It has **no** functions of its own — it holds, it does not behave
- [ ] It is `Sendable`
- [ ] Every piece of mutable state is behind a `Mutex` (Swift `Synchronization`)
- [ ] Stateless dependencies (e.g. a repository) are composed on access, not held here
