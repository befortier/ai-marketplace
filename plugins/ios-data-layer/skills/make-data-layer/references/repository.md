# Repository

Repositories coordinate the data flow: fetch from service, map to domain, persist in store. They're the boundary that the rest of the app talks to.

## Core Shape

```swift
@Mocked
public protocol PointPassRepository: Sendable {
    func stream(replayCurrentValue: Bool) async -> AsyncStream<PointPassLanding?>
    func refresh() async throws
}

public struct DefaultPointPassRepository: PointPassRepository {
    private let service: any PointPassService
    private let mapper: any PointPassLandingMapping
    private let store: any PointPassStore

    public init(
        service: any PointPassService,
        mapper: any PointPassLandingMapping = PointPassLandingMapper(),
        store: any PointPassStore
    ) {
        self.service = service
        self.mapper = mapper
        self.store = store
    }

    public func stream(replayCurrentValue: Bool) async -> AsyncStream<PointPassLanding?> {
        await store.stream(replayCurrentValue: replayCurrentValue)
    }

    public func refresh() async throws {
        let dto = try await service.getLanding()
        let model = try mapper.map(dto)
        await store.upsert(model)
    }
}
```

## Fetch-and-Return Variant

When the caller needs the result directly (no store):

```swift
public struct DefaultPointPassRepository: PointPassRepository {
    private let service: any PointPassService
    private let mapper: any PointPassLandingMapping

    public func fetchLanding() async throws -> PointPassLanding {
        let dto = try await service.getLanding()
        return try mapper.map(dto)
    }
}
```

## Where It Lives

```
Repository/
├── <Domain>Repository.swift            (protocol)
└── Default<Domain>Repository.swift     (implementation)
```

## Naming

| Protocol | Implementation |
|----------|---------------|
| `<Domain>Repository` | `Default<Domain>Repository` |

## Rules

| Rule | Why |
|------|-----|
| `@Mocked` protocol | Auto-generates test mocks |
| Protocol dependencies with `any` | Enables mock injection |
| Default mapper in init | Callers only need to provide service + store |
| Thin orchestration | No business logic — that belongs in use cases |
| `async throws` for network methods | Propagates errors to caller |
| Struct preferred | Simpler than class; use `final class` only if reference semantics needed |

## Testing

Verify service→mapper→store orchestration and error propagation:

```swift
@Suite
struct DefaultPointPassRepositoryTests {
    private let serviceMock = PointPassServiceMock()
    private let mapperMock = PointPassLandingMappingMock()
    private let storeMock = PointPassStoreMock()
    private let sut: DefaultPointPassRepository

    init() {
        sut = DefaultPointPassRepository(
            service: serviceMock,
            mapper: mapperMock,
            store: storeMock
        )
    }

    @Test("refresh fetches, maps, and stores")
    func refreshSuccess() async throws {
        let dto = PointPassLandingDTO.stub()
        let model = PointPassLanding.stub()
        serviceMock._getLanding.implementation = .returns(dto)
        mapperMock._map.implementation = .returns(model)

        try await sut.refresh()

        #expect(serviceMock._getLanding.callCount == 1)
        #expect(mapperMock._map.callCount == 1)
        let storedModel = try #require(storeMock._upsert.lastInvocation)
        #expect(storedModel == model)
    }

    @Test("refresh propagates service errors")
    func refreshServiceError() async {
        serviceMock._getLanding.implementation = .throws(TestError.network)

        await #expect(throws: TestError.network) {
            try await sut.refresh()
        }
        #expect(storeMock._upsert.callCount == 0)
    }

    @Test("refresh propagates mapper errors")
    func refreshMapperError() async {
        serviceMock._getLanding.implementation = .returns(PointPassLandingDTO.stub())
        mapperMock._map.implementation = .throws(TestError.mapping)

        await #expect(throws: TestError.mapping) {
            try await sut.refresh()
        }
        #expect(storeMock._upsert.callCount == 0)
    }
}
```
