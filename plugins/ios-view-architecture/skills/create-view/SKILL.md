---
name: create-view
description: Scaffolds a new iOS SwiftUI feature following a consistent architecture — ViewModel, ViewState, Mapper, loading states, and navigation. Use when creating a new view, feature, or screen in a SwiftUI project.
---

# Create View

Scaffold a new SwiftUI feature with a consistent architecture: ViewState, ViewModel, Mapper, loading states, and navigation exit pattern.

## Quick Start

When asked to create a new feature or view, gather these inputs:

1. **Feature name** — e.g. `OrderDetail`, `ProfileSettings`
2. **Data source** — What domain model drives this view? Does it load async?
3. **Sections** — What distinct visual sections does the screen have?
4. **Navigation exits** — Where can the user go from here?

Then generate the files following the architecture below.

## Architecture Overview

Every feature follows this layered structure:

```
MyFeature/
├── MyFeatureView.swift              # SwiftUI view (stateless, receives ViewState)
├── MyFeatureViewModel.swift         # Owns state, handles actions, orchestrates
├── MyFeatureViewState.swift         # Immutable value types the view renders
├── MyFeatureNavigationRequest.swift # Enum of exit destinations
└── Mapper/
    ├── MyFeatureViewStateMapper.swift        # Protocol
    └── DefaultMyFeatureViewStateMapper.swift # Implementation
```

## Step 1: Define the ViewState

Read [references/view-state.md](references/view-state.md) for the full pattern.

Key rules:
- Struct conforming to `Sendable, Hashable`
- Use `let` for data from outside, `var` only for view-owned transitions
- Compose nested view states for complex screens
- No domain types — only view-renderable values

## Step 2: Define the NavigationRequest

Read [references/navigation-exit.md](references/navigation-exit.md) for the full pattern.

Key rules:
- Enum conforming to `Sendable, Hashable`
- Names describe **destinations**, not events
- Feature never navigates itself

## Step 3: Create the Mapper

Read [references/mapper.md](references/mapper.md) for the full pattern.

Key rules:
- Protocol + default implementation
- Conforms to `Sendable`
- Single responsibility: domain model in, view state out
- Injected into ViewModel as a dependency

## Step 4: Create the ViewModel

Read [references/view-model.md](references/view-model.md) for the full pattern.

Key rules:
- `@MainActor final class` conforming to `ObservableObject`
- `@Published private(set)` for all state
- Dependencies injected as protocols
- One action handler per view layer
- State mutation via copy-modify-reassign

## Step 5: Choose a Loading Strategy

Read [references/loading-states.md](references/loading-states.md) for the full pattern.

- If data loads once and the parent handles failure: wrap ViewState in `LoadingState`
- If data can fail and retry: wrap in `FailableLoadingState` and **render the `.failure` case** as a real error view with retry
- If the project has an existing loading state type, use that (the canonical `LoadingState` / `FailableLoadingState` ship from the `ios-create-loading-state` skill — don't reinvent them)

When an attempt can fail, a failed load or action does two things: it drives the state to a renderable `.failure` (so the user sees a specific error with a retry affordance) **and** it logs the failure so it's observable to developers, consistent with the DEBUG recording / `LogStore` approach. See [references/view-model.md](references/view-model.md#logging-failed-attempts).

## Step 6: Build the Views

Read [references/view.md](references/view.md) for the full pattern.

This is the core of the feature. Key principles:

1. **Only the root view holds `@StateObject`.** It owns the ViewModel, switches on loading state, and accepts `onFinished` for navigation exit.
2. **Every child view is stateless.** It receives `(viewState:, onAction:)` — data in, actions out.
3. **Define an action enum per view layer.** Parent views wrap child actions into their own enum so the ViewModel receives a single routable type.
4. **Keep bodies small.** Extract logical sections into `@ViewBuilder` private computed properties. Aim for under 30 lines per body.
5. **Each child gets only its slice.** Pass `viewState.header` to the header, not the whole screen state.

### Root view structure

```swift
public struct MyFeatureView: View {
    @StateObject private var viewModel: ViewModel
    private let onFinished: @MainActor (NavigationRequest) -> Void

    public var body: some View {
        content
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.viewState {
        case .loading:
            SkeletonView()
        case .success(let viewState):
            MyFeatureContentView(
                viewState: viewState.content,
                onEvent: { viewModel.handleContentViewEvent($0) }
            )
        case .failure(let errorViewState):
            ErrorView(
                viewState: errorViewState,
                onRetry: { Task { await viewModel.retry() } }
            )
        }
    }
}
```

This example uses `FailableLoadingState` (`.loading` / `.success` / `.failure`). The `.failure` case is a real, renderable state — an `ErrorView` with a retry affordance — not a fall-through. If the feature genuinely can't fail (parent handles failure), use `LoadingState` with just `.loading` / `.completed`. See [references/loading-states.md](references/loading-states.md).

### Child view structure

```swift
struct HeaderView: View {
    let viewState: HeaderViewState
    let onAction: @MainActor (HeaderAction) -> Void

    var body: some View {
        HStack {
            Text(viewState.title)
            Button("Close") { onAction(.closeTapped) }
        }
    }
}
```

### File organization for views

```
Views/
├── ContentView/
│   ├── MyFeatureContentView.swift
│   ├── MyFeatureContentViewState.swift
│   └── MyFeatureContentViewEvent.swift
├── Header/
│   ├── HeaderView.swift
│   ├── HeaderViewState.swift
│   └── HeaderAction.swift
└── Footer/
    ├── FooterView.swift
    ├── FooterViewState.swift
    └── FooterAction.swift
```

## Guidelines

- **Scan the project first.** Before generating, look at existing features to match naming conventions, file organization, and any project-specific patterns (e.g. existing `LoadingState` types, navigation infrastructure, Composer patterns).
- **Don't over-generate.** If the feature is simple (no async loading, no navigation exits), skip the layers that aren't needed. A static info view doesn't need a Mapper.
- **Actions bubble up, state flows down.** Views never mutate state directly. They send actions to the ViewModel, which updates ViewState.
- **Each sub-view gets only its slice.** Don't pass the entire screen state to a child component.
- **Flat structure for simple features.** Don't create subfolders for a single view — use folders when a section has 2+ files.
