# NetworkService

`NetworkService` is the interface feature data-layer services depend on. It decouples features from `HTTPClient` internals.

> **Module:** the `NetworkService` protocol, `DateFormat`, `EmptyDecodable`, and the decoders live in **`Network`**; `NetworkServiceLive` lives in **`NetworkLive`**. Feature services `import Network` and depend on the protocol; the composition root `import NetworkLive` to build `NetworkServiceLive`.

## Protocol

```swift
public protocol NetworkService: Sendable {
    func fetch<T: Decodable>(
        from endpoint: Endpoint,
        dateFormat: DateFormat?
    ) async throws -> T
}
```

### Convenience overloads (extension)

```swift
// Ignore the response body (e.g. POST that returns 204)
func fetch(from endpoint: Endpoint, dateFormat: DateFormat?) async throws
func fetch(from endpoint: Endpoint) async throws

// Infer T from call site, no custom date format
func fetch<T: Decodable>(from endpoint: Endpoint) async throws -> T
```

## NetworkServiceLive

Production implementation. Creates a **fresh `JSONDecoder`** per call so concurrent decodes don't share mutable state.

```swift
public struct NetworkServiceLive: NetworkService {
    public init(client: any NetworkClient, jsonDecoder: JSONDecoder)
}
```

The `jsonDecoder` passed at init is used as a template — its `keyDecodingStrategy`, `dataDecodingStrategy`, and `nonConformingFloatDecodingStrategy` are copied. The `dateDecodingStrategy` is overridden per-call if a `DateFormat` is supplied.

## DateFormat

```swift
public enum DateFormat {
    case strategy(JSONDecoder.DateDecodingStrategy)
    case custom(DateFormatter)
}
```

**Usage:**

```swift
// ISO-8601 for a specific endpoint
let result: MyDTO = try await service.fetch(
    from: GetProfileEndpoint(),
    dateFormat: .strategy(.iso8601)
)

// Custom formatter
let fmt = DateFormatter()
fmt.dateFormat = "yyyy-MM-dd"
let result: MyDTO = try await service.fetch(
    from: GetEventsEndpoint(),
    dateFormat: .custom(fmt)
)
```

## JSONDecoder+MixedDate

For APIs that mix ISO-8601 timestamps (`2025-05-30T18:30:00Z`) and plain date strings (`2025-05-30`) in the same response:

```swift
let service = NetworkServiceLive(
    client: client,
    jsonDecoder: .mixedDateDecoder()
)
```

`mixedDateDecoder()` tries ISO-8601 first, then `yyyy-MM-dd`.

## EmptyDecodable

Use when an endpoint returns no body (empty 200/204):

```swift
// The protocol extension does this automatically when T is omitted:
try await service.fetch(from: PostActionEndpoint())
```

`EmptyDecodable` is `ExpressibleByNilLiteral` so it can be used as a nil placeholder in tests.

## How Feature Services Use NetworkService

A feature's network service takes `NetworkService` as a dependency, not `HTTPClient`:

```swift
public struct RemoteProfileService: ProfileService {
    private let networkService: any NetworkService

    public init(networkService: any NetworkService) {
        self.networkService = networkService
    }

    public func fetchProfile(userID: String) async throws -> ProfileDTO {
        try await networkService.fetch(from: GetProfileEndpoint(userID: userID))
    }
}
```

This keeps the feature package testable by swapping in a mock `NetworkService`.

## Rules

| Rule | Why |
|------|-----|
| Depend on `NetworkService`, not `NetworkServiceLive` | Mockable in tests |
| Fresh decoder per call | Concurrent calls can't corrupt shared state |
| Pass `dateFormat` at call site | Same service handles varied date formats per endpoint |
| `EmptyDecodable` for no-body responses | Avoids nullable return types at call sites |
