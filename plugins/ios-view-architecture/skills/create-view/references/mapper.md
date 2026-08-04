# Mapper

The Mapper transforms domain models into view state. It is the only place where domain types are converted to view-renderable types.

## Contents

- [Core Shape](#core-shape)
- [Where It Lives](#where-it-lives)
- [Routes Resolve at Map Time](#routes-resolve-at-map-time)
- [Grouping Buckets Are Enums](#grouping-buckets-are-enums)
- [Map Copy Verbatim](#map-copy-verbatim)
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

## Routes Resolve at Map Time

Rows arrive **pre-routed**: the mapper resolves each row's navigation destination via an injected `RouteMapping` protocol, so the ViewModel never inspects domain values to decide where a row goes.

```swift
public protocol RouteMapping: Sendable {
    func route(for item: MyDomainItem) -> MyFeatureNavigationDestination
}

public struct DefaultMyViewStateMapper: MyViewStateMapper {
    private let routeMapping: any RouteMapping

    public func map(_ model: MyDomainModel) throws -> MyViewState {
        MyViewState(
            rows: model.items.map { item in
                RowViewState(
                    title: item.title,
                    route: routeMapping.route(for: item)   // resolved here, not in the ViewModel
                )
            }
        )
    }
}
```

The ViewModel forwards `row.route` when the row is tapped — it never re-derives a destination from a domain model.

## Grouping Buckets Are Enums

Section/bucket groupings are enums with localized titles — never string tuples:

```swift
// Don't — stringly-typed buckets
func sections(_ model: MyDomainModel) -> [(title: String, rows: [RowViewState])]

// Do — an enum owns identity; the title is derived and localized
enum AgeBucket: Sendable, Hashable, CaseIterable {
    case today, thisWeek, earlier

    var title: String {
        switch self {
        case .today: String(localized: "Today", bundle: .module)
        case .thisWeek: String(localized: "This Week", bundle: .module)
        case .earlier: String(localized: "Earlier", bundle: .module)
        }
    }
}
```

## Map Copy Verbatim

User-facing strings pass through unchanged. `?? .fallback` is for enums only — no `nonEmpty` collapsing, no trimming, no defaulting of copy:

```swift
// Don't — copy massaged in the mapper
title: model.title.nonEmpty ?? String(localized: "Untitled", bundle: .module)

// Do — copy verbatim; enums get the fallback treatment
title: model.title,
status: mapStatus(model.status) ?? .fallback
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

Protocol signatures use plain `throws` — never typed throws. The error enum stays `internal`: it exists for reason codes, not for callers to switch on.

```swift
// Don't — typed throws on the protocol boundary
func map(_ model: MyDomainModel) throws(MyMappingError) -> MyViewState

// Do — untyped throws; internal enum for reason codes
public protocol MyViewStateMapper: Sendable {
    func map(_ model: MyDomainModel) throws -> MyViewState
}

enum MyMappingError: Error {
    case missingRequiredField(String)
    case unsupportedVariant(String)
}
```

## Rules

| Rule | Why |
|------|-----|
| Protocol + default implementation | Enables mock injection in tests |
| Mapper conforms to `Sendable` | May be called from async contexts |
| No domain types leak into ViewState | Views are isolated from API changes |
| Routes resolve at map time via `RouteMapping` | The ViewModel never inspects domain values |
| Copy maps verbatim; `?? .fallback` for enums only | The mapper isn't a copywriter |
| Plain `throws` on protocols; error enums `internal` | Callers render `.failure`; reason codes are diagnostics, not API |
