# Record Mapping

Persistent stores convert between storage records (Realm objects, managed objects) and domain models. One mapper type owns **both** directions.

## Core Shape

```swift
/// `.unchecked`: `ItemRecord` is thread-confined to the store's actor and Swift 6
/// rejects any cross-actor move, so unchecked Sendable is safe here.
@Mocked(sendableConformance: .unchecked)
protocol ItemRecordMapping {
    func model(from record: ItemRecord) throws -> Item
    func record(from model: Item) throws -> ItemRecord
}

struct ItemRecordMapper: ItemRecordMapping {
    func model(from record: ItemRecord) throws -> Item {
        guard let kind = ItemKindRecordValue(rawValue: record.kind)?.domain else {
            throw ItemRecordMappingError.unknownKind(record.kind)
        }
        return Item(id: record.id, kind: kind, title: record.title)
    }

    func record(from model: Item) throws -> ItemRecord {
        let record = ItemRecord()
        record.id = model.id
        record.kind = ItemKindRecordValue(model.kind).rawValue
        record.title = model.title
        return record
    }
}
```

## Both Directions on One Type

Never split the directions — no `init(record:)` extensions on the model with the encode path living somewhere else. Split directions drift:

```swift
// Don't — decode in an init extension, encode in the store
extension Item {
    init(record: ItemRecord) { ... }
}

// Do — one protocol + struct owning both directions
struct ItemRecordMapper: ItemRecordMapping { ... }
```

## Kind Strings Are Shared Raw-Value Enums

The string written to storage and the string parsed from it come from **one** raw-value enum, so the directions can't diverge:

```swift
/// Shared by both directions — the string written is the string parsed.
enum ItemKindRecordValue: String {
    case standard
    case featured

    init(_ kind: Item.Kind) {
        switch kind {
        case .standard: self = .standard
        case .featured: self = .featured
        }
    }

    var domain: Item.Kind {
        switch self {
        case .standard: .standard
        case .featured: .featured
        }
    }
}
```

Never write `record.kind = "standard"` in the encode path and `switch record.kind { case "standard": ... }` in the decode path.

## Encode Failures Are Analytics Events

When encoding for storage can fail (e.g. JSON-encoding a payload field), don't swallow it — record an analytics event at the store and skip the write, so the failure is visible in production:

```swift
do {
    realm.add(try mapper.record(from: model), update: .modified)
} catch {
    analytics.recordEncodeFailure(id: model.id, error: error)
}
```

## Mocking

Records are thread-confined, so the mapping protocol can't be checked `Sendable`. Mock it with `@Mocked(sendableConformance: .unchecked)` and document the rationale in a comment at the annotation — see the `swift-mocking` skill's configuration reference.

## Rules

| Rule | Why |
|------|-----|
| One mapper owns both directions | Split directions drift apart silently |
| Protocol + struct — never `init(record:)` extensions | Keeps conversion injectable and testable |
| Kind strings via shared raw-value enums | Write and parse can't diverge |
| Encode failures are analytics events, not swallowed | Dropped writes must be visible in production |
| `@Mocked(sendableConformance: .unchecked)` with a rationale comment | Records are thread-confined; the compiler can't check it |

## Testing

Round-trip both directions and cover the unknown-kind path:

```swift
@Suite
struct ItemRecordMapperTests {
    private let sut = ItemRecordMapper()

    @Test("model round-trips through a record")
    func roundTrip() throws {
        let model = Item.stub()
        let record = try sut.record(from: model)
        let decoded = try sut.model(from: record)
        #expect(decoded == model)
    }

    @Test("unknown kind throws")
    func unknownKind() {
        let record = ItemRecord.stub(kind: "brand_new_kind")
        #expect(throws: ItemRecordMappingError.self) {
            try sut.model(from: record)
        }
    }
}
```
