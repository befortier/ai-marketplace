# ViewModel

The ViewModel is the single source of truth for a feature. It owns the view state and handles all actions from views.

## Contents

- [Core Shape](#core-shape)
- [`viewState` Is the Only Stored State](#viewstate-is-the-only-stored-state)
- [Nesting Convention](#nesting-convention)
- [Dependencies](#dependencies)
- [Handlers Are Async; the View Owns Task Lifetimes](#handlers-are-async-the-view-owns-task-lifetimes)
- [Action Handling](#action-handling)
- [Actions Carry Their State Up](#actions-carry-their-state-up)
- [State Mutation](#state-mutation)
- [Observing Stores via AsyncStream](#observing-stores-via-asyncstream)
- [One-Time Effects](#one-time-effects)
- [Failures](#failures)
- [Exit Pattern](#exit-pattern)
- [Rules](#rules)

## Core Shape

```swift
@MainActor
public final class ViewModel: ObservableObject {
    @Published private(set) var viewState: FailableLoadingState<Nothing, MyContentViewState, LoadFailure> = .loading

    private let getModelStream: any GetModelStreamUseCase
    private let mapper: any MyViewStateMapper
    private let onAction: (MyFeatureAction) async -> Void

    public init(
        getModelStream: any GetModelStreamUseCase,
        mapper: any MyViewStateMapper,
        onAction: @escaping (MyFeatureAction) async -> Void
    ) {
        self.getModelStream = getModelStream
        self.mapper = mapper
        self.onAction = onAction
    }
}
```

`init` only stores dependencies — no work, no tasks. The view runs `start()`.

## `viewState` Is the Only Stored State

`viewState` is the ViewModel's **only** stored `var`. No stored tasks, no domain snapshots or dictionaries, no in-flight ID sets, no `didStart`/`retryEmitted` flags, no loggers.

About to add a second `var`? It is one of:

| It's actually… | Put it… |
|----------------|---------|
| Derivable from `viewState` | Nowhere — derive it where needed |
| Something a handler needs | In the action payload (see [Actions Carry Their State Up](#actions-carry-their-state-up)) |
| A task lifetime | In the view — `.task(id:)` / `Task { }` |

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

Inject all meaningful concerns as protocol dependencies — use cases, mappers, and any other collaborators. This keeps the ViewModel light and each concern independently testable.

```swift
public init(
    fetchData: any FetchDataUseCase,
    mapper: any MyViewStateMapper,
    onAction: @escaping (MyFeatureAction) async -> Void
) { ... }
```

The ViewModel orchestrates; it doesn't implement. Business logic belongs in use cases, mapping belongs in mappers.

## Handlers Are Async; the View Owns Task Lifetimes

Every action handler is `async`, and the ViewModel never spawns `Task { }`. The view fires unstructured tasks for actions and uses `.task(id:)` for observation that must restart:

```swift
// View — the view owns every task lifetime
Button("Retry") { Task { await viewModel.onRetryTapped() } }

.task(id: loadAttempt) { await viewModel.start() }   // new identity restarts start()
```

```swift
// Don't — ViewModel-owned task lifetime (a second stored property)
private var observationTask: Task<Void, Never>?
init(...) { observationTask = Task { await observe() } }
deinit { observationTask?.cancel() }

// Do — async methods; the view runs and cancels them
func start() async { ... }
func onRetryTapped() async { ... }
```

Retry re-runs `start()` through a fresh task identity (bump the `.task(id:)` value) — never by resuming or replacing a stored, cancelled task.

## Action Handling

One handler per view layer — mirrors the action bubbling hierarchy. Handlers are `async`:

```swift
public func onHeaderAction(_ action: HeaderAction) async {
    switch action {
    case .closeTapped: await onAction(.dismissed)
    case .helpTapped: viewState.successValue?.isHelpPresented = true
    }
}

public func onContentAction(_ action: ContentAction) async {
    switch action {
    case .rowTapped(let row): await onAction(.open(row.route))
    }
}
```

## Actions Carry Their State Up

Row and content events carry the view state they were rendered from — the handler never re-derives it:

```swift
enum ContentAction: Sendable {
    case rowTapped(RowViewState)
}

public func onContentAction(_ action: ContentAction) async {
    switch action {
    case .rowTapped(let row):
        viewState.successValue?.isPendingAction = true
        await onAction(.open(row.route))
        viewState.successValue?.isPendingAction = false
    }
}
```

- **Never `guard case .success`** to recover what a handler needs — the action payload already carries it. For in-place `.success` mutation, use the settable `successValue` accessor (see [loading-states.md](loading-states.md#in-place-success-mutation-successvalue)).
- **Never touch a domain model.** Rows carry pre-mapped routes from the Mapper (see [mapper.md](mapper.md#routes-resolve-at-map-time)); the handler forwards `row.route` instead of inspecting domain values.

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

For loading-state-wrapped state, `viewState.successValue?.flag = true` is the sanctioned shorthand — the accessor's setter reassigns the enum, so `@Published` observes it.

## Observing Stores via AsyncStream

When the ViewModel receives live data from a repository or store, **prefer AsyncStream observation over Combine**. `start()` is an async method the view runs via `.task(id:)` — it sets `.loading`, then maps every emission into `viewState`:

```swift
public func start() async {
    viewState = .loading
    do {
        for await model in try await getModelStream() {
            guard !Task.isCancelled else { return }
            viewState = .success(try mapper.map(model))
        }
        viewState = .failure(LoadFailure())   // stream ended unexpectedly
    } catch {
        guard !Task.isCancelled else { return }
        viewState = .failure(LoadFailure())
    }
}
```

A throw or an unexpected stream end both land in `.failure`. No stored task, no `deinit` — cancellation is the view's job.

### Combining Multiple Streams

When a view depends on more than one store, use `combineLatest` from `swift-async-algorithms` to merge them. Use `chain` to prepend an initial value to a stream that may not have emitted yet — this ensures `combineLatest` receives a value from both sides immediately rather than waiting.

```swift
import AsyncAlgorithms

public func start() async {
    viewState = .loading
    do {
        let itemStream = try await getItemStream()
        let likedStream = try await getLikedStream()

        for await (item, liked) in combineLatest(
            itemStream,
            chain(
                AsyncStream { $0.yield(LikedState(isLiked: false)); $0.finish() },
                likedStream
            )
        ) {
            guard !Task.isCancelled else { return }
            guard let item else { continue }
            viewState = .success(try mapper.map(item, liked))
        }
        viewState = .failure(LoadFailure())
    } catch {
        guard !Task.isCancelled else { return }
        viewState = .failure(LoadFailure())
    }
}
```

`chain` here provides `LikedState(isLiked: false)` as an initial value so `combineLatest` can start emitting even before the liked store has data. The mapper receives both values and produces the view state.

> `swift-async-algorithms` is required for `combineLatest` and `chain`. Add it to `Package.swift` if not already present.

## One-Time Effects

One-shot work tied to the loaded content — a seen watermark, a batch mark-seen mutation — fires from the loaded content view's `.onFirstAppear`, calling a ViewModel method that receives the loaded view state:

```swift
// Content view (rendered only in .success)
.onFirstAppear { Task { await viewModel.contentDidAppear(viewState) } }

// ViewModel
public func contentDidAppear(_ viewState: MyContentViewState) async {
    await markSeen(viewState.unseenIDs)
}
```

Once-ness is the **view's** guarantee. Never a `didStart` flag in the ViewModel (a second stored property), and never a once-guard buried inside the dependency being called.

## Failures

ViewModels don't hold loggers. A failed load or action becomes the `.failure` view state — that is the ViewModel's entire failure job. Diagnostics belong to the use case or store that failed, next to the failure.

## Exit Pattern

See [navigation-exit.md](navigation-exit.md): a single injected `onAction: (MyFeatureAction) async -> Void`, awaited from handlers — no published navigation state.

## Rules

| Rule | Why |
|------|-----|
| `@MainActor` | All UI state mutations on main thread |
| `viewState` is the only stored state | Everything else is derivable, action-carried, or view-owned |
| `@Published private(set)` | Views read state; only ViewModel writes it |
| Handlers are `async`; no `Task { }` in the ViewModel | The view owns task lifetimes (`Task { }` per action, `.task(id:)` for observation) |
| AsyncStream for store observation | Preferred over Combine — composable, cancellable, no `AnyCancellable` storage |
| `chain` for initial values | Ensures `combineLatest` emits immediately without waiting for all streams |
| Throw or stream end → `.failure` | A silent stop is indistinguishable from loading forever |
| Dependencies are `let` | Immutable after init |
| `final class` | Not designed for subclassing |
