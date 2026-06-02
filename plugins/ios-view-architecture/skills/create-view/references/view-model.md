# ViewModel

The ViewModel is the single source of truth for a feature. It owns all published state and handles all actions from views.

## Contents

- [Core Shape](#core-shape)
- [Nesting Convention](#nesting-convention)
- [Dependencies](#dependencies)
- [Action Handling](#action-handling)
- [State Mutation](#state-mutation)
- [Observing Stores via AsyncStream](#observing-stores-via-asyncstream)
- [Loading and Failing](#loading-and-failing)
- [Logging Failed Attempts](#logging-failed-attempts)
- [Exit Pattern](#exit-pattern)
- [Rules](#rules)

## Core Shape

```swift
@MainActor
public final class ViewModel: ObservableObject {
    @Published private(set) var viewState: MyViewState

    private let dependency: any MyDependency
    private let onFinished: @MainActor (Result) -> Void

    public init(
        dependency: any MyDependency,
        onFinished: @MainActor @escaping (Result) -> Void
    ) {
        self.dependency = dependency
        self.onFinished = onFinished
        self.viewState = .initial
    }
}
```

## Nesting Convention

ViewModels are nested inside their view when they are private to it:

```swift
extension MyFeatureView {
    @MainActor
    public final class ViewModel: ObservableObject { ... }
}
```

Use a standalone file when the ViewModel is instantiated externally (e.g., by a Composer).

## Dependencies

Inject all meaningful concerns as protocol dependencies — use cases, analytics, mappers, and any other collaborators. This keeps the ViewModel light and each concern independently testable.

```swift
public init(
    fetchData: any FetchDataUseCase,
    mapper: any MyViewStateMapper,
    analyticsRecorder: any MyAnalyticsRecording,
    logger: any FailureLogging,
    onFinished: @MainActor @escaping (NavigationRequest) -> Void
) { ... }
```

The ViewModel orchestrates; it doesn't implement. Business logic belongs in use cases, mapping belongs in mappers, tracking belongs in recorders, and failure logging belongs in the injected `FailureLogging` seam (see [Logging Failed Attempts](#logging-failed-attempts)).

## Action Handling

One handler per view layer — mirrors the action bubbling hierarchy:

```swift
public func onHeaderAction(_ action: HeaderAction) {
    switch action {
    case .closeTapped: onFinished(.dismissed)
    case .helpTapped: viewState.isHelpPresented = true
    }
}

public func onContentAction(_ action: ContentAction) {
    switch action {
    case .itemTapped(let id): navigate(to: id)
    }
}
```

## State Mutation

Always replace, never mutate nested structs in-place through a published property chain:

```swift
// Copy, modify, reassign
var updated = viewState
updated.header.isVisible = true
viewState = updated

// Direct nested mutation — SwiftUI may not observe this
viewState.header.isVisible = true
```

## Observing Stores via AsyncStream

When the ViewModel receives live data from a repository or store, **prefer AsyncStream observation over Combine**. Start a `Task` in `init` (or a `load()` method) that loops over the stream and updates `viewState`.

```swift
private var observationTask: Task<Void, Never>?

public init(
    repository: any MyRepository,
    mapper: any MyViewStateMapper,
    onFinished: @MainActor @escaping (NavigationRequest) -> Void
) {
    self.repository = repository
    self.mapper = mapper
    self.onFinished = onFinished
    self.viewState = .loading
    observationTask = Task { await observe() }
}

deinit {
    observationTask?.cancel()
}

private func observe() async {
    let stream = await repository.stream(replayCurrentValue: true)
    for await model in stream {
        guard let model else { continue }
        viewState = mapper.map(model)
    }
}
```

### Combining Multiple Streams

When a view depends on more than one store, use `combineLatest` from `swift-async-algorithms` to merge them. Use `chain` to prepend an initial value to a stream that may not have emitted yet — this ensures `combineLatest` receives a value from both sides immediately rather than waiting.

```swift
import AsyncAlgorithms

private func observe() async {
    let itemStream = await itemRepository.stream(replayCurrentValue: true)
    let likedStream = await likedRepository.stream(replayCurrentValue: false)

    for await (item, liked) in combineLatest(
        itemStream,
        chain(
            AsyncStream { $0.yield(LikedState(isLiked: false)); $0.finish() },
            likedStream
        )
    ) {
        guard let item else { continue }
        viewState = mapper.map(item, liked)
    }
}
```

`chain` here provides `LikedState(isLiked: false)` as an initial value so `combineLatest` can start emitting even before the liked store has data. The mapper receives both values and produces the view state.

> `swift-async-algorithms` is required for `combineLatest` and `chain`. Add it to `Package.swift` if not already present.

## Loading and Failing

When a load or action can fail, the ViewModel publishes a `FailableLoadingState` (see [loading-states.md](loading-states.md)) and drives it to `.failure` on error — never swallowing the error into a perpetual `.loading`.

```swift
// `Failure` carries the renderable ErrorViewState (see loading-states.md).
@Published private(set) var viewState: FailableLoadingState<Nothing, MyContentViewState, ErrorViewState>

public func load() async {
    viewState = .loading
    do {
        let model = try await fetchData()
        viewState = .success(try mapper.map(model))
    } catch {
        logger.logFailure(error, action: "load")        // observe the real error (see below)
        viewState = .failure(mapper.mapFailure(error))  // render the mapped state (see loading-states.md)
    }
}

public func retry() async {
    await load()
}
```

A failed attempt does **two** things: it surfaces a renderable `.failure` state to the user *and* logs the failure for developers. Neither replaces the other.

## Logging Failed Attempts

When a view model's load or action attempt fails, it **logs the failure** so failures are observable — consistent with the DEBUG recording / `LogStore` approach used elsewhere (the `DebugTools` package's `LogStore` / `DebugLogSink` seam, where recording decorators publish records that surface in the debug menu). Don't let a failure disappear into a `.failure` enum case with no trace; record it on the way out.

Inject the logging seam as a protocol dependency, exactly like any other collaborator — keep the ViewModel free of a hard dependency on a concrete logger so it stays testable and so release builds can install a no-op:

```swift
/// The pluggable seam the ViewModel logs failures to.
/// In DEBUG, backed by a sink into the shared `LogStore` (see DebugTools);
/// in release, a no-op so nothing is captured.
public protocol FailureLogging: Sendable {
    func logFailure(_ error: some Error, action: String)
}
```

```swift
public init(
    fetchData: any FetchDataUseCase,
    mapper: any MyViewStateMapper,
    logger: any FailureLogging,
    onFinished: @MainActor @escaping (NavigationRequest) -> Void
) { ... }
```

Every catch clause that ends in a `.failure` state — load *or* action — logs first:

```swift
public func onContentAction(_ action: ContentAction) {
    switch action {
    case .saveTapped:
        Task { await save() }
    }
}

private func save() async {
    do {
        try await saveChanges()
    } catch {
        logger.logFailure(error, action: "save")        // log the failed attempt
        viewState = .failure(mapper.mapFailure(error))  // and render the mapped error state
    }
}
```

| Rule | Why |
|------|-----|
| Log on every failed load/action attempt | Failures stay observable instead of vanishing into a `.failure` case |
| Inject logging as a protocol | Testable; release builds install a no-op, DEBUG routes to `LogStore` |
| Log *and* render | The log is for developers; the `.failure` view state is for the user |

> The `DebugTools` `LogStore` is a `@MainActor` ring buffer that conforms to `DebugLogSink`; recording decorators publish to it and the debug menu reads it. Implement `FailureLogging` the same way — a DEBUG-only recording seam injected at composition, backed by the shared `LogStore` (extend it or its sink to carry a failure record), and a no-op in release so nothing is captured. The point is the *pattern*: failures are recorded through an injected sink, observable in DEBUG, invisible (and zero-cost) in release.

## Exit Pattern

See [navigation-exit.md](navigation-exit.md) for the full navigation pattern.

## Rules

| Rule | Why |
|------|-----|
| `@MainActor` | All UI state mutations on main thread |
| `@Published private(set)` | Views read state; only ViewModel writes it |
| AsyncStream for store observation | Preferred over Combine — composable, cancellable, no `AnyCancellable` storage |
| `chain` for initial values | Ensures `combineLatest` emits immediately without waiting for all streams |
| Cancel task in `deinit` | Stops observation when ViewModel is deallocated |
| Dependencies are `let` | Immutable after init |
| `final class` | Not designed for subclassing |
| Log every failed load/action attempt | Failures stay observable (DEBUG recording / `LogStore`); never swallow into `.loading` |
| Drive failures to `.failure`, never silent `.loading` | The user sees a real, renderable error state with retry |
