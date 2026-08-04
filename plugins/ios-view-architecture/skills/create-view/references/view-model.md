# ViewModel

The ViewModel is the single source of truth for a feature. It owns the view state and handles all actions from views.

## Contents

- [Core Shape](#core-shape)
- [`viewState` Is the Only Stored State](#viewstate-is-the-only-stored-state)
- [Nesting Convention](#nesting-convention)
- [Dependencies](#dependencies)
- [Handlers Are Async; the View Owns Task Lifetimes](#handlers-are-async-the-view-owns-task-lifetimes)
- [Action Handling](#action-handling)
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
    @Published private(set) var viewState: FailableLoadingState<Nothing, MyContentViewState, LoadError> = .loading

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
| A derived value | In the Mapper — computed there and **set** on the view state; view states carry set values, never computed vars |
| Something a handler needs | In the action payload — payloads are complete (see [view.md](view.md)) |
| A task lifetime | In the view — `.task` / `Task { }` |

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
    onAction: @escaping (MyFeatureAction) async -> Void
) { ... }
```

The ViewModel orchestrates; it doesn't implement. Business logic belongs in use cases, mapping belongs in mappers, tracking belongs in recorders.

## Handlers Are Async; the View Owns Task Lifetimes

Every action handler is `async`, and the ViewModel never spawns `Task { }`. The view fires unstructured tasks for actions and runs the observation loop from `.task`:

```swift
// View — the view owns every task lifetime
Button("Retry") { Task { await viewModel.retry() } }

.task { await viewModel.start() }
```

## Action Handling

One `async` handler per view layer — mirrors the action bubbling hierarchy. Two artifacts:

**1. The view passes the loaded view state into the handler:**

```swift
// Root view, .success case
MyContentView(viewState: loadedViewState) { action in
    Task { await viewModel.handleContentAction(action, viewState: loadedViewState) }
}
```

**2. Handlers pull what they need off the action's associated values** — payloads are complete, often literally the row view state (see [view.md](view.md)):

```swift
public func handleContentAction(_ action: ContentAction, viewState: MyContentViewState) async {
    switch action {
    case .rowTapped(let rowTappedInfo):
        analyticsRecorder.rowTapped(rowTappedInfo.id)
        await onAction(.rowTapped(rowTappedInfo.type, rowTappedInfo.id))
    }
}
```

The handler never re-derives state from the published enum — the loaded view state comes in from the view, and the action's associated value carries how to respond.

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

When the ViewModel receives live data from a repository or store, **prefer AsyncStream observation over Combine**. `start()` is an async method the view runs from `.task` — it sets `.loading`, then maps every emission into `viewState`:

```swift
public func start() async {
    viewState = .loading
    do {
        for await model in try await getModelStream() {
            guard !Task.isCancelled else { return }
            viewState = .success(try mapper.map(model))
        }
        viewState = .failure(.streamEnded)   // stream ended unexpectedly
    } catch {
        guard !Task.isCancelled else { return }
        viewState = .failure(.loadFailed)
    }
}
```

A throw or an unexpected stream end both land in `.failure` (see [loading-states.md](loading-states.md) for how the view renders it). No stored task, no `deinit` — cancellation is the view's job.

The ViewModel consumes exactly **one** stream. When a view depends on more than one source, the join happens in the use case, not here — see the `ios-join-async-stream` skill.

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
| `viewState` is the only stored state | Everything else is mapper-set, action-carried, or view-owned |
| `@Published private(set)` | Views read state; only ViewModel writes it |
| Handlers are `async`; no `Task { }` in the ViewModel | The view owns task lifetimes (`Task { }` per action, `.task` for observation) |
| AsyncStream for store observation | Preferred over Combine — composable, cancellable, no `AnyCancellable` storage |
| One stream per ViewModel; joins live in use cases | See the `ios-join-async-stream` skill |
| Throw or stream end → `.failure` | A silent stop is indistinguishable from loading forever |
| Dependencies are `let` | Immutable after init |
| `final class` | Not designed for subclassing |
