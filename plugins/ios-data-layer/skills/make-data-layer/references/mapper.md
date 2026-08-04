# Mapper

Mappers convert DTOs into domain models. This is where raw API strings become typed enums, optional strings become URLs, and invalid data gets filtered or throws.

## Planning Phase

Before generating mapper code, **present a field-by-field mapping plan** to the user. Any DTO field that requires a transformation that can fail (Date, URL, enum, etc.) must be called out with a proposed failure strategy:

```
Mapping Plan for PointPassLandingDTO → PointPassLanding:
─────────────────────────────────────────────────────────
Field              Transform               On Failure
─────────────────────────────────────────────────────────
seasonID           passthrough (String)     —
title              passthrough (String)     —
status (String)    → LandingStatus enum     soft-default → .fallback
imageURL (String?) → URL?                   soft-default → nil
startDate (String) → Date                   TERMINAL — throw
rewards[].type     → RewardType enum        soft-default → .fallback
rewards[].title    required guard           skip item (compactMap)
─────────────────────────────────────────────────────────
```

**Terminal** = the whole mapping throws if this field fails (model is useless without it).
**Soft-default** = use a fallback value (`nil`, `.fallback`, or skip the item).

Present this plan and let the user adjust before generating code.

## Core Shape

```swift
@Mocked
public protocol PointPassLandingMapping: Sendable {
    func map(_ dto: PointPassLandingDTO) throws -> PointPassLanding
}

public struct PointPassLandingMapper: PointPassLandingMapping {
    public init() {}

    public func map(_ dto: PointPassLandingDTO) throws -> PointPassLanding {
        guard let startDate = DateFormatter.iso8601.date(from: dto.startDate) else {
            throw PointPassLandingMappingError.invalidDate(dto.startDate)
        }

        return PointPassLanding(
            id: dto.seasonID,
            title: dto.title,
            progress: mapProgress(dto.progress),
            rewards: dto.rewards.compactMap { mapReward($0) },
            status: mapStatus(dto.status) ?? .fallback,
            imageURL: dto.imageURL.flatMap { URL(string: $0) },
            startDate: startDate
        )
    }

    private func mapProgress(_ dto: ProgressDTO) -> PointPassLanding.Progress {
        .init(current: dto.current, total: dto.total)
    }

    private func mapReward(_ dto: RewardDTO) -> PointPassLanding.Reward? {
        guard let title = dto.title else { return nil }
        return .init(
            id: dto.id,
            type: mapRewardType(dto.type) ?? .fallback,
            value: dto.value,
            title: title
        )
    }

    private func mapStatus(_ raw: String) -> LandingStatus? {
        switch raw {
        case "active": .active
        case "completed": .completed
        case "locked": .locked
        default: nil
        }
    }

    private func mapRewardType(_ raw: String) -> RewardType? {
        switch raw {
        case "points": .points
        case "perk": .perk
        default: nil
        }
    }
}
```

Note: enum mapping functions return `nil` for unrecognized values. The call site decides whether to use `?? .fallback` (soft-default) or `throw` (terminal).

## Where It Lives

```
DTO/
└── <Domain>DTO.swift        (one file per type — see dto.md)
Wire/
├── <Domain>Mapper.swift
└── <Domain>MappingError.swift
```

## Composing Sub-Mappers

Inject dependent mappers via init for testability:

```swift
public struct QuestSectionMapper: QuestSectionMapping {
    private let basicQuestMapper: any BasicQuestMapping
    private let tieredQuestMapper: any TieredQuestMapping

    public init(
        basicQuestMapper: any BasicQuestMapping = BasicQuestMapper(),
        tieredQuestMapper: any TieredQuestMapping = TieredQuestMapper()
    ) {
        self.basicQuestMapper = basicQuestMapper
        self.tieredQuestMapper = tieredQuestMapper
    }
}
```

## Error Handling

Define typed errors for terminal failures:

```swift
public enum PointPassLandingMappingError: Error, Hashable {
    case missingLandingPage
    case missingProgress
    case invalidDate(String)
}
```

- **Terminal**: `throw` when a missing/invalid field makes the whole model useless
- **Soft-default**: use `?? .fallback` for enums, `nil` for optional URLs/dates
- **Skip item**: return `nil` from item mapper + `compactMap` on the collection

## Naming

| Protocol | Implementation |
|----------|---------------|
| `<Domain>Mapping` | `<Domain>Mapper` |
| `Wire<Source>Mapping` | `Wire<Source>Mapper` |

## Rules

| Rule | Why |
|------|-----|
| Sendable struct | Thread-safe, stateless |
| `@Mocked` protocol | Auto-generates test mocks |
| String→enum here, not in DTO | DTOs stay stable; mapper absorbs change |
| `?? .fallback` not `?? .specificCase` | Single source of truth for soft defaults |
| `compactMap` for optional items | Gracefully skip invalid collection entries |
| Defaults in init | Callers don't need to wire sub-mappers manually |
| Present mapping plan before generating | User can intervene on terminal vs soft-default decisions |

## Testing

Test each transformation path — happy path, unknown enum values hitting fallback, terminal failures throwing:

```swift
@Suite
struct PointPassLandingMapperTests {
    private let sut = PointPassLandingMapper()

    @Test("maps a complete DTO to domain model")
    func mapCompleteDTO() throws {
        let dto = PointPassLandingDTO.stub()
        let result = try sut.map(dto)

        #expect(result.id == dto.seasonID)
        #expect(result.title == dto.title)
        #expect(result.status == .active)
    }

    @Test("unknown status soft-defaults to .fallback")
    func unknownStatusFallback() throws {
        let dto = PointPassLandingDTO.stub(status: "brand_new_status")
        let result = try sut.map(dto)

        #expect(result.status == LandingStatus.fallback)
    }

    @Test("invalid date throws terminal error")
    func invalidDateThrows() {
        let dto = PointPassLandingDTO.stub(startDate: "not-a-date")

        #expect(throws: PointPassLandingMappingError.self) {
            try sut.map(dto)
        }
    }

    @Test("filters rewards with missing title")
    func filterInvalidRewards() throws {
        let dto = PointPassLandingDTO.stub(rewards: [
            .stub(title: "Valid"),
            .stub(title: nil)
        ])
        let result = try sut.map(dto)

        #expect(result.rewards.count == 1)
    }

    @Test("maps status string correctly", arguments: [
        ("active", LandingStatus.active),
        ("completed", LandingStatus.completed),
        ("locked", LandingStatus.locked),
    ])
    func mapStatus(raw: String, expected: LandingStatus) throws {
        let dto = PointPassLandingDTO.stub(status: raw)
        let result = try sut.map(dto)
        #expect(result.status == expected)
    }
}
```
