# Store (AsyncStream)

Actor-based in-memory stores that publish domain models via `AsyncStream`. Thread-safe by design — no locks or queues needed.

## Core Shape

```swift
@Mocked
public protocol PointPassStore: AnyObject, Sendable {
    func upsert(_ model: PointPassLanding) async
    func stream(replayCurrentValue: Bool) async -> AsyncStream<PointPassLanding?>
    func removeAll() async
}

public actor InMemoryPointPassStore: PointPassStore {
    private var currentValue: PointPassLanding?
    private var continuations: [UUID: AsyncStream<PointPassLanding?>.Continuation] = [:]

    public init() {}

    public func upsert(_ model: PointPassLanding) {
        currentValue = model
        for continuation in continuations.values {
            continuation.yield(model)
        }
    }

    public func stream(replayCurrentValue: Bool) -> AsyncStream<PointPassLanding?> {
        let id = UUID()
        let (stream, continuation) = AsyncStream.makeStream(of: PointPassLanding?.self)

        continuations[id] = continuation

        if replayCurrentValue {
            continuation.yield(currentValue)
        }

        continuation.onTermination = { [weak self] _ in
            Task { [weak self] in
                await self?.removeContinuation(id)
            }
        }

        return stream
    }

    public func removeAll() {
        currentValue = nil
        for continuation in continuations.values {
            continuation.yield(nil)
        }
    }

    private func removeContinuation(_ id: UUID) {
        continuations.removeValue(forKey: id)
    }

    deinit {
        for continuation in continuations.values {
            continuation.finish()
        }
    }
}
```

## Fallible Stores Throw

A store whose backing can fail to open (a database, a file) throws from its accessors — never swallow an open error into an empty stream:

```swift
// Don't — an open failure becomes silence
func activeItemsStream() async -> AsyncStream<[Item]> {
    guard let realm = try? openRealm() else {
        return AsyncStream { $0.finish() }
    }
    ...
}

// Do — the getter throws; the caller renders failure
func activeItemsStream() async throws -> AsyncStream<[Item]>
```

## Persistent Store Rules

- **Actor-isolated end to end.** No `nonisolated` mutation paths, no implicitly-unwrapped snapshots captured outside the actor.
- **Mutations report whether they transitioned.** A mutation that may be a no-op returns whether it actually changed state, so callers can act exactly once on a real transition:

```swift
@discardableResult
func markSeen(_ ids: Set<Item.ID>) async throws -> Bool   // true iff something changed
```

- **Record ↔ model conversion lives in a two-way mapper** — see [record-mapping.md](record-mapping.md).

## Package Dependency

Add `swift-async-algorithms` to `Package.swift` when using this store pattern. It provides `combineLatest` and `chain` for ViewModels that observe multiple streams.

```swift
// Package.swift
.package(url: "https://github.com/apple/swift-async-algorithms", from: "1.0.0")

// Target dependency
.product(name: "AsyncAlgorithms", package: "swift-async-algorithms")
```

## Where It Lives

```
Store/
├── <Domain>Store.swift              (protocol)
└── InMemory<Domain>Store.swift      (actor implementation)
```

## Naming

| Protocol | Implementation |
|----------|---------------|
| `<Domain>Store` | `InMemory<Domain>Store` |

## Rules

| Rule | Why |
|------|-----|
| `actor` implementation | Thread-safe without manual synchronization |
| `@Mocked` protocol | Auto-generates test mocks |
| `AsyncStream.makeStream(of:)` | Synchronous access to stream + continuation |
| Stores domain models, not DTOs | Consumers shouldn't know about wire format |
| `replayCurrentValue` parameter | Lets new subscribers get current state immediately |
| Clean up continuations on termination + deinit | Prevents memory leaks |
| `AnyObject` on protocol | Allows `weak self` capture in continuations |
| Throw from accessors when opening can fail | An empty stream hides real failures |
| Mutations return whether they transitioned | Callers act exactly once on real changes |

## Testing

Test stream emission, replay behavior, and cleanup:

```swift
@Suite
struct InMemoryPointPassStoreTests {
    private let sut = InMemoryPointPassStore()

    @Test("upsert emits to stream subscribers")
    func upsertEmits() async {
        let model = PointPassLanding.stub()
        let stream = await sut.stream(replayCurrentValue: false)
        var iterator = stream.makeAsyncIterator()

        await sut.upsert(model)
        let emitted = await iterator.next()

        #expect(emitted == model)
    }

    @Test("stream replays current value when requested")
    func streamReplay() async {
        let model = PointPassLanding.stub()
        await sut.upsert(model)

        let stream = await sut.stream(replayCurrentValue: true)
        var iterator = stream.makeAsyncIterator()
        let replayed = await iterator.next()

        #expect(replayed == model)
    }

    @Test("stream without replay does not emit current value")
    func streamNoReplay() async {
        let model = PointPassLanding.stub()
        await sut.upsert(model)

        let stream = await sut.stream(replayCurrentValue: false)
        var iterator = stream.makeAsyncIterator()

        // Upsert a new value to verify the stream is listening
        let newModel = PointPassLanding.stub(id: "new")
        await sut.upsert(newModel)
        let emitted = await iterator.next()

        #expect(emitted == newModel)
    }

    @Test("removeAll emits nil to subscribers")
    func removeAllEmitsNil() async {
        let model = PointPassLanding.stub()
        await sut.upsert(model)

        let stream = await sut.stream(replayCurrentValue: false)
        var iterator = stream.makeAsyncIterator()

        await sut.removeAll()
        let emitted = await iterator.next()

        #expect(emitted == .some(nil))
    }
}
```
