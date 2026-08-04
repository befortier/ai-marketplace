# View State

View state is an immutable value type passed into views. It represents exactly what the view needs to render — nothing more.

## Contents

- [Core Shape](#core-shape)
- [`let` vs `var`](#let-vs-var)
- [Polymorphic States](#polymorphic-states)
- [Nested Hierarchy](#nested-hierarchy)
- [Hoisting Non-Content State](#hoisting-non-content-state)
- [The Failure Case Is a View State](#the-failure-case-is-a-view-state)
- [Rules](#rules)

## Core Shape

```swift
public struct MyViewState: Sendable, Hashable {
    public let title: String
    public let isButtonEnabled: Bool
    public var isExpanded: Bool   // var only if the view owns this transition
}
```

## `let` vs `var`

| Use `let` | Use `var` |
|-----------|-----------|
| Data from outside (titles, counts, images) | Locally-owned UI transitions (expanded/collapsed, paused) |
| Anything the ViewModel controls | State the view manages internally before surfacing as an action |

When in doubt, use `let`. If the ViewModel needs to know about it, it should be an action, not a `var`.

## Polymorphic States

Use an enum when a view can render meaningfully different layouts:

```swift
public enum FooterViewState: Sendable, Hashable {
    case progress(ProgressViewState)
    case cta(CTAViewState)
}
```

## Nested Hierarchy

Complex screens compose smaller view states:

```swift
public struct ScreenViewState: Sendable, Hashable {
    public let header: HeaderViewState
    public let content: ContentViewState
    public var footer: FooterViewState?
}
```

Each sub-view receives only its slice — not the whole screen state.

## Hoisting Non-Content State

When a feature has data that shouldn't be part of `ContentViewState`, hoist it to a parent struct. There are two reasons something belongs there instead:

1. **Not `Hashable`** — e.g. a rich media asset. Technical constraint; can't conform.
2. **Not needed to render** — e.g. `AnalyticsContext`. Even if `Hashable`, it belongs to the composing layer. The content view shouldn't know about it.

```swift
// Top-level: Sendable only — holds rendering-unrelated data + content
public struct MyFeatureViewState: Sendable {
    public let analyticsContext: AnalyticsContext // Not needed to render
    public var content: MyFeatureContentViewState
}

// Content: Sendable + Hashable — exactly what the stateless view needs, nothing more
public struct MyFeatureContentViewState: Sendable, Hashable {
    public let header: HeaderViewState
    public var footer: FooterViewState?
}
```

The ViewModel holds `MyFeatureViewState`. The content view receives only `MyFeatureContentViewState`.

```swift
// ViewModel publishes top-level
@Published private(set) var viewState: MyFeatureViewState

// Top-level view passes only the content slice down
MyFeatureContentView(
    viewState: viewModel.viewState.content,
    onAction: viewModel.onContentAction
)
```

The naming convention follows this split: `MyFeatureViewState` wraps everything; `MyFeatureContentViewState` is what the stateless content view renders.

## The Failure Case Is a View State

When a feature can fail to load (or its primary action can fail), the failure is **not** just an absence of content — it's a real state the view renders. Give it the same treatment as any other view state: a `Sendable, Hashable` value type with exactly the fields the error UI draws, and no domain or `Error` types.

```swift
// Conforms to Error so it can sit in the FailableLoadingState `Failure` slot.
public struct ErrorViewState: Sendable, Hashable, Error {
    public let title: String
    public let message: String
    public let retryButtonTitle: String
}
```

The feature's published state then wraps loading, success, and this renderable failure together via `FailableLoadingState` (see [loading-states.md](loading-states.md#failableloadingstateloading-success-failure)):

```swift
@Published private(set) var viewState: FailableLoadingState<Nothing, MyFeatureContentViewState, ErrorViewState>
```

The domain error is mapped into `ErrorViewState` in the Mapper layer — the view switches on the loading state and renders the `.failure` case with a real, specific error view, never a blank or perpetually-loading screen. See [loading-states.md](loading-states.md#the-failure-case-is-a-real-renderable-view-state) for how the view renders it.

## Rules

| Rule | Why |
|------|-----|
| Conforms to `Sendable, Hashable` | Thread safety; enables diffing and use in collections |
| Value type (struct or enum) | Copies on assignment; no shared mutable state |
| No business logic or computed side effects | Views are for rendering, not logic |
| No raw API/domain types | Domain models are transformed in the Mapper layer |
