---
name: network-layer
description: iOS Network/NetworkLive architecture reference — HTTP client, endpoint protocol, retry policies, bearer auth, and NetworkService. Loaded by the create-network-layer agent as its knowledge base.
---

# iOS Network Layer Reference

Architecture conventions for the generic `Networking` Swift package, split into two
library products: **`Network`** (the abstraction — endpoints, protocols, models, decoding)
and **`NetworkLive`** (the URLSession `HTTPClient` + `NetworkServiceLive`, depending on
`Network`). Feature code depends on `Network`; only the composition root pulls
`NetworkLive`. The `create-network-layer` agent uses these references to scaffold and
customize the stack.

## Architecture

```
Consumer (feature service)
  → NetworkService              (fetch<T: Decodable>(from:dateFormat:))
    → NetworkClient             (URLSession abstraction)
      → HTTPClient              (retry loop + adapter chain)
        → [NetworkAdapter]      (BearerRequestAdapter, etc.)
        → RetryPolicy           (BasicRetryPolicy / BearerRetryPolicy)
    → EndpointInterpreter       (Endpoint → URLRequest)
      → Endpoint                (GetEndpoint / PostEndpoint / DeleteEndpoint)
        → BaseURL               (app-specific base URLs — customize per project)
```

## Layers

### Endpoint (read first — everything builds on it)

Read [references/endpoints.md](references/endpoints.md) for the full pattern.

Key rules:
- `Endpoint` protocol: `baseURL`, `path`, `queryParameters`, `headers`, `fixturesPath`
- Marker protocols: `GetEndpoint`, `PostEndpoint<Body>`, `DeleteEndpoint`
- `BaseURL` is a **placeholder** — replace with app-specific cases after scaffolding
- Naming: `Get<Resource>Endpoint`, `Post<Resource>Endpoint`

### HTTP Client

Read [references/client.md](references/client.md) for the full pattern.

Key rules:
- `NetworkClient` protocol — `URLSession` conforms by default
- `HTTPClient` — the retry/adapter loop; never used directly by feature code
- `BearerRequestAdapter` — injects `Authorization: Bearer {token}` header
- `HeaderConfiguration` — holds the bearer token closure
- `RetryPolicy` protocol + `BasicRetryPolicy` (5xx) / `BearerRetryPolicy` (401 refresh)

### NetworkService

Read [references/service.md](references/service.md) for the full pattern.

Key rules:
- `NetworkService` protocol — feature services depend on this, not `HTTPClient`
- `NetworkServiceLive` — production implementation; creates a fresh decoder per call
- `DateFormat` — `.strategy` or `.custom` for per-call date decoding
- `EmptyDecodable` — use for endpoints that return no body

## File Organization

Two targets in one package. `Network` (abstraction) has no dependency on `NetworkLive`;
`NetworkLive` does `import Network`.

```
Sources/Network/                            ← abstraction product
├── Client/
│   ├── NetworkClient.swift                 ← protocol + URLSession conformance
│   └── NetworkError.swift
├── Endpoint/
│   ├── BaseURL.swift                        ← TODO: customize per app
│   ├── Endpoint.swift
│   ├── GetEndpoint.swift
│   ├── PostEndpoint.swift
│   ├── DeleteEndpoint.swift
│   ├── EndpointInterpreter.swift            ← public; builds URLRequest
│   ├── InterpretedHTTPMethod.swift
│   └── InterpretedEndpoint.swift
├── Service/
│   └── NetworkService.swift                 ← protocol only
├── Decoding/
│   ├── DateFormat.swift
│   ├── EmptyDecodable.swift
│   └── JSONDecoder+MixedDate.swift
└── Utility/
    └── URLResponse+Success.swift

Sources/NetworkLive/                        ← concrete product (import Network)
├── Client/
│   ├── HTTPClient.swift
│   └── HTTP/
│       ├── HeaderConfiguration.swift
│       ├── BearerHTTPClient/
│       │   ├── BearerRequestAdapter.swift   ← NetworkAdapter protocol lives here
│       │   └── TokenRefreshing.swift
│       └── RetryPolicy/
│           ├── RetryDirective.swift         ← RetryPolicy protocol + RetryDecision
│           ├── BasicRetryPolicy.swift
│           └── BearerRetryPolicy.swift
└── Service/
    └── NetworkServiceLive.swift
```

## Scaffold Script

```bash
plugins/ios-network-layer/scripts/create-network-layer.sh [target-dir]
```

Stamps out a `Networking` package with both products. `BaseURL.swift` is a TODO
placeholder — the agent fills it in after running the script.
