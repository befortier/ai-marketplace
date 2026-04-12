# DTO

Data Transfer Objects decode API responses into typed Swift structs. They mirror the API shape exactly — no normalization, no logic.

## Core Shape

```swift
public struct PointPassLandingDTO: Decodable, Sendable, Hashable {
    public let seasonID: String
    public let title: String
    public let progress: ProgressDTO
    public let rewards: [RewardDTO]
    public let status: String          // NOT an enum — backward compat
    public let imageURL: String?       // String, not URL — parse in mapper
}

public struct ProgressDTO: Decodable, Sendable, Hashable {
    public let current: Int
    public let total: Int
}

public struct RewardDTO: Decodable, Sendable, Hashable {
    public let id: String
    public let type: String            // "points", "perk" — String, not enum
    public let value: Int?
    public let title: String?
}
```

## Where It Lives

```
Wire/
└── <Domain>DTO.swift
```

Group nested DTOs in the same file when they're small. Split to separate files when a nested DTO exceeds ~30 lines.

## CodingKeys

Use when the API uses snake_case or non-standard naming:

```swift
public struct OfferDetailDTO: Decodable, Sendable, Hashable {
    public let offerID: String
    public let pointsAward: Int
    public let deepLinkURL: String?

    enum CodingKeys: String, CodingKey {
        case offerID = "offer_id"
        case pointsAward = "points_award"
        case deepLinkURL = "deep_link_url"
    }
}
```

## Rules

| Rule | Why |
|------|-----|
| `Decodable`, not `Codable` | DTOs only flow inward from the network |
| No enums | New API values won't crash the decoder |
| `String` for URLs | Parse to `URL` in the mapper, not here |
| `String` or `Int` for dates | Use the raw API type; parse to `Date` in the mapper |
| `String` for type/status fields | Map to domain enums in the mapper |
| All properties `let` | DTOs are immutable snapshots |
| Optional for nullable API fields | Matches API contract exactly |
| `Sendable + Hashable` | Concurrency-safe, usable as dictionary keys |

## Testing

Write a deserialization test that decodes a JSON fixture into the DTO, verifying all fields round-trip correctly:

```swift
@Suite
struct PointPassLandingDTOTests {
    @Test("decodes complete JSON response")
    func decodesComplete() throws {
        let json = """
        {
            "season_id": "s1",
            "title": "Season 1",
            "status": "active",
            "image_url": "https://example.com/img.png",
            "progress": { "current": 3, "total": 10 },
            "rewards": [{ "id": "r1", "type": "points", "value": 500, "title": "Bonus" }]
        }
        """.data(using: .utf8)!

        let dto = try JSONDecoder().decode(PointPassLandingDTO.self, from: json)

        #expect(dto.seasonID == "s1")
        #expect(dto.title == "Season 1")
        #expect(dto.status == "active")
        #expect(dto.progress.current == 3)
        #expect(dto.rewards.count == 1)
    }

    @Test("decodes with null optional fields")
    func decodesNulls() throws {
        let json = """
        {
            "season_id": "s1",
            "title": "Season 1",
            "status": "active",
            "image_url": null,
            "progress": { "current": 0, "total": 0 },
            "rewards": []
        }
        """.data(using: .utf8)!

        let dto = try JSONDecoder().decode(PointPassLandingDTO.self, from: json)

        #expect(dto.imageURL == nil)
    }
}
```
