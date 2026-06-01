#!/usr/bin/env bash
# create-network-layer.sh
# Stamps out a complete Networking Swift package at the target directory, split
# into two library products:
#   • Networking      — the abstraction: protocols, endpoints, models, decoding.
#   • NetworkingLive  — the concrete URLSession implementation (depends on Networking).
# Feature code depends on `Networking`; only the composition root pulls `NetworkingLive`.
#
# NOTE: the abstraction module is `Networking`, NOT `Network` — a module named
# `Network` collides with Apple's system `Network.framework` (e.g. WebKit pulls
# `Network.ProxyConfiguration`), which breaks any target that imports both.
#
# Usage:
#   ./create-network-layer.sh [target-directory]
#
# If no target is given, the current directory is used.
# A Package.swift is created only if one does not already exist.

set -euo pipefail

TARGET="${1:-.}"

echo "→ Scaffolding Networking (Networking + NetworkingLive) at: $TARGET"

# ---------------------------------------------------------------------------
# Directory structure
# ---------------------------------------------------------------------------
mkdir -p "$TARGET/Sources/Networking/Client"
mkdir -p "$TARGET/Sources/Networking/Endpoint"
mkdir -p "$TARGET/Sources/Networking/Service"
mkdir -p "$TARGET/Sources/Networking/Decoding"
mkdir -p "$TARGET/Sources/Networking/Utility"
mkdir -p "$TARGET/Sources/NetworkingLive/Client/HTTP/BearerHTTPClient"
mkdir -p "$TARGET/Sources/NetworkingLive/Client/HTTP/RetryPolicy"
mkdir -p "$TARGET/Sources/NetworkingLive/Service"
mkdir -p "$TARGET/Tests/NetworkingLiveTests"

# ===========================================================================
# Networking — abstraction target
# ===========================================================================

# --- Client -----------------------------------------------------------------
cat > "$TARGET/Sources/Networking/Client/NetworkClient.swift" << 'EOF'
import Foundation

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// Abstraction over URLSession for testability. The `URLSession` conformance
/// lives here (trivial glue) so callers in any module can pass `.shared`.
public protocol NetworkClient: Sendable {
  func data(for request: URLRequest, delegate: (any URLSessionTaskDelegate)?) async throws -> (
    Data, URLResponse
  )
}

extension URLSession: NetworkClient {}
EOF

cat > "$TARGET/Sources/Networking/Client/NetworkError.swift" << 'EOF'
import Foundation

/// Errors thrown by NetworkService.
/// Canonical network errors understood by the retry policy.
public enum NetworkError: Error, Equatable {
    case unauthorized          // 401 / 403
    case clientError(Int)      // other 4xx
    case serverError(Int)      // 5xx
    case transport(URLError)   // connectivity / TLS, etc.
    case noToken
    case unknown
}
EOF

# --- Endpoint ---------------------------------------------------------------
cat > "$TARGET/Sources/Networking/Endpoint/BaseURL.swift" << 'EOF'
// TODO: Replace with your app's actual base URLs.
// Add a case for each host your app communicates with.
//
// Example:
//   case api    = "https://api.yourapp.com"
//   case cdn    = "https://cdn.yourapp.com"
//
public enum BaseURL: String, Sendable {
    case api = "https://api.example.com"
}
EOF

cat > "$TARGET/Sources/Networking/Endpoint/Endpoint.swift" << 'EOF'
import Foundation

/// Defines the information needed to build a network request.
public protocol Endpoint: Sendable {
  var baseURL: BaseURL { get }
  var path: String { get }
  var queryParameters: [String: String]? { get }
  var headers: [String: String]? { get }
  var fixturesPath: String? { get }
}

extension Endpoint {
  public var fixturesPath: String? { nil }
}
EOF

cat > "$TARGET/Sources/Networking/Endpoint/GetEndpoint.swift" << 'EOF'
import Foundation

/// Marker protocol for read-only GET requests.
public protocol GetEndpoint: Endpoint {}
EOF

cat > "$TARGET/Sources/Networking/Endpoint/PostEndpoint.swift" << 'EOF'
import Foundation

