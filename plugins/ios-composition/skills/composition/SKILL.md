---
name: composition
description: Composes a feature's dependency graph and infers the app's navigation tree in the main app target or a dedicated AppComposition package, from feature containers, app scopes, and local state — packages defer composition and navigation upward. Composition is wiring + navigation only — no business logic, analytics, or network calls. Use when composing dependencies, wiring up a feature, building the composition root, inferring the navigation tree, adding a feature to the app graph, deciding what belongs in the main app / AppComposition versus a feature package, or when discussing composers, feature containers, app scopes, local state in composition, or why packages defer navigation to the app.
---

# Composition

Composition is where a feature's raw dependencies are assembled into a working graph and where the app's **navigation tree** is decided. It lives in **one place** — the main app target, or a dedicated `AppComposition` package — and nowhere else. Feature packages expose their raw initializers and stay ignorant of how they are wired or navigated; the app composes them.

## The rule in one line

Packages expose raw initializers; the **app** (or `AppComposition`) takes in feature containers, app scopes, and local state, composes the dependencies, and infers the navigation graph — and does **nothing else**.

## What composition is — and is not

Composition is **only two things**:

1. **Composition of dependencies** — taking the raw pieces and constructing the wired graph.
2. **The navigation graph** — deciding how composed screens relate (the navigation tree).

Composition is **not** any of the following. If you find one of these in a composer, it belongs in a use case, a repository, a service, or a view model — not here:

- **No business logic.** No decisions, no branching on domain rules.
- **No analytics.** No event firing, no tracking.
- **No network calls.** No fetching, no I/O. A composer constructs the thing that makes the call; it never makes the call itself.

## Who composes what

### Packages do NOT compose

A feature package exposes its **raw initializers** and abstractions. It does not build its own graph, does not reach for the dependencies of other packages, and does not know how it is wired. It is handed everything it needs.

### The app (or `AppComposition`) composes

Composition takes in three kinds of input and produces two kinds of output.

**Inputs:**

- **Feature containers** — the per-feature holders of scope-lived state (e.g. a socket subscription, an in-memory store) that the app owns and tears down. (See the `ios-container` skill.)
- **App scopes** — the signed-in / signed-out lifecycle scopes that own session-lived dependencies. The scope authority is this repo's `ios/Packages/AppComposition/CLAUDE.md` — the type-grounded companion for the scope and app-bootstrap → data-bootstrap rules that feed composition. (The stateless `Composer` enum factory pattern lives in the `swift-modularization` scopes-and-containers reference.)
- **Local state** — state that is only inferable from a local action or local state, **not** global state. Navigation phase (loading / authenticated / signed-out) is the canonical example: it is driven by a local `@State` transition, not by a global flag.

**Outputs:**

- **Composed dependencies** — the wired graph of abstractions, ready to inject into the UI.
- **A navigation tree** — the relationship between composed screens.

### Navigation belongs to the app, only

**Composition is the ONLY place it is okay to infer the navigation graph.** Feature packages **defer navigation to the main app** — a screen does not decide what comes after it. The app, which alone can see every feature, is the only layer with the knowledge to assemble the navigation tree. This is why navigation inference is allowed here and forbidden everywhere else.

## Worked example (grounded in this repo's `AppComposition`)

The `AppComposition` package is the composition root. The `@main` target calls `AppComposition.makeRootView()` and owns no graph itself.

### The composer takes inputs and returns composed dependencies

`AuthenticatedComposition` is the composer for the authenticated graph. It takes the **app scope token** (`AppSession`) as input and returns **composed dependencies** — `NetworkService`, `WebsocketClient`, `ChatService`, `ConnectionsService` — as abstractions:

```swift
/// The authenticated main-app composition root — the "lock".
struct AuthenticatedComposition {
    let session: AppSession
    let networkService: any NetworkService
    let websocketClient: any WebsocketClient
    let chatService: any ChatService
    let connectionsService: any ConnectionsService

    @MainActor
    init(session: AppSession) {
        self.session = session

        // Pure wiring: build the bearer HTTP stack from the session token.
        let headers = HeaderConfiguration(bearerToken: { session.token })
        let bearerClient = HTTPClient(
            adapters: [BearerRequestAdapter(configuration: headers)],
            policy: BasicRetryPolicy()
        )
        self.networkService = NetworkServiceLive(client: bearerClient, jsonDecoder: JSONDecoder())
        self.websocketClient = WebsocketClientLive()
        self.chatService  = SessionGatedChatService(/* … */)        // placeholder
        self.connectionsService = SessionGatedConnectionsService(/* … */)  // placeholder
    }
}
```

