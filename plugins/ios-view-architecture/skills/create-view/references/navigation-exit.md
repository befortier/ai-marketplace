# Navigation & Exit Pattern

Features never navigate themselves. Exit intent leaves the feature through a single injected async closure on the ViewModel; the app decides what happens next.

## The Exit Closure

The ViewModel takes `onAction: (MyFeatureAction) async -> Void` at init and awaits it from its handlers:

```swift
// ViewModel
private let onAction: (MyFeatureAction) async -> Void

func onRowTapped(_ row: RowViewState) async {
    viewState.successValue?.isPendingAction = true
    await onAction(.open(row.route))
    viewState.successValue?.isPendingAction = false
}
```

| Property | Why |
|----------|-----|
| `async` | The ViewModel can await completion and render a pending state meanwhile (see [loading-states.md](loading-states.md#in-place-success-mutation-successvalue)) |
| Non-throwing | Not every action can fail, and failure policy doesn't belong to the feature — the app-side handler owns it |
| One closure | Every exit goes through `onAction` — no per-destination closures, no published requests |

**Single exit** — a feature with exactly one way out uses a payload-free `onAction: () async -> Void`. No enum, no extra file.

## NavigationDestination Enum

Navigation payloads are a `Sendable, Hashable` enum. Names describe **where to go**, not what happened:

```swift
// Exit action — what the app should do
public enum MyFeatureAction: Sendable, Hashable {
    case open(MyFeatureNavigationDestination)
    case dismissed
}

// NavigationDestination — destination-oriented
public enum MyFeatureNavigationDestination: Sendable, Hashable {
    case settings
    case detail(id: String)
    case support
}

// contrast with a view Action — event-oriented
enum HeaderAction {
    case primaryButtonTapped
    case closeTapped
}
```

Rows arrive from the Mapper with their destination pre-resolved (see [mapper.md](mapper.md#routes-resolve-at-map-time)) — the ViewModel forwards `row.route`, never deriving a destination from domain values.

## Handling in the App

The composer wires `onAction` to a dedicated **NavigationHandler** — a small app-side type that switches exhaustively over the actions, composes the destination screen, and owns per-destination failure policy (e.g. showing a toast when a destination fails to open). The feature has no knowledge of what happens next. See the `ios-composition` skill for the handler shape.

```swift
// Composition layer
let handler = MyFeatureNavigationHandler(...)
let viewModel = MyFeatureView.ViewModel(
    ...,
    onAction: { await handler.handle($0) }
)
```

## Rules

| Rule | Why |
|------|-----|
| Exit closure is `onAction: (Action) async -> Void` | One awaited path out; the feature can render a pending state |
| Non-throwing closure | Failure policy lives in the app-side handler, not the feature |
| No `@Published` navigation state | `viewState` is the ViewModel's only stored state |
| `NavigationDestination` conforms to `Sendable, Hashable` | May cross actor boundaries; enables use in collections |
| Names describe destinations, not events | Distinguishes navigation intent from action intent |
| Feature never navigates itself | The app owns the navigation stack |
| Exhaustive `switch` in the handler | All exit paths are handled explicitly |