/// Endpoint for requests that send an encodable body.
public protocol PostEndpoint<Body>: Endpoint {
  associatedtype Body: NetworkRequestBody
  var requestBody: Body? { get }
}

public typealias NetworkRequestBody = Sendable & Encodable
EOF

cat > "$TARGET/Sources/Networking/Endpoint/DeleteEndpoint.swift" << 'EOF'
import Foundation

/// Marker protocol for DELETE requests.
public protocol DeleteEndpoint: Endpoint {}
EOF

cat > "$TARGET/Sources/Networking/Endpoint/InterpretedHTTPMethod.swift" << 'EOF'
import Foundation

/// String-based representation of HTTP methods.
public enum InterpretedHTTPMethod: String {
  case get = "GET"
  case post = "POST"
  case put = "PUT"
  case delete = "DELETE"
}
EOF

cat > "$TARGET/Sources/Networking/Endpoint/InterpretedEndpoint.swift" << 'EOF'
import Foundation

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// A fully constructed request derived from an Endpoint.
public struct InterpretedEndpoint {
  public let urlRequest: URLRequest
  public init(urlRequest: URLRequest) { self.urlRequest = urlRequest }
}
EOF

cat > "$TARGET/Sources/Networking/Endpoint/EndpointInterpreter.swift" << 'EOF'
import Foundation

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// Converts Endpoint values into URLRequest objects. Public so the live
/// service (in NetworkingLive) can build requests from the abstraction.
public struct EndpointInterpreter {
  public static func interpret(endpoint: Endpoint) -> URLRequest? {
    guard let url = URL(string: endpoint.baseURL.rawValue + endpoint.path) else { return nil }
    var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
    components?.queryItems = endpoint.queryParameters?.map {
      URLQueryItem(name: $0.key, value: $0.value)
    }

    guard let finalURL = components?.url else { return nil }
    var request = URLRequest(url: finalURL)
    request.allHTTPHeaderFields = endpoint.headers

    if let post = endpoint as? any PostEndpoint {
      request.httpMethod = InterpretedHTTPMethod.post.rawValue
      if let body = post.requestBody {
        request.httpBody = try? JSONEncoder().encode(body)
      }
    } else if endpoint is DeleteEndpoint {
      request.httpMethod = InterpretedHTTPMethod.delete.rawValue
    } else if endpoint is GetEndpoint {
      request.httpMethod = InterpretedHTTPMethod.get.rawValue
    }

    return request
  }
}
EOF

# --- Service (protocol) -----------------------------------------------------
cat > "$TARGET/Sources/Networking/Service/NetworkService.swift" << 'EOF'
import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Interface for fetching and decoding network resources.
public protocol NetworkService: Sendable {
    func fetch<T: Decodable>(
        from endpoint: Endpoint,
        dateFormat: DateFormat?
    ) async throws -> T
}

extension NetworkService {
    /// Fetches a resource and ignores the decoded response.
    public func fetch(from endpoint: Endpoint, dateFormat: DateFormat?) async throws {
        _ = try await fetch(from: endpoint, dateFormat: dateFormat) as EmptyDecodable
    }

    public func fetch(from endpoint: Endpoint) async throws {
        _ = try await fetch(from: endpoint, dateFormat: nil) as EmptyDecodable
    }

    public func fetch<T: Decodable>(from endpoint: Endpoint) async throws -> T {
        try await fetch(from: endpoint, dateFormat: nil)
    }
}
EOF

# --- Decoding ---------------------------------------------------------------
cat > "$TARGET/Sources/Networking/Decoding/DateFormat.swift" << 'EOF'
public import Foundation

/// Convenience enum so call-sites can pass either a built-in
/// strategy or a named custom formatter.
public enum DateFormat {
    /// Use one of JSONDecoder's standard strategies.
    case strategy(JSONDecoder.DateDecodingStrategy)
    /// Provide a custom formatter (internally mapped to `.formatted(_)`).
    case custom(DateFormatter)

