# Loading States

Use a generic loading state enum for async data that drives view rendering. If your project already provides a loading state type, use that. Otherwise, add one with the **`ios-create-loading-state`** skill — don't roll your own per feature.

## Contents

- [`LoadingState<Loading, Completed>`](#loadingstateloading-completed)
- [`FailableLoadingState<Loading, Success, Failure>`](#failableloadingstateloading-success-failure)
- [Which to Use](#which-to-use)
- [Logging the Failure](#logging-the-failure)
- [Common Mistakes](#common-mistakes)

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

For data that can **fail** and be retried. This is the type to reach for whenever a load or action can realistically error — and most network-backed screens can. It carries a real, typed failure:

```swift
public enum FailableLoadingState<Loading, Success, Failure: Error> {
    case loading(Loading)
    case success(Success)
    case failure(Failure)
}
```

The `Failure` parameter carries a **renderable** error view state — the ViewModel maps its typed error into presentation data before wrapping it, exactly as it maps success:

```swift
@Published private(set) var viewState: FailableLoadingState<Nothing, MyContentViewState, ErrorViewState>
```

The view renders **all three** cases — the `.failure` case is a first-class, renderable state, not an afterthought:

```swift
switch viewModel.viewState {
case .loading:
    SkeletonView()
case .success(let content):
    MyContentView(viewState: content)
case .failure(let error):
    ErrorView(
        viewState: error,
        onRetry: { Task { await viewModel.retry() } }
    )
}
```

> `ErrorViewState` must conform to `Error` to slot into the `Failure` position (`FailableLoadingState<Loading, Success, Failure: Error>`). Conform it explicitly. If you prefer to keep the typed domain error in the enum, use `FailableLoadingState<Nothing, MyContentViewState, LoadError>` instead and map `LoadError` → `ErrorViewState` inside the view via the Mapper — but carrying the renderable state directly keeps the view free of mapping logic.

### The failure case is a real, renderable view state

Don't treat `.failure` as a dead end that just shows a generic spinner-gone-wrong. Map the failure into its own renderable view state — exactly like you map success — so the view shows something specific and actionable:

```swift
// A renderable failure — same discipline as any other view state:
// Sendable, Hashable, no domain types, only what the view draws.
// Conforms to Error so it fits the FailableLoadingState `Failure` slot.
public struct ErrorViewState: Sendable, Hashable, Error {
    public let title: String
    public let message: String
    public let retryButtonTitle: String
}
```

```swift
struct ErrorView: View {
    let viewState: ErrorViewState
    let onRetry: @MainActor () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text(viewState.title).font(.headline)
            Text(viewState.message).multilineTextAlignment(.center)
            Button(viewState.retryButtonTitle, action: onRetry)
        }
    }
}
```

The domain error is mapped to `ErrorViewState` in the Mapper layer (see [mapper.md](mapper.md)) — the view never inspects a raw error, just as it never inspects a raw domain model. See [view-state.md](view-state.md#the-failure-case-is-a-view-state) for where the failure view state lives in the hierarchy.

## Which to Use

| Scenario | Type |
|----------|------|
| Loads once, no retry, parent handles failure | `LoadingState` |
| Can fail and be retried; component renders its own error | `FailableLoadingState` |
| Multiple independent async sections | Separate published properties per section |

A screen that can fail to load — or whose primary action can fail — uses `FailableLoadingState` and renders the `.failure` case. Reaching for `LoadingState` on a network-backed screen and silently dropping errors is the mistake the fail state exists to prevent.

## Logging the Failure

Producing the `.failure` state is only half the job: when a load or action fails, the ViewModel **also logs the failure** so it's observable (consistent with the DEBUG recording / `LogStore` approach used elsewhere). The renderable `.failure` view state is for the user; the log entry is for the developer. See [view-model.md](view-model.md#logging-failed-attempts) for the pattern.

## Common Mistakes

**Rolling a custom loading enum per feature** — prefer the shared `LoadingState` / `FailableLoadingState` from `ios-create-loading-state` for consistency and to avoid reinventing error handling in every feature.

**Storing domain model in loading state** — the loading state should wrap the *view state*, not the domain model. Map first, then wrap. This applies to the failure case too: wrap a renderable `ErrorViewState`, not a raw `Error`, when you want the failure to carry presentation data.

**Treating `.failure` as un-renderable** — `.failure` is a real case the view must handle. Render a specific error view with a retry affordance; don't fall through to a blank or perpetual-loading screen.

**Failing silently** — surfacing the error to the user without also logging it leaves failures invisible to developers. Always do both (see [view-model.md](view-model.md#logging-failed-attempts)).
