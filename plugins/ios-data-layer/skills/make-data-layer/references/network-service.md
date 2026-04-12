# Network Service

Each domain gets its own service — a stateless struct that hits the API and returns DTOs.

## Core Shape

Feature services inject `NetworkService` from NetworkKit and define their own endpoint types:

```swift
@Mocked
public protocol PointPassService: Sendable {
    func getLanding() async throws -> PointPassLandingDTO
    func getDetails(for id: String) async throws -> PointPassDetailsDTO
}

public struct RemotePointPassService: PointPassService {
    private let networkService: any NetworkService

    public init(networkService: any NetworkService) {
        self.networkService = networkService
    }

    public func getLanding() async throws -> PointPassLandingDTO {
        try await networkService.fetch(from: GetPointPassLandingEndpoint())
    }

    public func getDetails(for id: String) async throws -> PointPassDetailsDTO {
        try await networkService.fetch(from: GetPointPassDetailsEndpoint(id: id))
    }
}
```

## Endpoints

Each service method gets its own endpoint type conforming to `GetEndpoint`, `PostEndpoint`, or `DeleteEndpoint`:

```swift
struct GetPointPassLandingEndpoint: GetEndpoint {
    var baseURL: BaseURL { .api }
    var path: String { "/api/v1/pointpass/landing" }
    var queryParameters: [String: String]? { nil }
    var headers: [String: String]? { nil }
}

struct GetPointPassDetailsEndpoint: GetEndpoint {
    let id: String
    var baseURL: BaseURL { .api }
    var path: String { "/api/v1/pointpass/\(id)/details" }
    var queryParameters: [String: String]? { nil }
    var headers: [String: String]? { nil }
}
```

**Scan the target package** for `NetworkService` usage and the project's `BaseURL` cases before generating. If NetworkKit is not present, use the `create-network-layer` agent to scaffold it first.

## Where It Lives

```
Network/
├── <Domain>Service.swift              (protocol)
├── Remote<Domain>Service.swift        (implementation)
└── Get<Resource>Endpoint.swift
```

## Naming

| Protocol | Implementation |
|----------|---------------|
| `<Domain>Service` | `Remote<Domain>Service` |

Endpoint naming: `Get<Resource>Endpoint`, `Post<Resource>Endpoint`, `Delete<Resource>Endpoint`

## Rules

| Rule | Why |
|------|-----|
| Sendable struct | Stateless, concurrency-safe |
| Returns DTO, not domain model | Mapping is the mapper's job |
| `async throws` | Propagates network errors to caller |
| `@Mocked` protocol | Auto-generates test mocks |
| One service per domain | Prevents god-service bloat |
| Inject `any NetworkService` | Mockable in tests without touching HTTP |
| One endpoint type per call | Keeps request configs explicit and testable |

## Testing

Verify the correct endpoint is built and `NetworkService` is called:

```swift
@Suite
struct RemotePointPassServiceTests {
    private let networkServiceMock = NetworkServiceMock()
    private let sut: RemotePointPassService

    init() {
        sut = RemotePointPassService(networkService: networkServiceMock)
    }

    @Test("getLanding fetches from correct endpoint and returns DTO")
    func getLanding() async throws {
        let expectedDTO = PointPassLandingDTO.stub()
        networkServiceMock._fetch.implementation = .returns(expectedDTO)

        let result = try await sut.getLanding()

        #expect(networkServiceMock._fetch.callCount == 1)
        let endpoint = networkServiceMock._fetch.lastInvocation?.endpoint as? GetPointPassLandingEndpoint
        #expect(endpoint != nil)
        #expect(result == expectedDTO)
    }

    @Test("getLanding propagates network errors")
    func getLandingError() async {
        networkServiceMock._fetch.implementation = .throws(NetworkError.serverError(500))

        await #expect(throws: NetworkError.serverError(500)) {
            try await sut.getLanding()
        }
    }
}
```