    public var decoderStrategy: JSONDecoder.DateDecodingStrategy {
        switch self {
        case .strategy(let s): return s
        case .custom(let fmt): return .formatted(fmt)
        }
    }
}
EOF

cat > "$TARGET/Sources/Networking/Decoding/EmptyDecodable.swift" << 'EOF'
/// A placeholder type used to decode empty responses.
public struct EmptyDecodable: Decodable, ExpressibleByNilLiteral {
  public init(nilLiteral: ()) {}
  public init(from decoder: Decoder) throws {}
}
EOF

cat > "$TARGET/Sources/Networking/Decoding/JSONDecoder+MixedDate.swift" << 'EOF'
public import Foundation

extension JSONDecoder {
    /// A decoder that handles both ISO-8601 timestamps ("2025-05-30T18:30:00Z")
    /// and plain date strings ("2025-05-30") in the same payload.
    public static func mixedDateDecoder() -> JSONDecoder {
        let d = JSONDecoder()

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]

        let short = DateFormatter()
        short.dateFormat = "yyyy-MM-dd"
        short.timeZone   = TimeZone.current
        short.locale     = .init(identifier: "en_US_POSIX")

        d.dateDecodingStrategy = .custom { decoder in
            let c = try decoder.singleValueContainer()
            let s = try c.decode(String.self)
            if let date = iso.date(from: s)   { return date }
            if let date = short.date(from: s) { return date }
            throw DecodingError.dataCorruptedError(
                in: c,
                debugDescription: "Unrecognised date: \(s)"
            )
        }
        return d
    }
}
EOF

# --- Utility ----------------------------------------------------------------
cat > "$TARGET/Sources/Networking/Utility/URLResponse+Success.swift" << 'EOF'
import Foundation

extension URLResponse {
    /// Returns true if the HTTP response status code is in the 200–299 range.
    public var isHTTPSuccess: Bool {
        guard let httpResponse = self as? HTTPURLResponse else { return false }
        return (200...299).contains(httpResponse.statusCode)
    }
}
EOF

# ===========================================================================
# NetworkingLive — concrete implementation target (depends on Networking)
# ===========================================================================

# --- Client -----------------------------------------------------------------
cat > "$TARGET/Sources/NetworkingLive/Client/HTTPClient.swift" << 'EOF'
import Foundation
import Networking

public struct HTTPClient: NetworkClient {
    private let session: any NetworkClient
    private let adapters: [any NetworkAdapter]
    private let policy: any RetryPolicy
    private let clock: any Clock<Duration>

    public init(
        session: any NetworkClient = URLSession.shared,
        adapters: [any NetworkAdapter] = [],
        policy: any RetryPolicy,
        clock: any Clock<Duration> = ContinuousClock()
    ) {
        self.session = session
        self.adapters = adapters
        self.policy = policy
        self.clock = clock
    }

    public func data(
        for request: URLRequest,
        delegate: (any URLSessionTaskDelegate)? = nil
    ) async throws -> (Data, URLResponse) {
        try await execute(request, delegate: delegate)
    }

    // MARK: - Core executor

    @discardableResult
    public func execute(
        _ original: URLRequest,
        delegate: (any URLSessionTaskDelegate)? = nil
    ) async throws -> (Data, URLResponse) {
        var attempt = 0
        var request = try await adapters.adapt(original)

        while true {
            do {
                let (data, response) = try await session.data(for: request, delegate: delegate)
                try classifyAndThrowIfNeeded(response)
                return (data, response)
            } catch {
                let (_, mapped) = map(error: error)

                switch try await policy.decision(for: mapped, attempt: attempt) {
                case .retry(let delay):
                    attempt += 1
                    if delay > .zero { try await clock.sleep(for: delay) }
                    request = try await adapters.adapt(original)
                case .fail:
                    throw mapped
                }
            }
        }
    }

    private func classifyAndThrowIfNeeded(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { return }
        switch http.statusCode {
        case 200..<300: return
        case 401, 403:  throw NetworkError.unauthorized
        case 400..<500: throw NetworkError.clientError(http.statusCode)
        case 500..<600: throw NetworkError.serverError(http.statusCode)
        default:        throw NetworkError.unknown
        }
    }

