# @Mocked configuration

## Contents
- Compilation conditions
- Sendable conformance
- Actor / @MainActor protocols
- Unchecked implementations

## Compilation conditions

By default mocks are wrapped in `#if SWIFT_MOCKING_ENABLED` (the common case in
this codebase). Override when needed:

```swift
@Mocked                                  // default → SWIFT_MOCKING_ENABLED
public protocol MyService: Sendable {}

@Mocked(compilationCondition: .debug)    // wrap in #if DEBUG
public protocol MyService {}

@Mocked(compilationCondition: .none)     // no wrapping
public protocol MyService {}
```

## Sendable conformance

Control how the generated mock conforms to `Sendable`:

```swift
@Mocked                                       // checked, inherits from protocol
protocol Dependency: Sendable {}

@Mocked(sendableConformance: .unchecked)      // @unchecked Sendable
protocol Dependency: Sendable {}
```

Use `.unchecked` only when concurrency-safety can't be checked by the compiler but
you can guarantee it.

## Actor / @MainActor protocols

Works with global-actor-isolated and actor protocols:

```swift
@Mocked @MainActor
protocol MainActorService {
    var current: State { get }
    func update() async
}
```

## Unchecked implementations

For non-`Sendable` return values or closures, the macro provides `unchecked`
variants:

```swift
mock._method.implementation = .uncheckedReturns(nonSendableValue)
mock._method.implementation = .uncheckedInvokes { param in nonSendableValue }
```

Prefer the checked `.returns(...)` / `.invokes(...)` whenever the types allow it;
reach for `unchecked` only when a type genuinely cannot be `Sendable`.
