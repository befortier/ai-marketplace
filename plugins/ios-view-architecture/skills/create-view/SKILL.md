---
name: create-view
description: Scaffold a new iOS SwiftUI feature following a consistent architecture — ViewModel, ViewState, Mapper, loading states, and navigation. Use when creating a new view, feature, or screen in a SwiftUI project.
---

# Create View

Scaffold a new SwiftUI feature: ViewState, ViewModel, Mapper, loading states, and navigation exit.

## Quick Start

Gather these inputs, then generate:

1. **Feature name** — e.g. `OrderDetail`, `ProfileSettings`
2. **Data source** — What domain model drives this view? Does it load async?
3. **Sections** — What distinct visual sections does the screen have?
4. **Navigation exits** — Where can the user go? How many distinct destinations?

If the feature is a **multi-step flow driven by a single ViewModel** (not independent screens), read [references/engine-variant.md](references/engine-variant.md) first — it has a different shape.

## Architecture Overview

```
MyFeature/
├── MyFeatureView.swift              # SwiftUI view (stateless, receives ViewState)
├── MyFeatureViewModel.swift         # Owns state, handles actions, orchestrates
├── MyFeatureViewState.swift         # Immutable value types the view renders
├── MyFeatureNavigationRequest.swift # Multi-exit only; omit for single-exit
└── Mapper/
    ├── MyFeatureViewStateMapper.swift
    └── DefaultMyFeatureViewStateMapper.swift
```

For sub-views, place them under `Views/` — see [File Structure](#file-structure).

## Steps

**1. ViewState** — Read [references/view-state.md](references/view-state.md). Key rules:
- `Sendable, Hashable` (struct or enum)
- `let` for data from outside; `var` only for view-owned transitions
- No domain types; compose nested view states for complex screens

**2. Exit pattern** — Read [references/navigation-exit.md](references/navigation-exit.md). Key rules:
- **Single exit**: bare `onFinished: @MainActor () -> Void` — no enum, no extra file
- **Multiple exits**: `NavigationRequest` enum conforming to `Sendable, Hashable`
- Feature never navigates itself

**3. Mapper** — Read [references/mapper.md](references/mapper.md). Protocol + default impl; `Sendable`; domain in, view state out; injected into ViewModel.

**4. ViewModel** — Read [references/view-model.md](references/view-model.md). `@MainActor final class ObservableObject`; `@Published private(set)` state; dependencies as protocols; one action handler per view layer.

**5. Loading strategy** — Read [references/loading-states.md](references/loading-states.md) for `LoadingState` vs `FailableLoadingState`.

**6. Views** — Read [references/view.md](references/view.md). Key rules:
- Only the root view holds `@StateObject`
- Every child view is stateless: `(viewState:, onAction:)` — data in, actions out
- Action enum per view layer; parents wrap child actions before routing to ViewModel
- Bodies under 30 lines; extract sections as `@ViewBuilder` computed properties

## File Structure

One entity per file. Co-locate each view's ViewState and Action/Event enum in the same folder.

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
├── Components/          # reusable sub-views shared across sections
└── Shared/
    ├── SkeletonView.swift
    └── ErrorView.swift
```

For an engine-style view target (one VM, many phases) the layout is more structured — see [references/engine-variant.md](references/engine-variant.md) for `Views/<Engine>/`, `Controls/<Name>/`, `Components/`, `Phases/`.

**Rules:**
- One entity per file — never pair two unrelated view states in one file
- Folder only when a section has 2+ files
- `Runner/` is **not** a valid folder name for a view target

## Guidelines

- **Scan the project first.** Match existing naming conventions and patterns before generating.
- **Don't over-generate.** A static info view doesn't need a Mapper or NavigationRequest.
- **Actions bubble up, state flows down.** Views never mutate state directly.
- **Each sub-view gets only its slice.** Don't pass the full screen state to a child.
- **Single exit = bare closure.** Only introduce `NavigationRequest` for multiple distinct destinations.