> This example is simplified. The real `AuthenticatedComposition.swift` uses the `SessionGatedChatService` / `SessionGatedConnectionsService` placeholders shown above (pending the Chat (jd-9pm) and Connections (jd-eam) Live services), and elides the DEBUG `RecordingNetworkClient` / `RecordingWebsocketClient` decorators that wrap the clients in debug builds. The wiring shape is what matters here.

Notice: it **constructs** the services that make network calls; it never makes a call itself. There is no business logic, no analytics. Just wiring — the first allowed job.

Notice too the **scope-as-input**: the initializer *requires* an `AppSession`, and the only producer of one is `Bootstrap.loadSession()`. The authenticated dependencies literally cannot be composed without the scope token in hand.

### The local state drives the navigation tree

`BootstrapView` is where the **navigation tree** is inferred — the second allowed job. It switches on **local state** (a `@State` phase that is inferable only from the local session-restore action, not a global flag) and assembles the tree: which composed graph hands which services to which screen.

```swift
struct BootstrapView: View {
    let bootstrap: Bootstrap
    @State private var phase: Phase = .loading   // local state — not a global flag

    enum Phase { case loading; case authenticated(AppSession); case signedOut }

    var body: some View {
        Group {
            switch phase {
            case .loading:
                ProgressView()
            case .authenticated(let session):
                // Compose behind the gate, then hand composed deps to the UI.
                let graph = AuthenticatedComposition(session: session)
                RootView(
                    chatService: graph.chatService,
                    connectionsService: graph.connectionsService,
                    onLogout: { await bootstrap.logout(); phase = .signedOut }
                )
            case .signedOut:
                SignedOutView()
            }
        }
        .task {
            // The local action that produces the local state the tree switches on.
            phase = await bootstrap.loadSession().map(Phase.authenticated) ?? .signedOut
        }
    }
}
```

`RootView` — the composed screen — receives its dependencies by injection and **defers its own navigation upward**: it knows nothing about what precedes or follows it. The app decided that.

### Packages just expose raw initializers

`RootView` lives in `AppComposition` and takes its dependencies in its initializer — it does not compose them, does not fetch them, does not decide the graph around it:

```swift
public struct RootView: View {
    public init(
        chatService: any ChatService,
        connectionsService: any ConnectionsService,
        onLogout: @escaping @MainActor () async -> Void
    ) { /* store and inject — no wiring, no navigation decisions */ }
}
```

`Bootstrap` is the unauthenticated composer — it exposes `make()` (build the signed-out graph) and `loadSession()` (the only producer of the scope token). It holds **no** authenticated dependencies; those exist only in `AuthenticatedComposition`, behind the scope gate.

## Key Rules

1. **Packages do not compose.** They expose raw initializers and abstractions; they are handed everything they need.
2. **Composition lives in one place** — the main app target or a dedicated `AppComposition` package. Never in a feature package.
3. **Composition takes feature containers + app scopes + local state.** Local state means state inferable from a local action/state, not global state.
4. **Composition returns composed dependencies + a navigation tree.**
5. **Navigation is inferred only in composition.** Packages defer navigation to the app — the only layer that can see every feature.
6. **Composition is wiring + navigation only.** No business logic, no analytics, no network calls. A composer builds the thing that calls; it never calls.

## Checklist

- [ ] The feature package exposes raw initializers and abstractions — it composes nothing
- [ ] All composition lives in the app target or `AppComposition`, not in a feature package
- [ ] The composer's inputs are feature containers, app scopes, and/or local state (local, not global)
- [ ] "Local state" used for navigation is inferable from a local action/state, not a global flag
- [ ] The composer returns composed dependencies (as abstractions) and/or a navigation tree
- [ ] The navigation graph is inferred only here; screens defer navigation upward
- [ ] No business logic in the composer
- [ ] No analytics in the composer
- [ ] No network calls in the composer (it constructs the caller; it does not call)

## See also

- **`ios/Packages/AppComposition/CLAUDE.md` (Scope/Bootstrap docs)** — the in-repo, type-grounded authority for **app scopes** and the **app-bootstrap → data-bootstrap** order that feed composition. It is the source of truth for the signed-in / signed-out scope rules (`Sendable`, no functions, no mutable state) and the key/lock session gate. Consult it for how scopes actually land in this repo; consult this skill for the general composition pattern.
- **`ios-container` skill** — feature containers that hold scope-lived state (a socket subscription, an in-memory store), created on auth and torn down with the scope. These are a primary input to composition.
- **`swift-modularization` skill, scopes-and-containers reference** — the stateless `Composer` enum factory pattern (`enum Foo` + `static func make(...)`) that builds and forgets. This is where that factory pattern lives; for the app scopes themselves, defer to `AppComposition/CLAUDE.md` above.
- **This repo's `AppComposition` package** — `AppComposition.swift`, `Bootstrap.swift`, `AuthenticatedComposition.swift`, `BootstrapView.swift`, `RootView.swift` ground every example above.
