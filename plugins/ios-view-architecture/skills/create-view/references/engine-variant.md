# Engine Variant

Use this variant when a feature is a **single multi-step flow driven by one ViewModel** — a sequence of phases (intro / steps / results / done) where the entire flow lives inside one `@StateObject`, rather than a set of independent per-screen ViewModels.

The per-screen shape (the rest of this skill) applies everywhere else.

## When to Use

- The flow is one contiguous session; the user moves forward/backward through internal phases rather than navigating to separate screens.
- The phase machine is an implementation detail the parent should never see.
- Example: a multi-step intake workflow, a guided setup wizard.

## Shape

### One Root ViewModel, ONE published state

A single `@MainActor ObservableObject` publishes **one** `@Published private(set) var viewState: MyFlowViewState`. Not one `@Published` per phase.

```swift
@MainActor
public final class MyFlowViewModel: ObservableObject {
    @Published private(set) var viewState: MyFlowViewState = .intro(.initial)

    private var phase: InternalPhase = .intro
    private let contextStore: ContextStore
    private let mapper: MyFlowViewStateMapper

    public func handle(_ action: MyFlowAction) {
        // mutate contextStore / phase, then recompute
        viewState = mapper.map(phase: phase, context: contextStore)
    }
}
```

The root view holds this as its only `@StateObject` and switches on `viewState`.

### Internal phase enum

The engine's phase machine is an **internal** enum (not published, not in ViewState). It is folded into the one published view state by a pure mapper.

```swift
// Internal only — never published directly
private enum InternalPhase {
    case intro
    case page(index: Int)
    case results
    case done
}
```

### A content-viewstate enum + `@ViewBuilder` switch

Variable content (one case per control/variant, plus `.unknown`) is a single enum. Each case carries a view-ready per-control ViewState with selections/values already resolved.

```swift
public enum MyFlowContentViewState: Sendable, Hashable {
    case chips(ChipsControlViewState)
    case counter(CounterControlViewState)
    case slider(SliderControlViewState)
    case unknown
}
```

A `@ViewBuilder` switch renders the concrete view per case. **No `AnyView`, no renderer protocol, no type-erased boxing** — the switch is the dispatch.

```swift
@ViewBuilder
private var contentView: some View {
    switch viewState.content {
    case .chips(let s):   ChipsControlView(viewState: s, onAction: handle)
    case .counter(let s): CounterControlView(viewState: s, onAction: handle)
    case .slider(let s):  SliderControlView(viewState: s, onAction: handle)
    case .unknown:        UnknownControlFallbackView()
    }
}
```

### A shared intent vocabulary

Views emit one `Action` enum (navigation actions + content *intent* actions). Actions carry **intent**, not a resolved ViewState. The ViewModel's single `handle(_:)` resolves intent → state, recomputes, and republishes.

```swift
public enum MyFlowAction: Sendable, Hashable {
    // nav
    case start, advance, back, submit
    // intent — NOT a resolved ViewState
    case optionToggled(id: String)
    case sliderChanged(Double)
    case textChanged(String)
}
```

### Exit rule

- **Single exit** (e.g. "flow complete, close"): use a bare `onFinished: @MainActor () -> Void`. No `NavigationRequest` file needed.
- **Multiple exits** (e.g. "finished" vs "go to cart details"): use a `NavigationRequest` enum:

```swift
public enum MyFlowNavigationRequest: Sendable, Hashable {
    case finished
    case cartDetails(cartID: String)
}
```

The root view accepts `onFinished: @MainActor (MyFlowNavigationRequest) -> Void` and never navigates itself.

### An in-memory ContextStore

Accumulated user input across phases lives in a store held by the ViewModel — not in views, not in each step's `@State`.

```swift
// Thread-safe via Mutex (not an actor) — the VM calls it synchronously inside handle()
final class ContextStore: Sendable {
    private let mutex = Mutex<[String: AnswerValue]>([:])

    func set(_ value: AnswerValue, for key: String) {
        mutex.withLock { $0[key] = value }
    }

    func answers() -> [String: AnswerValue] {
        mutex.withLock { $0 }
    }
}
```

### Forward-compat `.unknown` + graceful degradation

Every server-driven enum (control type, tone, audience, mode) must have an `.unknown` case. Unknown controls map to a neutral fallback view and are auto-skipped where they can't render. A newer server payload must not crash an older client. Enforce at the mapping edge, in the ViewModel, and in the ViewState mapper — and write a test proving an unknown control auto-skips and the flow still completes.

## Folder Layout

```
Sources/MyFlow/
├── MyFlowRunView.swift              # Root composing view (BootstrapView idiom)
├── MyFlowNavigationRequest.swift    # Only if multi-exit
└── Views/
    ├── MyFlow/                      # Engine core (VM + ViewState + mapper + internals)
    │   ├── MyFlowRunViewModel.swift
    │   ├── MyFlowViewState.swift
    │   ├── MyFlowViewStateMapper.swift
    │   ├── MyFlowAction.swift
    │   ├── InternalPhase.swift
    │   └── ContextStore.swift
    ├── Controls/                    # Per-control view + ViewState, one entity per file
    │   ├── Chips/
    │   │   ├── ChipsControlView.swift
    │   │   └── ChipsControlViewState.swift
    │   ├── Counter/
    │   │   ├── CounterControlView.swift
    │   │   └── CounterControlViewState.swift
    │   └── Slider/
    │       ├── SliderControlView.swift
    │       └── SliderControlViewState.swift
    ├── Components/                  # Reusable atoms shared across controls/phases
    │   ├── AvatarView.swift
    │   └── ProgressDotsView.swift
    └── Phases/                      # Per-phase screens (stateless, receive a ViewState slice)
        ├── Intro/
        │   └── IntroView.swift
        ├── Step/
        │   ├── StepView.swift
        │   └── StepContentView.swift
        ├── Results/
        │   ├── ResultsView.swift
        │   └── ResultCardView.swift
        └── Done/
            └── DoneView.swift
```

**Rules:**
- `Runner/` is **not** a valid folder name — use `Views/<EngineName>/` for the engine core.
- One entity per file throughout — no pairing of two control ViewStates in one file.
- ViewState and Action enums co-located with the view that owns them (same folder).

## Rules

| Rule | Why |
|------|-----|
| One published `viewState` | Single source of truth; no per-phase `@Published` sprawl |
| Internal phase enum never published | Phase is an impl detail; the mapper folds it into the view state |
| `@ViewBuilder` switch, no `AnyView` | Type-safe dispatch; SwiftUI can optimize concrete types |
| Actions carry intent, not ViewState | The ViewModel resolves intent → state; views stay dumb |
| `ContextStore` via `Mutex`, not actor | VM calls it synchronously inside `handle()` |
| `.unknown` on every server-driven enum | Forward-compat: new server payload must not crash old client |
| Single exit → bare closure, multi-exit → `NavigationRequest` | Don't wrap one case in an enum |
