# Domain Model

Domain models represent normalized, validated business data. They're the canonical types consumed by repositories, view models, and use cases.

## Core Shape

```swift
public struct PointPassLanding: Sendable, Hashable, Identifiable {
    public let id: String
    public let title: String
    public let progress: Progress
    public let rewards: [Reward]
    public let status: LandingStatus
    public let imageURL: URL?

    public init(
        id: String,
        title: String,
        progress: Progress,
        rewards: [Reward],
        status: LandingStatus,
        imageURL: URL?
    ) {
        self.id = id
        self.title = title
        self.progress = progress
        self.rewards = rewards
        self.status = status
        self.imageURL = imageURL
    }
}
```

## Enums in Domain Models

Unlike DTOs, domain models can use enums. Include an `unknown` case for forward compatibility:

```swift
public enum LandingStatus: Sendable, Hashable {
    case active
    case completed
    case locked
    case unknown(String)
}
```

When a field can be soft-defaulted (non-terminal mapping failure), add a `.fallback` static property. This gives a single source of truth for the default rather than scattering a specific case throughout mapper code:

```swift
public enum RewardColor: Sendable, Hashable {
    case blue
    case red
    case gold
    case unknown(String)

    /// Single source of truth for the soft-default when an unrecognized value arrives.
    public static let fallback: RewardColor = .blue
}
```

Usage in the mapper: `mapColor(dto.color) ?? .fallback` — not `?? .blue`.

## Shape Decisions

- **Prefer `Model?` over result wrappers.** An absent value with a one-line doc beats a `ModelLookupResult`-style wrapper type.
- **IDs are `let id: String`, referenced as `Model.ID`.** `Identifiable` provides the alias — no ID newtypes.
- **Domain models are not `Codable`.** Wire coding belongs to DTOs and storage records.
- **Prefer a `source` enum with associated values over parallel optional fields:**

```swift
// Don't — parallel optionals that can half-populate
public let remoteID: String?
public let localDraftID: String?

// Do — one source; invalid combinations can't exist
public enum Source: Sendable, Hashable {
    case remote(id: String)
    case localDraft(id: String)
}
```

## Nested Types via Extensions

Split complex models across files using extensions:

```
Models/
├── PointPassLanding.swift
├── PointPassLanding+Progress.swift
└── PointPassLanding+Reward.swift
```

```swift
// PointPassLanding+Progress.swift
extension PointPassLanding {
    public struct Progress: Sendable, Hashable {
        public let current: Int
        public let total: Int

        public init(current: Int, total: Int) {
            self.current = current
            self.total = total
        }
    }
}
```

## Rules

| Rule | Why |
|------|-----|
| `Sendable + Hashable` | Concurrency-safe, diffable |
| `Identifiable` when natural ID exists | Enables SwiftUI list rendering |
| Public init with all properties | Enables construction in mappers and tests |
| No UI decisions | Colors, formatted strings, layout hints belong in ViewState |
| Value types only (struct/enum) | Predictable equality and copying |
| `unknown(String)` case on enums | Handles unrecognized API values without crashing |
| `.fallback` static on soft-defaultable enums | Single source of truth for default value |
| `Model?` over result-wrapper types | Absence is already expressive |
| Not `Codable` | Wire coding belongs to DTOs and records |
| `source` enum over parallel optionals | Invalid combinations can't exist |

## Testing

Domain models are simple value types — testing focuses on stub factories that other test files depend on:

```swift
// PointPassLanding+Stub.swift
extension PointPassLanding {
    static func stub(
        id: String = "season-1",
        title: String = "Season 1",
        progress: Progress = .stub(),
        rewards: [Reward] = [],
        status: LandingStatus = .active,
        imageURL: URL? = nil
    ) -> PointPassLanding {
        .init(
            id: id,
            title: title,
            progress: progress,
            rewards: rewards,
            status: status,
            imageURL: imageURL
        )
    }
}

extension PointPassLanding.Progress {
    static func stub(current: Int = 3, total: Int = 10) -> Self {
        .init(current: current, total: total)
    }
}
```

Create matching stubs for DTOs:

```swift
// PointPassLandingDTO+Stub.swift
extension PointPassLandingDTO {
    static func stub(
        seasonID: String = "season-1",
        title: String = "Season 1",
        status: String = "active",
        startDate: String = "2025-01-01T00:00:00Z",
        imageURL: String? = "https://example.com/img.png",
        rewards: [RewardDTO] = []
    ) -> PointPassLandingDTO {
        .init(
            seasonID: seasonID,
            title: title,
            status: status,
            startDate: startDate,
            imageURL: imageURL,
            progress: .init(current: 3, total: 10),
            rewards: rewards
        )
    }
}
```
