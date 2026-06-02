---
name: composition
description: Composes a feature's dependency graph and infers the app's navigation tree using stateless enum composers, from feature containers, app sessions, and local state. Composition is wiring + navigation only — no business logic, analytics, or network calls. Use when composing dependencies, wiring up a feature, building the composition root, inferring the navigation tree, adding a feature to the app graph, or discussing composers, feature containers, app sessions, and why packages defer navigation upward.
---

# Composition

Composition assembles a feature's raw dependencies into a working graph and infers the app's **navigation tree**. It lives in **one place** — the main app target — and nowhere else. Feature packages expose raw initializers and stay ignorant of how they are wired or navigated; the app composes them.

## Rules

1. **Composers are stateless enums.** `enum XComposer { @MainActor static func make(...) -> SomeView }`. Never a struct, never holding state, never an init.
2. **Packages do not compose.** They expose raw initializers and abstractions; they are handed everything they need.
3. **Composition lives in one place** — the main app target. Never in a feature package.
4. **Composers take feature containers + app sessions + local state.** Local state means state inferable from a local action/state, not global state.
5. **Composers return composed views with their dependencies wired**, and infer the navigation tree between them.
6. **Navigation is inferred only in composition.** Packages defer navigation upward — the app is the only layer that sees every feature.
7. **Composition is wiring + navigation only.** No business logic, no analytics, no network calls. A composer builds the thing that calls; it never calls.

## What composition is — and is not

Composition is **only two things**:

1. **Composition of dependencies** — taking the raw pieces and constructing the wired graph.
2. **The navigation tree** — deciding how composed screens relate.

If you find any of the following in a composer, it belongs in a use case, a repository, a service, or a view model — not here:

- **No business logic.** No decisions, no branching on domain rules.
- **No analytics.** No event firing, no tracking.
- **No network calls.** A composer constructs the thing that makes the call; it never makes the call itself.

## Composers are stateless enums

A composer is a stateless `enum` with a single `static func make(...)`. It takes raw inputs, builds the dependency graph, returns the composed view, and forgets. It never holds state and never has an init — there is nothing to instantiate.

```swift
enum SomeFeatureContainerComposer {
    @MainActor
    static func make(
        session: AppSession,
        entryPoint: EntryPoint,
        container: SomeFeatureContainer
    ) -> SomeFeatureView {
        // Pure wiring: build dependencies from the inputs.
        let repository = DefaultSomeFeatureRepository(
            networkService: session.networkService,
            store: container.store
        )
        let service = DefaultSomeFeatureService(repository: repository)
        let useCase = DefaultSomeUseCase(
            service: service,
            otherContainer: container.otherContainer
        )

        return SomeFeatureView(
            entryPoint: entryPoint,
            service: service,
            someUseCase: useCase
        )
    }
}
```

The composer **constructs** the service that makes network calls; it never makes a call itself. There is no business logic and no analytics — just wiring, the first allowed job.

The `make` is marked `@MainActor` only when it must be — for example when it constructs a `View` or touches main-actor-isolated state. Put `@MainActor` on the `static func`, never on a struct or init: composers are enums and have neither.

### Inputs

- **Feature containers** — `Sendable` per-feature holders of scope-lived state (a socket subscription, an in-memory store). They hold no functions and no init logic; mutable state sits behind a [`Mutex`](https://developer.apple.com/documentation/Synchronization/Mutex). They are bootstrapped by a use case (e.g. `BootstrapFeatureContainerUseCase`) and instantiated, held, and bootstrapped in the main app. (See the `ios-container` skill.)
- **App session** — the signed-in session value (`AppSession`) that owns session-lived dependencies. Authenticated dependencies cannot be composed without it.
- **Local state** — state inferable only from a local action or local state, **not** global state. Navigation phase (loading / authenticated / signed-out) is the canonical example: it is driven by a local `@State` transition, not by a global flag.

## Navigation belongs to composition, only

**Composition is the ONLY place it is okay to infer the navigation tree.** A composed view defers navigation upward: it surfaces a navigation request and lets the composer decide what comes next by composing the destination. This bubbles navigation out of the feature and up to the app — the only layer that can see every feature.

```swift
enum ProductListViewComposer {
    @MainActor
    static func make(session: AppSession, container: CatalogContainer) -> ProductListView {
        let repository = DefaultProductRepository(
            networkService: session.networkService,
            store: container.store
        )
        let service = DefaultProductService(repository: repository)

        return ProductListView(service: service) { navigationRequest in
            switch navigationRequest {
            case .detailsPage(let id):
                ProductDetailsPageComposer.make(session: session, id: id)
            case .supportPage(let request):
                SupportViewComposer.make(session: session, request: request)
            }
        }
    }
}
```

`ProductListView` knows nothing about `ProductDetailsPage` or `SupportView`. It emits a `navigationRequest`; the composer maps each case to the destination composer. The view-architecture skill dictates how the view surfaces that request.

## Packages just expose raw initializers

A feature package exposes its **raw initializers** and abstractions. It does not build its own graph, does not reach for another package's dependencies, and does not know how it is wired or navigated — it is handed everything it needs.

```swift
public struct SomeFeatureView: View {
    public init(
        entryPoint: EntryPoint,
        service: any SomeFeatureService,
        someUseCase: any SomeUseCase
    ) { /* store and inject — no wiring, no navigation decisions */ }
}
```

## App Package Folder Layout

The main App / App package organizes its composition source by **one folder per domain or
infrastructure concern**. Each folder holds that domain's composers and any main-app
activities (bootstrapping, lifecycle wiring) for that package.

Every composer protocol and any associated implementation live in **separate files**.

```
AppComposition/
├── Network/                        # HTTP client setup, NetworkClientComposer
│   └── NetworkClientComposer.swift
├── Websocket/                      # WebSocket client + session bootstrapping
│   ├── WebsocketClientComposer.swift
│   └── BootstrapWebsocketUseCase.swift
├── User/                           # User domain composers + bootstrap
│   ├── UserComposer.swift
│   └── BootstrapUserContainerUseCase.swift
├── <Domain>/                       # One folder per additional domain or infra area
│   ├── <Domain>Composer.swift
│   └── Bootstrap<Domain>UseCase.swift
└── AppComposition.swift            # Root: ties all domain folders into the session graph
```

**Rules:**
- **One folder per domain or infrastructure area.** Don't put all composers in a flat list at the root.
- **A folder's scope is the package it composes.** `Network/` wires the `Networking` package; `User/` wires the `User` package.
- **Bootstrap use cases live alongside their domain's composers** — they are main-app activities for that domain, not feature-package code.
- **Composer protocols (if any) and their implementations are separate files** — same rule as all other layers.

## See also

- **`ios-container` skill** — feature containers that hold scope-lived state, created on auth and torn down with the scope. A primary input to composition.