    private func map(error: Error) -> (Int?, NetworkError) {
        if let urlErr = error as? URLError {
            let ns = urlErr as NSError
            let status = (ns.userInfo[NSURLErrorFailingURLErrorKey]
                          as? HTTPURLResponse)?.statusCode
            return (status, .transport(urlErr))
        }
        if let net = error as? NetworkError { return (nil, net) }
        return (nil, .unknown)
    }
}
EOF

# --- Adapters ---------------------------------------------------------------
cat > "$TARGET/Sources/NetworkingLive/Client/HTTP/BearerHTTPClient/BearerRequestAdapter.swift" << 'EOF'
public import Foundation
import Networking

public protocol NetworkAdapter: Sendable {
    func adapt(_ request: URLRequest) async throws -> URLRequest
}

extension Sequence where Element == any NetworkAdapter {
    /// Serially applies each adapter; throws on the first failure.
    func adapt(_ req: URLRequest) async throws -> URLRequest {
        var r = req
        for ad in self { r = try await ad.adapt(r) }
        return r
    }
}

/// Injects a bearer token into the Authorization header.
public struct BearerRequestAdapter: NetworkAdapter {
    private let configuration: HeaderConfiguration

    public init(configuration: HeaderConfiguration) { self.configuration = configuration }

    public func adapt(_ request: URLRequest) async throws -> URLRequest {
        var r = request
        guard let bearer = await configuration.bearerToken() else {
            throw NetworkError.noToken
        }
        r.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization")
        return r
    }
}
EOF

cat > "$TARGET/Sources/NetworkingLive/Client/HTTP/HeaderConfiguration.swift" << 'EOF'
import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Configuration containing tokens required for authenticated requests.
public struct HeaderConfiguration: Sendable {
    public typealias BearerToken = @Sendable () async -> String?

    /// Async closure that returns the current bearer token, or nil if unavailable.
    public let bearerToken: BearerToken

    public init(bearerToken: @escaping BearerToken) {
        self.bearerToken = bearerToken
    }
}
EOF

cat > "$TARGET/Sources/NetworkingLive/Client/HTTP/BearerHTTPClient/TokenRefreshing.swift" << 'EOF'
import Foundation

/// Abstraction for objects capable of refreshing bearer tokens.
public protocol TokenRefreshing: Sendable {
  func refreshToken() async throws
}
EOF

# --- Retry policies ---------------------------------------------------------
cat > "$TARGET/Sources/NetworkingLive/Client/HTTP/RetryPolicy/RetryDirective.swift" << 'EOF'
import Foundation
import Networking

/// Possible actions after inspecting an HTTP error.
public enum RetryDecision {
    /// Retry after an optional delay.
    case retry(after: Duration = .zero)
    /// Give up and surface the error.
    case fail
}

/// A strategy object that decides whether to retry and can run pre-retry
/// side-effects (e.g. token refresh). Keeps HTTPClient unaware of auth.
public protocol RetryPolicy: Sendable {
    func decision(
        for error: NetworkError,
        attempt: Int
    ) async throws -> RetryDecision
}
EOF

cat > "$TARGET/Sources/NetworkingLive/Client/HTTP/RetryPolicy/BasicRetryPolicy.swift" << 'EOF'
import Networking

/// Retries once on 5xx with a short backoff. Never refreshes tokens.
public struct BasicRetryPolicy: RetryPolicy {
    private let backoffBase = 200 // ms

    public init() {}

    public func decision(
        for error: NetworkError,
        attempt: Int
    ) async throws -> RetryDecision {
        switch error {
        case .serverError:
            .retry(after: .milliseconds(backoffBase))
        default:
            .fail
        }
    }
}
EOF

cat > "$TARGET/Sources/NetworkingLive/Client/HTTP/RetryPolicy/BearerRetryPolicy.swift" << 'EOF'
import Networking

/// Refreshes the bearer token on the first 401/403, then retries once.
/// Falls back to basic 5xx retry for server errors.
public struct BearerRetryPolicy: RetryPolicy {
    private let refresher: any TokenRefreshing
    private let backoffBase = 200

