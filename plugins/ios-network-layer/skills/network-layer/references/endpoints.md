# Endpoints

Endpoints are pure value types that describe a request — URL, method, body, query params — without touching networking code. `EndpointInterpreter` converts them to `URLRequest`.

> **Module:** all endpoint types (and `EndpointInterpreter`) live in the **`Network`** abstraction product.

## Core Shape

```swift
// Endpoint.swift — base protocol
public protocol Endpoint: Sendable {
    var baseURL: BaseURL { get }
    var path: String { get }
    var queryParameters: [String: String]? { get }
    var headers: [String: String]? { get }
    var fixturesPath: String? { get }  // default: nil
}

// Marker protocols
public protocol GetEndpoint: Endpoint {}
public protocol DeleteEndpoint: Endpoint {}
public protocol PostEndpoint<Body>: Endpoint {
    associatedtype Body: NetworkRequestBody
    var requestBody: Body? { get }
}
public typealias NetworkRequestBody = Sendable & Encodable
```

## BaseURL

`BaseURL` is a **project-specific placeholder**. After running the scaffold script, replace the template with your app's actual hosts:

```swift
// Before (scaffolded placeholder)
public enum BaseURL: String, Sendable {
    case api = "https://api.example.com"
}

// After (your app)
public enum BaseURL: String, Sendable {
    case api     = "https://api.yourapp.com"
    case uploads = "https://uploads.yourapp.com"
}
```

## Writing an Endpoint

```swift
// GET /api/v1/profile?userID=123
struct GetProfileEndpoint: GetEndpoint {
    let userID: String

    var baseURL: BaseURL { .api }
    var path: String { "/api/v1/profile" }
    var queryParameters: [String: String]? { ["userID": userID] }
    var headers: [String: String]? { nil }
}

// POST /api/v1/reservations
struct PostReservationEndpoint: PostEndpoint {
    typealias Body = ReservationRequest

    var baseURL: BaseURL { .api }
    var path: String { "/api/v1/reservations" }
    var queryParameters: [String: String]? { nil }
    var headers: [String: String]? { nil }
    let requestBody: ReservationRequest?
}
```

## EndpointInterpreter

`EndpointInterpreter.interpret(endpoint:)` is called internally by `NetworkServiceLive`. It:
1. Combines `baseURL.rawValue + path` → `URL`
2. Appends `queryParameters` as `URLQueryItem`s
3. Sets `allHTTPHeaderFields` from `headers`
4. Switches on protocol conformance to set `httpMethod` (GET/POST/DELETE)
5. JSON-encodes `requestBody` for `PostEndpoint` conformances

Feature code never calls `EndpointInterpreter` directly.

## Naming

| HTTP method | Protocol | Naming |
|-------------|----------|--------|
| GET | `GetEndpoint` | `Get<Resource>Endpoint` |
| POST | `PostEndpoint` | `Post<Resource>Endpoint` |
| DELETE | `DeleteEndpoint` | `Delete<Resource>Endpoint` |

## Rules

| Rule | Why |
|------|-----|
| `Sendable` | Endpoints cross concurrency boundaries |
| No init stored on protocol | Each endpoint is its own lightweight struct |
| `fixturesPath` default nil | Test fixtures opt-in, not required |
| `queryParameters` nil (not empty) | Avoids appending `?` with no items |
