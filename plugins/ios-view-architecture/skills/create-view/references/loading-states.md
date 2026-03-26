# Loading States

Use a generic loading state enum for async data that drives view rendering. If your project already provides a `LoadingState` type, use that. Otherwise, define one following this pattern.

## `LoadingState<Value>`

For data that loads once and either succeeds or is in-flight:

```swift
public enum LoadingState<Value: Sendable>: Sendable {
    case loading
    case completed(Value)
}
```

```swift
@Published private(set) var viewState: LoadingState<MyViewState>
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

## `FailableLoadingState<Value>`

For data that can fail and be retried:

```swift
public enum FailableLoadingState<Value: Sendable>: Sendable {
    case loading
    case completed(Value)
    case failed(Error)
}
```

```swift
@Published private(set) var viewState: FailableLoadingState<MyViewState>
```

```swift
switch viewModel.viewState {
case .loading:
    SkeletonView()
case .completed(let viewState):
    MyContentView(viewState: viewState)
case .failed:
    ErrorView { await viewModel.retry() }
}
```

## Which to Use

| Scenario | Type |
|----------|------|
| Loads once, no retry needed | `LoadingState` |
| Can fail and be retried | `FailableLoadingState` |
| Multiple independent async sections | Separate published properties per section |

## Common Mistakes

**Rolling a custom loading enum per feature** — prefer a single shared `LoadingState`/`FailableLoadingState` for consistency and to avoid reinventing error handling in every feature.

**Storing domain model in loading state** — the loading state should wrap the *view state*, not the domain model. Map first, then wrap.
