# Network Service

Each domain gets its own service — a stateless struct that hits the API and returns DTOs.

## Core Shape

```swift
@Mocked
public protocol PointPassService: Sendable {
    func getLanding() async throws -> PointPassLandingDTO
    func getDetails(for id: String) async throws -> PointPassDetailsDTO
}

public struct RemotePointPassService: PointPassService {
    private let httpClient: any GatewayHTTPClient

    public init(httpClient: any GatewayHTTPClient) {
        self.httpClient = httpClient
    }

    public func getLanding() async throws -> PointPassLandingDTO {
        let descriptor = GetPointPassLandingDescriptor()
        return try await httpClient.request(descriptor: descriptor)
    }

    public func getDetails(for id: String) async throws -> PointPassDetailsDTO {
        let descriptor = GetPointPassDetailsDescriptor(id: id)
        return try await httpClient.request(descriptor: descriptor)
    }
}
```

## Descriptors

Descriptors encapsulate request configuration:

```swift
struct GetPointPassLandingDescriptor: APIDescriptor {
    let path = "/api/v1/pointpass/landing"
    let method: HTTPMethod = .get
}

struct GetPointPassDetailsDescriptor: APIDescriptor {
    let id: String
    var path: String { "/api/v1/pointpass/\(id)/details" }
    let method: HTTPMethod = .get
}
```

**Scan the target package** for the existing descriptor protocol (`APIDescriptor`, `GatewayDescriptor`, etc.) and HTTP client type before generating.

## Where It Lives

```
Network/
├── <Domain>Service.swift              (protocol)
├── Remote<Domain>Service.swift        (implementation)
└── Get<Resource>Descriptor.swift
```

## Naming

| Protocol | Implementation |
|----------|---------------|
| `<Domain>Service` | `Remote<Domain>Service` |

Descriptor naming: `Get<Resource>Descriptor`, `Post<Resource>Descriptor`

## Rules

| Rule | Why |
|------|-----|
| Sendable struct | Stateless, concurrency-safe |
| Returns DTO, not domain model | Mapping is the mapper's job |
| `async throws` | Propagates network errors to caller |
| `@Mocked` protocol | Auto-generates test mocks |
| One service per domain | Prevents god-service bloat |
| No stored mutable state | Struct with only `let` dependencies |

## Testing

Verify the correct descriptor is built and the HTTP client is called:

```swift
@Suite
struct RemotePointPassServiceTests {
    private let httpClientMock = GatewayHTTPClientMock()
    private let sut: RemotePointPassService

    init() {
        sut = RemotePointPassService(httpClient: httpClientMock)
    }

    @Test("getLanding calls httpClient and returns DTO")
    func getLanding() async throws {
        let expectedDTO = PointPassLandingDTO.stub()
        httpClientMock._request.implementation = .returns(expectedDTO)

        let result = try await sut.getLanding()

        #expect(httpClientMock._request.callCount == 1)
        #expect(result == expectedDTO)
    }

    @Test("getLanding propagates client errors")
    func getLandingError() async {
        httpClientMock._request.implementation = .throws(TestError.network)

        await #expect(throws: TestError.network) {
            try await sut.getLanding()
        }
    }
}
```
