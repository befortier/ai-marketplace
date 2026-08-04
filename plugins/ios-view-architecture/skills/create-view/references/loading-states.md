# Loading States

Use a generic loading state enum for async data that drives view rendering. If your project already provides a loading state type, use that. Otherwise, add one with the **`ios-create-loading-state`** skill — don't roll your own per feature.

## Contents

- [`LoadingState<Loading, Completed>`](#loadingstateloading-completed)
- [`FailableLoadingState<Loading, Success, Failure>`](#failableloadingstateloading-success-failure)
- [The Failure Payload Is a Marker; Copy Lives in the View](#the-failure-payload-is-a-marker-copy-lives-in-the-view)
- [In-Place Success Mutation: `successValue`](#in-place-success-mutation-successvalue)
- [Which to Use](#which-to-use)

> **Reconcile, don't reinvent.** The canonical `LoadingState` and `FailableLoadingState` types ship from the `ios-create-loading-state` skill. This reference shows how a *view* renders them; that skill owns the type definitions, convenience initializers, and `map`/`flatMap` helpers. Cross-reference it rather than copying the enums.

## `LoadingState<Loading, Completed>`

For data that loads once and either succeeds or is in-flight. The **parent/composer is responsible for rendering any failure** — the component itself only models loading vs. completed:

```swift
public enum LoadingState<Loading, Completed> {
    case loading(Loading)
    case completed(Completed)
}
```

```swift
@Published private(set) var viewState: LoadingState<Nothing, MyContentViewState>
```

```swift
// In view:
switch viewModel.viewState {
case .loading:
    SkeletonView()
case .completed(let viewState):
    MyContentView(viewState: viewState)
}
```

> `.loading` and `.completed` are convenience statics available when `Loading == Nothing` / `Completed == Nothing` (or `Void`). See `ios-create-loading-state`.

## `FailableLoadingState<Loading, Success, Failure>`

For data that can **fail** and be retried. This is the type to reach for whenever a load or action can realistically error — and most network-backed screens can.

```swift
public enum FailableLoadingState<Loading, Success, Failure: Error> {
    case loading(Loading)
    case success(Success)
    case failure(Failure)
}
```

The `Failure` payload is a **marker**, not copy:

```swift
/// Marker — the load failed; the error view owns the copy.
public struct LoadFailure: Error, Hashable {}
```

```swift
@Published private(set) var viewState: FailableLoadingState<Nothing, MyContentViewState, LoadFailure>
```

The view renders **all three** cases — the `.failure` case is a first-class, renderable state, not an afterthought:

```swift
switch viewModel.viewState {
case .loading:
    SkeletonView()
case .success(let content):
    MyContentView(viewState: content)
case .failure:
    ErrorView(onRetry: { loadAttempt += 1 })   // fresh .task(id:) identity re-runs start()
}
```

### The Failure Payload Is a Marker; Copy Lives in the View

Error copy does not travel through the mapper as view state. It renders inline in the error view, localized via the package's string catalog:

```swift
// Don't — copy carried in the failure payload
public struct ErrorViewState: Sendable, Hashable, Error {
    public let title: String
    public let message: String
    public let retryButtonTitle: String
}

// Do — marker failure; the error view owns its catalog-localized copy
struct ErrorView: View {
    let onRetry: @MainActor () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("Something went wrong", bundle: .module)
                .font(.headline)
            Button(String(localized: "Try Again", bundle: .module), action: onRetry)
        }
    }
}
```

If distinct failures need distinct UI, make the marker an enum (`enum LoadFailure: Error, Hashable { case offline, notFound }`) — still no copy in the payload. See [view-state.md](view-state.md#the-failure-case-is-a-marker) for where the marker lives in the hierarchy.

### In-Place Success Mutation: `successValue`

`successValue` is the sanctioned way to mutate `.success` sub-state in place. It ships with the loading-state type (see `ios-create-loading-state`): a settable accessor that reads and writes the success payload and is a no-op in the other cases:

```swift
extension FailableLoadingState {
    public var successValue: Success? {
        get { if case .success(let value) = self { value } else { nil } }
        set {
            guard case .success = self, let newValue else { return }
            self = .success(newValue)
        }
    }
}
```

```swift
// ViewModel — flip a flag on the loaded state without unwrapping the enum
viewState.successValue?.isPendingAction = true
```

No `guard case .success` dance in handlers; the setter reassigns the enum, so `@Published` observes the change.

## Which to Use

| Scenario | Type |
|----------|------|
| Loads once, no retry, parent handles failure | `LoadingState` |
| Can fail and be retried; component renders its own error | `FailableLoadingState` |
| Multiple independent async sections | Separate published properties per section |

A screen that can fail to load — or whose primary action can fail — uses `FailableLoadingState` and renders the `.failure` case. Reaching for `LoadingState` on a network-backed screen and silently dropping errors is the mistake the fail state exists to prevent.
