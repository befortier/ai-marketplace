# View

Views are stateless structs that render ViewState and bubble actions upward. Only the root composing view holds a ViewModel.

## Contents

- The Stateless View Contract
- Action Enums Per Layer
- Action Wrapping
- The Root Composing View
- Body Decomposition
- Each View Gets Only Its Slice
- File Organization
- Rules

## The Stateless View Contract

Every child view follows the same two-parameter pattern — data in, actions out:

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

Views never own `@State` for data that comes from outside. They never call services, fetch data, or navigate. They render what they're given and report what happened.

## Action Enums Per Layer

Each view defines its own action enum describing what can happen in that view:

```swift
enum HeaderAction: Sendable {
    case closeTapped
    case helpTapped
}

enum ContentAction: Sendable {
    case itemTapped(id: String)
    case retryTapped
}
```

Name actions after **what the user did**, not what should happen next. The ViewModel decides the consequence.

## Action Wrapping

Parent views wrap child actions into their own enum so the ViewModel receives a single, routable type:

```swift
enum MyFeatureContentViewEvent: Sendable {
    case headerEvent(HeaderAction)
    case contentEvent(ContentAction)
    case contactSupportTapped
}
```

The parent view wires child closures into the wrapper:

```swift
struct MyFeatureContentView: View {
    let viewState: MyFeatureContentViewState
    let onEvent: @MainActor (MyFeatureContentViewEvent) -> Void

    var body: some View {
        VStack {
            HeaderView(
                viewState: viewState.header,
                onAction: { onEvent(.headerEvent($0)) }
            )
            ContentSectionView(
                viewState: viewState.content,
                onAction: { onEvent(.contentEvent($0)) }
            )
        }
    }
}
```

The ViewModel receives one handler per layer — handlers are `async` (see [view-model.md](view-model.md#handlers-are-async-the-view-owns-task-lifetimes)):

```swift
func handleContentViewEvent(_ event: MyFeatureContentViewEvent) async {
    switch event {
    case .headerEvent(let action):
        await onHeaderAction(action)
    case .contentEvent(let action):
        await onContentAction(action)
    case .contactSupportTapped:
        await onAction(.open(.support))
    }
}
```

## The Root Composing View

The root view is the only view that holds a `@StateObject` ViewModel. It is responsible for:

1. Owning the ViewModel
2. Switching on loading state
3. Wiring child `onAction`/`onEvent` closures to the ViewModel
4. Owning task lifetimes — `.task(id:)` for observation, `Task { }` per action

Navigation exit is **not** the root view's job: the composer injects the async `onAction` exit closure into the ViewModel directly (see [navigation-exit.md](navigation-exit.md)).

The ViewModel **must** be injected as an `@autoclosure` — `viewModel: @autoclosure @escaping () -> ViewModel`.

```swift
public struct MyFeatureView: View {
    @StateObject private var viewModel: ViewModel
    @State private var loadAttempt = 0

    public init(viewModel: @autoclosure @escaping () -> ViewModel) {
        self._viewModel = StateObject(wrappedValue: viewModel())
    }

    public var body: some View {
        content
            .task(id: loadAttempt) { await viewModel.start() }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.viewState {
        case .loading:
            SkeletonView()
        case .success(let viewState):
            MyFeatureContentView(
                viewState: viewState.content,
                onEvent: { event in Task { await viewModel.handleContentViewEvent(event) } }
            )
        case .failure:
            ErrorView(onRetry: { loadAttempt += 1 })
        }
    }
}
```

This switches over `FailableLoadingState` (`.loading` / `.success` / `.failure`). The `.failure` case is a real, renderable state — an `ErrorView` with a retry affordance — not a fall-through; its payload is a marker, and the error copy lives inline in `ErrorView` (see [loading-states.md](loading-states.md#the-failure-payload-is-a-marker-copy-lives-in-the-view)). Retry bumps `loadAttempt`, which restarts `start()` through a fresh `.task(id:)` identity — the ViewModel stores no task. A feature that can't fail (its parent renders failure) uses `LoadingState` with just `.loading` / `.completed` instead.

No child view below this point knows about the ViewModel, navigation, or loading state.

## Body Decomposition

Keep `body` small by extracting logical sections into `@ViewBuilder` private computed properties:

```swift
var body: some View {
    VStack(spacing: 0) {
        headerView
        contentView
        Spacer()
        footerView
    }
    .background(backgroundView)
}

@ViewBuilder
private var headerView: some View {
    HeaderView(
        viewState: viewModel.viewState.header,
        onAction: viewModel.onHeaderAction
    )
}

@ViewBuilder
private var footerView: some View {
    FooterView(
        viewState: viewModel.viewState.footer,
        onAction: { viewModel.onFooterAction($0) }
    )
}
```

**Guidelines:**
- Aim for bodies under 30 lines
- One `@ViewBuilder` var per logical section
- Name vars as nouns describing the section (`headerView`, `footerView`, not `makeHeader`)
- Use `@ViewBuilder` when the property needs conditional logic (`if`/`switch`)

## Each View Gets Only Its Slice

Never pass the entire screen state to a child. Each child receives the smallest ViewState it needs:

```swift
// Root passes slices, not the whole thing
HeaderView(viewState: viewState.header, onAction: ...)
ContentView(viewState: viewState.content, onAction: ...)
FooterView(viewState: viewState.footer, onAction: ...)
```

## File Organization

Mirror the view hierarchy in the directory structure. Co-locate each view with its action enum and ViewState. **One entity per file** — never pair two unrelated view states or views in the same file.

```
MyFeature/
├── MyFeatureView.swift                    # Root composing view
├── MyFeatureViewModel.swift
├── MyFeatureViewState.swift               # Top-level state (may wrap content state)
├── MyFeatureNavigationDestination.swift   # Omit for single-exit features
├── Mapper/
│   ├── MyFeatureViewStateMapper.swift
│   └── DefaultMyFeatureViewStateMapper.swift
└── Views/
    ├── ContentView/
    │   ├── MyFeatureContentView.swift
    │   ├── MyFeatureContentViewState.swift
    │   └── MyFeatureContentViewEvent.swift
    ├── Header/
    │   ├── HeaderView.swift
    │   ├── HeaderViewState.swift
    │   └── HeaderAction.swift
    ├── Footer/
    │   ├── FooterView.swift
    │   ├── FooterViewState.swift
    │   └── FooterAction.swift
    ├── Components/              # reusable sub-views shared across sections
    │   └── AvatarView.swift
    └── Shared/
        ├── SkeletonView.swift
        └── ErrorView.swift
```

**Engine-style target (one VM, many phases):** the `Views/` subtree is more structured — the engine core goes in `Views/<EngineName>/`, controls go in `Views/Controls/<ControlName>/`, reusable atoms go in `Views/Components/`, and phase screens go in `Views/Phases/`. See [engine-variant.md](engine-variant.md) for the full layout.

For simple features with few views, a flat structure is fine — don't create folders for a single file. `Runner/` is not a valid folder name for a view target.

## Rules

| Rule | Why |
|------|-----|
| Only root view holds `@StateObject` | Single source of truth; children are stateless |
| `viewState + onAction` is the standard contract | Consistent, testable, composable |
| Action enums per layer, wrapped by parents | Type-safe routing without leaking child details |
| Bodies under 30 lines | Readable, scannable, easy to modify |
| Each child gets only its slice of state | No unnecessary coupling between siblings |
| File structure mirrors view hierarchy | Easy to find and navigate |
