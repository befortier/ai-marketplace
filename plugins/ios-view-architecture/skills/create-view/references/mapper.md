# Mapper

The Mapper transforms domain models into view state. It is the only place where domain types are converted to view-renderable types.

## Contents

- [Core Shape](#core-shape)
- [Where It Lives](#where-it-lives)
- [Reusable Component Mappers](#reusable-component-mappers)
- [Injection](#injection)
- [Mapping Errors](#mapping-errors)
- [Rules](#rules)

## Core Shape

```swift
public protocol MyViewStateMapper: Sendable {
    func map(_ model: MyDomainModel) throws -> MyViewState
}

public struct DefaultMyViewStateMapper: MyViewStateMapper {
    public func map(_ model: MyDomainModel) throws -> MyViewState {
        MyViewState(
            title: model.name,
            isButtonEnabled: model.status == .active
        )
    }
}
```

## Where It Lives

```
MyFeature/
└── Mapper/
    ├── MyViewStateMapper.swift         // Protocol
    └── DefaultMyViewStateMapper.swift  // Implementation
```

For complex screens, split into sub-mappers per section:

```
Mapper/
├── MyViewStateMapper.swift
├── DefaultMyViewStateMapper.swift
├── HeaderViewStateMapper.swift
└── Sections/
    ├── SectionAMapper.swift
    └── SectionBMapper.swift
```

## Reusable Component Mappers

When a component is reused across features, its mapper lives next to the component — not inside any one feature's `Mapper/` directory. This lets other mappers inject and compose it.

```
SharedComponents/
├── RewardBadge/
│   ├── RewardBadgeView.swift
│   ├── RewardBadgeViewState.swift
│   └── RewardBadgeViewStateMapper.swift   // Lives with the component
```

Other mappers inject it as a dependency:

```swift
public struct ItemDetailViewStateMapper: ItemDetailViewStateMapping {
    private let badgeMapper: any RewardBadgeViewStateMapping

    public init(
        badgeMapper: any RewardBadgeViewStateMapping = RewardBadgeViewStateMapper()
    ) {
        self.badgeMapper = badgeMapper
    }

    public func map(_ item: Item) -> ItemDetailViewState {
        ItemDetailViewState(
            badge: badgeMapper.map(item.reward),
            ...
        )
    }
}
```

## Injection

The Mapper is injected into the ViewModel as a protocol dependency:

```swift
final class ViewModel: ObservableObject {
    private let mapper: any MyViewStateMapper

    init(mapper: any MyViewStateMapper = DefaultMyViewStateMapper()) { ... }
}
```

## Mapping Errors

Define a typed error for mapping failures rather than using a generic one:

```swift
enum MyMappingError: Error {
    case missingRequiredField(String)
    case unsupportedVariant(String)
}
```

### Mapping a Failure to a Renderable State

When a feature renders its own failure (see [loading-states.md](loading-states.md) and [view-state.md](view-state.md#the-failure-case-is-a-view-state)), the Mapper also turns a caught error into the renderable `ErrorViewState` — the same domain-to-view-state discipline, just for the failure path. Add an error-mapping method alongside `map(_:)` (named `mapFailure(_:)` to avoid colliding with `FailableLoadingState.mapError`):

```swift
public protocol MyViewStateMapper: Sendable {
    func map(_ model: MyDomainModel) throws -> MyContentViewState
    func mapFailure(_ error: some Error) -> ErrorViewState
}

extension DefaultMyViewStateMapper {
    public func mapFailure(_ error: some Error) -> ErrorViewState {
        // Inspect the typed error here; keep raw errors out of the view.
        ErrorViewState(
            title: "Something went wrong",
            message: "We couldn't load this right now.",
            retryButtonTitle: "Try Again"
        )
    }
}
```

This keeps the view free of error inspection: it renders the `.failure` payload directly. Logging the underlying error is the ViewModel's job (see [view-model.md](view-model.md#logging-failed-attempts)) — the Mapper produces presentation, not log records.

## Rules

| Rule | Why |
|------|-----|
| Protocol + default implementation | Enables mock injection in tests |
| Mapper conforms to `Sendable` | May be called from async contexts |
| No domain types leak into ViewState | Views are isolated from API changes |
| Mapping errors are typed | Callers can handle specific failures |
