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
