---
name: container
description: Defines the container pattern — a Sendable holder with no functions and mutable state behind a Mutex, holding a domain's scope-lived in-memory state (a store/cache or a live subscription). Use when creating a container, deciding where to hold in-memory state, or choosing between holding state versus composing a stateless dependency on access.
---

# Container Pattern

A **container** is the `Sendable` *holder* of a domain's scope-lived in-memory state. It has
no functions, does no composition, and keeps any mutable state behind a `Mutex`. It exists
for exactly one reason: some state has a *lifetime* and must be **held** in memory for that
lifetime. The container is what holds it.

The container holds the **store**; **the store is not the container.** A store (a type with
functions like `upsert` / `stream` / `removeAll`) is the scope-lived state *held by* a
container. Everything stateless — a repository, a use case, a service struct — is *not*
held; it is composed on access.

Two canonical shapes for the held state:

- **An in-memory store / cache** — e.g. a current-user store that holds a value and fans it
  out to observers.
- **A held subscription** — e.g. a socket subscription kept alive for the scope's duration
  and released when the scope ends.

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
   the **store** instead, and compose the repository on access in the main app.
4. **Does NOT have functions.** A container is a holder of state, not a behavior surface.
   It exposes the held state; it does not add methods of its own. It also does NO work in
   `init` — `init` only stores the dependencies passed to it. Any logic (starting a
   subscription, seeding a cache) belongs in a bootstrap use case, not the container.
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

- **If it's a `struct` with no held state, it is not container material.** It is composed
  on access. A repository is exactly this — a stateless protocol whose default
  implementation is a struct. You do **not** store it; you store the store it reads from and
  build the repository when accessed.
- **If it holds values in memory or holds a live subscription, it is container material.**
  An in-memory store is exactly this — it holds the current value and a set of live
  continuations for the scope's lifetime.

### Smells that mean you've built the wrong thing

- Your "container" has methods that *do* work (mapping, fetching, policy) → that behavior
  belongs in a repository or use case, not a container (rule 4).
- Your "container" does work in `init` (starts a task, seeds a cache) → that bootstrapping
  belongs in a use case (rule 4); `init` only stores dependencies.
- Your "container" reaches out and constructs its own dependencies → that's composition;
  move it to a composer (rule 2).
- Your "container" stores a repository, a use case, or a service struct → you're storing a
  composed, stateless dependency; store the underlying *state* instead and compose the
  stateless thing on access (rule 3).
- Your "container" has a bare `var` mutated from more than one place → unsynchronized
  mutable state; put it behind a `Mutex` (rule 6).

## Worked example

A feature container holds a store (the in-memory state) and a subscription it keeps alive
for the scope's lifetime. It is a plain `Sendable` holder: no functions, no `init` logic,
mutable state behind a real `Mutex` from Swift's `Synchronization` framework. A separate
bootstrap use case starts the subscription.

```swift
import Synchronization

/// Holds the feature domain's scope-lived state: the in-memory `store` and the
/// subscription kept alive for as long as the scope lives. A plain holder — no
/// functions, no `init` logic. Created on scope start; the bootstrap use case
/// starts its subscription, and the scope cancels it on teardown.
///
/// Holds the STORE (state), not a repository: a repository is a stateless struct,
/// so it is composed on access in the app, never stored here.
public final class FeatureContainer: Sendable {
    /// The in-memory state this container exists to hold.
    public let store: any SomeStore

    /// Mutable state shared across concurrency domains, behind a real `Mutex`
    /// (Swift `Synchronization`). The bootstrap use case writes the task here;
    /// the scope cancels it on teardown.
    public let subscription = Mutex<Task<Void, Never>?>(nil)

    /// `init` only stores the dependency passed in — no composition, no work.
    public init(store: any SomeStore) {
        self.store = store
    }
}
```

Bootstrapping — starting the subscription — lives in a use case, NOT in the container.
This keeps the container a trivially testable holder and puts the lifecycle logic somewhere
that can be exercised on its own:

```swift
/// Starts the container's scope-lived subscription. Lives outside the container
/// so the container stays a plain holder and this logic is testable in isolation.
struct BootstrapFeatureContainerUseCase {
    func callAsFunction(container: FeatureContainer) {
        container.subscription.withLock { task in
            guard task == nil else { return }   // idempotent — a second call is a no-op
            task = Task {
                // observe a websocket / repository stream and feed the store
            }
        }
    }
}
```

The bootstrap use case **is** the subscription's lifetime owner — no separate starter or
observation types. The first authenticated surface invokes it once; the store-only-if-nil
guard makes a stray second call harmless.

Notes tying this back to the rules:

- **Holds state, no functions, no `init` logic (rules 1, 4):** the container exposes
  `store` and `subscription`; it adds no methods, and `init` only stores `store`. Starting
  the subscription is the use case's job.
- **No composition (rule 2):** `store` is passed in. The container does not build it.
- **Holds the store, not the repository (rule 3):** a repository is stateless, so it is
  absent here — composed on access in the app from the held `store`.
- **`Sendable` (rule 5):** the class is `Sendable`; `store` is `Sendable` and the `Mutex`
  guards the only mutable state.
- **Mutex (rule 6):** the mutable `subscription` lives behind a real `Mutex` from
  `Synchronization`, written by the bootstrap use case and the scope's teardown.
- **Protocol-typed state is explicit:** held protocol state is declared `any SomeStore`,
  never a bare protocol name.

> Note on isolation: a `Sendable` scope-lived state holder can be an `@Observable` class,
> an `actor`, or a `Mutex`-protected type — all three are valid kinds. The container rule is
> specifically about the container's *own* mutable state: when a container holds a mutable
> value, that value goes behind a `Mutex`.

## Where the container lives

The container type lives **in the feature package** (named like `FeatureContainer`). It is
instantiated in the main app, its state is held by the main app, and it is bootstrapped in
the main app (by calling the bootstrap use case). The main app owns the container for the
duration of the scope and tears it down — cancelling the subscription — when the scope ends.

## Containers always exist

Create the container unconditionally when its scope starts. Never wrap it in an
availability layer — no `isInitialized` flags, no membership checks deciding whether the
container gets created, no optional container on the scope. A container is just held state
and is cheap to hold; whether the *feature* is shown is a rendering decision, not the
container's concern.

## Cross-links

- **Composition** → the `ios-composition` skill. Composers are the stateless factories that
  build dependencies; a container never composes (rule 2). When you need to *build*
  something, that's a composer's job.
