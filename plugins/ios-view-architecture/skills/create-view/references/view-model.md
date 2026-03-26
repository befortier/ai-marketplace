# ViewModel

The ViewModel is the single source of truth for a feature. It owns all published state and handles all actions from views.

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

## Exit Pattern

See [navigation-exit.md](navigation-exit.md) for the full navigation pattern.

## Rules

| Rule | Why |
|------|-----|
| `@MainActor` | All UI state mutations on main thread |
| `@Published private(set)` | Views read state; only ViewModel writes it |
| Dependencies are `let` | Immutable after init |
| `final class` | Not designed for subclassing |