    public init(refresher: any TokenRefreshing) { self.refresher = refresher }

    public func decision(
        for error: NetworkError,
        attempt: Int
    ) async throws -> RetryDecision {
        guard attempt == 0 else { return .fail }

        switch error {
        case .unauthorized:
            try await refresher.refreshToken()
            return .retry()
        case .serverError:
            return .retry(after: .milliseconds(backoffBase))
        default:
            return .fail
        }
    }
}
EOF

# --- Service (live) ---------------------------------------------------------
cat > "$TARGET/Sources/NetworkingLive/Service/NetworkServiceLive.swift" << 'EOF'
public import Foundation
import Networking

/// Production implementation of NetworkService.
public struct NetworkServiceLive: NetworkService {
    private let client: any NetworkClient
    private let baseJSONDecoder: JSONDecoder

    public init(client: any NetworkClient, jsonDecoder baseJSONDecoder: JSONDecoder) {
        self.client = client
        self.baseJSONDecoder = baseJSONDecoder
    }

    public func fetch<T: Decodable>(from endpoint: Endpoint, dateFormat: DateFormat? = nil) async throws -> T {
        guard let request = EndpointInterpreter.interpret(endpoint: endpoint) else {
            throw NetworkError.unknown
        }

        let (data, _): (Data, URLResponse) = try await client.data(for: request, delegate: nil)

        // Build a fresh decoder so concurrent calls don't share mutable state.
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = baseJSONDecoder.keyDecodingStrategy
        decoder.dataDecodingStrategy = baseJSONDecoder.dataDecodingStrategy
        decoder.nonConformingFloatDecodingStrategy = baseJSONDecoder.nonConformingFloatDecodingStrategy

        if let format = dateFormat {
            decoder.dateDecodingStrategy = format.decoderStrategy
        } else {
            decoder.dateDecodingStrategy = baseJSONDecoder.dateDecodingStrategy
        }

        return try decoder.decode(T.self, from: data)
    }
}
EOF

# ===========================================================================
# Tests (NetworkingLive) — placeholder so the test target isn't empty
# ===========================================================================
cat > "$TARGET/Tests/NetworkingLiveTests/NetworkingLiveTests.swift" << 'EOF'
import XCTest
@testable import NetworkingLive

final class NetworkingLiveTests: XCTestCase {
    func testScaffoldCompiles() {
        XCTAssertTrue(true)
    }
}
EOF

# ---------------------------------------------------------------------------
# Package.swift (only if one doesn't already exist)
# ---------------------------------------------------------------------------
if [ ! -f "$TARGET/Package.swift" ]; then
cat > "$TARGET/Package.swift" << 'EOF'
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Networking",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "Networking", targets: ["Networking"]),
        .library(name: "NetworkingLive", targets: ["NetworkingLive"]),
    ],
    targets: [
        .target(
            name: "Networking",
            path: "Sources/Networking"
        ),
        .target(
            name: "NetworkingLive",
            dependencies: ["Networking"],
            path: "Sources/NetworkingLive"
        ),
        .testTarget(
            name: "NetworkingLiveTests",
            dependencies: ["NetworkingLive"],
            path: "Tests/NetworkingLiveTests"
        ),
    ]
)
EOF
    echo "  ✓ Package.swift created"
else
    echo "  ↷ Package.swift already exists — skipping (add Networking + NetworkingLive targets manually)"
fi

echo ""
echo "✅ Networking scaffolded at $TARGET (products: Networking, NetworkingLive)"
echo ""
echo "Next steps:"
echo "  1. Open $TARGET/Sources/Networking/Endpoint/BaseURL.swift"
echo "     and replace the placeholder with your app's actual base URLs."
echo "  2. If your app uses auth headers beyond Authorization: Bearer,"
echo "     customize NetworkingLive's BearerRequestAdapter.swift."
echo "  3. Feature code depends on the 'Networking' product; wire 'NetworkingLive'"
echo "     (HTTPClient + NetworkServiceLive) only at the composition root."
