# HTTP Client

`HTTPClient` is the retry/adapter loop that sits between `NetworkService` and `URLSession`. Feature code never depends on it directly — feature services depend on `NetworkService`.

## Layers

```
HTTPClient          ← retry loop, adapter chain, status→error classification
  ↳ NetworkClient   ← URLSession abstraction (protocol)
  ↳ [NetworkAdapter]← serial middleware chain (e.g. BearerRequestAdapter)
  ↳ RetryPolicy     ← decides retry vs fail; runs side-effects (token refresh)
```

## NetworkClient

```swift
public protocol NetworkClient: Sendable {
    func data(for request: URLRequest, delegate: (any URLSessionTaskDelegate)?) async throws -> (Data, URLResponse)
}
// URLSession conforms out of the box
```

## HTTPClient

```swift
public init(
    session: any NetworkClient = URLSession.shared,
    adapters: [any NetworkAdapter] = [],
    policy: any RetryPolicy,
    clock: any Clock<Duration> = ContinuousClock()
)
```

The retry loop:
1. Adapts the original request through the adapter chain
2. Executes via `session.data(for:delegate:)`
3. On success: returns `(Data, URLResponse)`
4. On error: maps to `NetworkError`, asks the policy, retries or fails
5. On retry: re-adapts the original request (picks up refreshed token)

## NetworkAdapter + BearerRequestAdapter

```swift
public protocol NetworkAdapter: Sendable {
    func adapt(_ request: URLRequest) async throws -> URLRequest
}

public struct BearerRequestAdapter: NetworkAdapter {
    private let configuration: HeaderConfiguration
    // Injects: Authorization: Bearer {token}
    // Throws NetworkError.noToken if token closure returns nil
}
```

`HeaderConfiguration` holds the bearer token as an async closure:

```swift
public struct HeaderConfiguration: Sendable {
    public typealias BearerToken = @Sendable () async -> String?
    public let bearerToken: BearerToken
}
```

**Customizing headers:** If your app needs additional headers (API keys, device IDs), add a new `NetworkAdapter` conformance rather than modifying `BearerRequestAdapter`. Chain it alongside `BearerRequestAdapter` in the `adapters` array.

## Retry Policies

### BasicRetryPolicy

Retries once on any 5xx with 200ms backoff. Never touches auth:

```swift
let policy = BasicRetryPolicy()
```

### BearerRetryPolicy

On the first 401/403: calls `refresher.refreshToken()`, then retries once. Also retries on 5xx.

```swift
let policy = BearerRetryPolicy(refresher: myTokenRefresher)
```

Implement `TokenRefreshing` in your auth layer:

```swift
public protocol TokenRefreshing: Sendable {
    func refreshToken() async throws
}
```

## NetworkError

```swift
public enum NetworkError: Error, Equatable {
    case unauthorized          // 401 / 403
    case clientError(Int)      // other 4xx
    case serverError(Int)      // 5xx
    case transport(URLError)   // connectivity / TLS
    case noToken               // bearer closure returned nil
    case unknown
}
```

Feature services propagate `NetworkError` as-is — mappers and repositories handle it at their boundary.

## Assembly Example

```swift
let configuration = HeaderConfiguration {
    await tokenStore.currentToken
}

let client = HTTPClient(
    adapters: [BearerRequestAdapter(configuration: configuration)],
    policy: BearerRetryPolicy(refresher: tokenStore)
)

let service = NetworkServiceLive(
    client: client,
    jsonDecoder: .mixedDateDecoder()
)
```

## Rules

| Rule | Why |
|------|-----|
| Feature services depend on `NetworkService`, not `HTTPClient` | Keeps features unaware of retry/auth plumbing |
| Re-adapt on retry | Ensures refreshed tokens are picked up |
| `clock` is injected | Enables time-controlled tests without real sleeps |
| New adapters for new headers | Keeps `BearerRequestAdapter` single-purpose |
