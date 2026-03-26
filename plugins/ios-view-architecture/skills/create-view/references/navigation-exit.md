# Navigation & Exit Pattern

Features never navigate themselves. Navigation intent is bubbled outward via a closure and caught at the composition layer where the next screen can be composed and presented.

## NavigationRequest Enum

Define exit destinations as a `Sendable, Hashable` enum. Names describe **where to go**, not what happened — this distinguishes them from actions:

```swift
// NavigationRequest — destination-oriented
public enum MyFeatureNavigationRequest: Sendable, Hashable {
    case settings
    case detail(id: String)
    case support
}

// contrast with Action — event-oriented
enum Action {
    case primaryButtonTapped
    case closeTapped
}
```

## Bubbling Navigation Out

Navigation must not be coupled to the view or component. It is bubbled out via a closure on the ViewModel.

```swift
// ViewModel
private let onFinished: @MainActor (MyFeatureNavigationRequest) -> Void

func closeTapped() {
    onFinished(.support)
}
```

For cases where the host needs to be accessed for navigation — e.g. pushing onto a navigation stack or accessing a presenting controller — the ViewModel publishes the request and the top-level view observes and relays it through its own `onFinished` closure:

```swift
// ViewModel
@Published private(set) var pendingNavigation: MyFeatureNavigationRequest?

func closeTapped() {
    pendingNavigation = .support
}

// Top-level view
.onChange(of: viewModel.pendingNavigation) { request in
    guard let request else { return }
    viewModel.pendingNavigation = nil
    onFinished(request)
}
```

## Handling at the Composition Layer

Navigation requests bubble up to the composition layer where further screens are composed and navigated to. The feature has no knowledge of what happens next.

```swift
MyFeatureView(onFinished: { request in
    switch request {
    case .settings:
        navigator.push(SettingsComposer.make(...))
    case .detail(let id):
        navigator.push(DetailComposer.make(id: id, ...))
    case .support:
        navigator.present(SupportComposer.make(...))
    }
})
```

## Rules

| Rule | Why |
|------|-----|
| `NavigationRequest` conforms to `Sendable, Hashable` | May cross actor boundaries; enables use in collections |
| Names describe destinations, not events | Distinguishes navigation intent from action intent |
| Feature never navigates itself | Parent owns the navigation stack |
| Exhaustive `switch` at call site | All exit paths are handled explicitly |
