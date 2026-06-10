---
name: composition
description: Composes a feature's dependency graph and infers the app's navigation tree with stateless enum composers that take the app session (a pure-holder scope), local state, and closures. Wiring and navigation only — no business logic, analytics, network, or unit tests. Use when wiring a feature, building the composition root or app-session builder, adding convenience initializers, or discussing composers, feature containers, and scopes.
---

# Composition

Composition assembles a feature's raw dependencies into a working graph and infers the app's **navigation tree**. It lives in **one place** — the main app target — and nowhere else. Feature packages expose raw initializers and stay ignorant of how they are wired or navigated; the app composes them.

## Rules

1. **Composers are stateless enums.** `enum XComposer { @MainActor static func make(...) -> SomeView }`. Never a struct, never holding state, never an init.
2. **Packages do not compose.** They expose raw initializers and abstractions; they are handed everything they need.
3. **Composition lives in one place** — the main app target. Never in a feature package.
4. **Composers take the app session (the scope) + local state + closures.** Read held containers and clients *off the session*; never thread them in as separate parameters. Local state means state inferable from a local action/state, not global state.
5. **Composers return composed views with their dependencies wired**, and infer the navigation tree between them.
6. **Navigation is inferred only in composition.** Packages defer navigation upward — the app is the only layer that sees every feature.
7. **Composition is wiring + navigation only.** No business logic, no analytics, no network calls. A composer builds the thing that calls; it never calls.
8. **Composition has no unit tests.** Composition is wiring — there is nothing to unit-test, and the *urge* to test a composer means logic leaked in. Move that logic out, and test it there.

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
enum SomeFeatureViewComposer {
    @MainActor
    static func make(session: AppSession, entryPoint: EntryPoint) -> SomeFeatureView {
        // Pure wiring: read held state off the session; build the rest.
        let repository = DefaultSomeFeatureRepository(
            networkService: session.networkService,
            store: session.someFeatureContainer.store
        )
        let service = DefaultSomeFeatureService(repository: repository)
        let useCase = DefaultSomeUseCase(service: service)

        return SomeFeatureView(entryPoint: entryPoint, service: service, someUseCase: useCase)
    }
}
```

The composer **constructs** the service that makes network calls; it never makes a call itself. There is no business logic and no analytics — just wiring, the first allowed job. `someFeatureContainer` comes off the session (Rule 4), not as a separate parameter.

Mark `make` `@MainActor` only when it must be — e.g. when it constructs a `View` or touches main-actor-isolated state. Put `@MainActor` on the `static func`, never on a struct or init: composers are enums and have neither.

## The app session is a pure holder; a builder composes it

The **app session** (the authenticated scope) is a `Sendable` value that *holds* the session-lived dependencies — the signed-in session, the shared clients (HTTP, socket), and the feature containers. It has **no functions and no composition logic in its `init`**: it only stores already-built dependencies.

The wiring that *builds* those dependencies lives in a **builder** — itself a composer (`enum AppSessionComposer { static func make(...) -> AppSession }`) that constructs each piece and hands them to the session's memberwise initializer. Keep composition out of the session's `init`: a holder that also composes is doing two jobs, and every consumer pays for the conflation.

Hold in the session **only what must live for the whole session** — live state: a current-user store, a run-state store, a socket subscription (see the `ios-container` skill). Audit each held thing: if it carries no live state and is cheap to rebuild, it does not belong in the session — build it on demand instead (next section).

## Composers take the app session, not a bag of fields

A composer's signature is **`(session, local state, closures)`**. Read the held containers and clients off the session *inside* the composer — never thread them in as separate parameters. A composer that takes six or nine individual session fields is the smell this rule exists to kill: take the session and read what you need.

```swift
// Don't — a bag of individual session fields:
static func make(session: AppSession, networkService: any NetworkService,
                 baseURL: BaseURL, catalogContainer: CatalogContainer,
                 socket: any Socket) -> some View { ... }

// Do — take the session; read fields off it:
static func make(session: AppSession) -> some View {
    HomeNavigationHost(session: session) // reads session.catalogContainer, session.networkService, …
}
```

Local state (a selected id, a launch mode) and closures (navigation callbacks) stay explicit — they are per-invocation, not session-lived. A presentation **host** view that needs `@State` holds the `session` too, and threads it down to the composers it calls — not a re-listed set of fields.

## Convenience initializers for leaf dependencies

Small, stateless, frequently-reused **leaf** dependencies — an SSE client, a remote service, a per-feature repository — are **not** held in the session. Build them on demand from the session via an `extension`, so composers stay thin and the wiring lives in one place:

```swift
extension AppSession {
    func makeOrderService() -> RemoteOrderService {
        RemoteOrderService(networkService: networkService)
    }

    func makeEventStream() -> any EventStream {
        // Built from the session's one baseURL + its live bearer adapter.
        EventStreamLive(baseURL: baseURL, adapters: [bearerAdapter])
    }
}
```

A composer then calls `session.makeOrderService()` instead of re-deriving it inline. These are pure factories over the session — they take no extra state and store nothing. This is the dividing line: **held** = live session state (in the session, via a container); **convenience-initialized** = stateless leaf deps (an `extension` factory, built per use).

## Don't unit-test composition

Composition is wiring + navigation, so there is nothing to unit-test: a test that only asserts "the graph builds" or "this field is wired" is low value and churns on every refactor. More importantly, the *temptation* to write a composition test is a signal — if a composer has behavior worth asserting, that behavior is logic that leaked into composition. Move it to a use case, view model, or repository, and test it there. Keep the composition layer test-free.

## Navigation belongs to composition, only

**Composition is the ONLY place it is okay to infer the navigation tree.** A composed view defers navigation upward: it surfaces a navigation request and lets the composer decide what comes next by composing the destination. This bubbles navigation out of the feature and up to the app — the only layer that can see every feature.

```swift
enum ProductListViewComposer {
    @MainActor
    static func make(session: AppSession) -> ProductListView {
        let repository = DefaultProductRepository(
            networkService: session.networkService,
            store: session.catalogContainer.store
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

`ProductListView` knows nothing about `ProductDetailsPage` or `SupportView`. It emits a `navigationRequest`; the composer maps each case to the destination composer (passing `session` + the local state each needs). The view-architecture skill dictates how the view surfaces that request.

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

## Inputs, in one place

- **App session (the scope)** — the signed-in pure-holder value (`AppSession`) that owns the session-lived dependencies: the session, the shared clients, and the feature containers. Authenticated dependencies cannot be composed without it. Built by its builder; never composes in its own `init`.
- **Feature containers** — `Sendable` per-feature holders of scope-lived state (a socket subscription, an in-memory store), **held by the session** and read off it (not a separate composer parameter). They hold no functions and no init logic; mutable state sits behind a [`Mutex`](https://developer.apple.com/documentation/Synchronization/Mutex). See the `ios-container` skill.
- **Local state** — state inferable only from a local action or local state, **not** global state. A navigation phase or a selected id is the canonical example.
- **Closures** — navigation callbacks the composer wires to the destination it composes.

## See also

- **`ios-container` skill** — feature containers that hold scope-lived state, created on auth and torn down with the scope. Held by the app session.
