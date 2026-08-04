---
name: swift-mocking
description: Guidance on the swift-mocking package (@Mocked macro) for generating test mocks from protocols in Swift. Use when mocking protocols, stubbing dependencies, or asserting on invocations in Swift unit tests.
---

# Swift Mocking

## Overview

[swift-mocking](https://github.com/fetch-rewards/swift-mocking) is a macro that
generates a mock class from a protocol. It is Swift 6 / concurrency-safe and the
generated mocks are conditionally compiled (wrapped in `#if SWIFT_MOCKING_ENABLED` by
default). It is designed for the Swift Testing framework (`#expect`/`#require`).

- **Import:** `import Mocking` (`public import Mocking` from a module that vends
  `public` mockable protocols)
- **Why protocols:** a dependency must be a protocol to get an `@Mocked` mock — inject
  the mock in tests and the real implementation in production.

## Quick Start

Annotate a protocol; `@Mocked` generates `<Protocol>Mock`:

```swift
import Mocking

@Mocked
public protocol TokenRepository: Sendable {
    func retrieveCredentials(id: String?) throws -> AuthCredential
    func refreshAuthToken(credential: AuthCredential?) async throws
}
```

Use it in a test — stub behavior, inject, then assert on exact invocations:

```swift
let mock = TokenRepositoryMock()
mock._retrieveCredentials.implementation = .returns(mockCredential)

let sut = MyService(repository: mock)
try await sut.performOperation()

let call = try #require(mock._retrieveCredentials.lastInvocation)
#expect(call == nil)               // assert the exact argument passed
#expect(mock._retrieveCredentials.callCount == 1)
```

## Core API

Each protocol member generates a `_member` handle on the mock.

**Stub behavior** via `.implementation`:

```swift
mock._method.implementation = .returns(value)        // fixed value
mock._method.implementation = .throws(MyError.case)  // throw
mock._method.implementation = .invokes { param in    // computed
    return compute(param)
}
```

**Inspect calls** — always verify *what* was passed, not just that it happened:

```swift
mock._method.callCount                          // number of calls
try #require(mock._method.lastInvocation)       // args of the last call
mock._method.invocations                        // [args] for all calls
mock._method.returnedValues                     // values returned
```

Assert on `lastInvocation` / `invocations` (deep input verification) — never assert on
call count alone.

## Beyond the basics → references

| Topic | Read |
|-------|------|
| Compilation conditions, `Sendable`/`@MainActor`/actor conformance, `unchecked` variants | [references/configuration.md](references/configuration.md) |
| Property mocking (get/set), static members + reset, manual mocks (`@MockedMembers`), implementation-type table | [references/advanced-mocks.md](references/advanced-mocks.md) |

## Guidelines

- **`@Mocked` by default.** Only hand-write a mock (`@MockedMembers`) when the macro
  can't apply — e.g. protocol inheritance. See references/advanced-mocks.md.
- **Every injected protocol gets `@Mocked`** — mappers, providers, stream getters
  included, not just services.
- **Replace hand-written recorders when touched.** A test that hand-rolls a
  spy/recorder for a protocol gets migrated to the generated mock as part of the
  change.
- **Prefer checked implementations** (`.returns`/`.invokes`). Use the `unchecked`
  variants only for genuinely non-`Sendable` types.
- **Reset static mocks** between tests: `SomeMock.resetMockedStaticMembers()`.
- **Conform protocols to `Sendable`** where possible for concurrency safety.

## Common Mistakes

- **Asserting only `callCount`.** Verify arguments via `lastInvocation`/`invocations`.
- **Reaching for a manual mock first.** `@Mocked` covers almost everything; manual
  mocks are the fallback.
- **Using `unchecked` returns/invokes by habit.** They're only for non-`Sendable` types.
- **Forgetting `resetMockedStaticMembers()`** — static stubs leak across tests.
- **No `#if SWIFT_MOCKING_ENABLED` guard** around hand-written mocks.

## Reference Files

| File | When to read |
|------|-------------|
| [references/configuration.md](references/configuration.md) | `@Mocked` options: compilation conditions, Sendable/actor conformance, unchecked implementations |
| [references/advanced-mocks.md](references/advanced-mocks.md) | Property mocking, static members, manual `@MockedMembers` mocks, implementation-type reference table |
