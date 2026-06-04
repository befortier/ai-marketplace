# ViewModel

The ViewModel is the single source of truth for a feature. It owns all published state and handles all actions from views.

## Contents

- [Core Shape](#core-shape)
- [Nesting Convention](#nesting-convention)
- [Dependencies](#dependencies)
- [Action Handling](#action-handling)
- [State Mutation](#state-mutation)
- [Observing Stores via AsyncStream](#observing-stores-via-asyncstream)
- [Logging failures](#logging-failures)
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
    onFinished: @MainActor @escaping (NavigationRequest) -> Void
) { ... }
```

The ViewModel orchestrates; it doesn't implement. Business logic belongs in use cases, mapping belongs in mappers, tracking belongs in recorders.

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

## Logging failures

When a load or action attempt fails, log the failure so it stays observable. If a logging-failure skill exists, invoke it and follow its pattern; otherwise mirror how other view models in this codebase already handle failures. A dedicated logging pattern will be defined later — keep this light for now and stay consistent with what's already there.

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
