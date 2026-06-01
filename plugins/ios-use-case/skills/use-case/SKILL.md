---
name: Use Case Pattern
description: This skill should be used when the user asks to "create a use case", "add a use case", "implement a use case", "write a use case", "new use case", or when implementing business logic that should be encapsulated as a callable struct conforming to a protocol. Also applies when discussing use case injection, callAsFunction, or the DefaultXxxUseCase naming convention.
---

# Use Case Pattern

Encapsulate a single unit of business logic as a `Sendable` struct that conforms to a protocol and is invoked via `callAsFunction()`. This pattern provides clear separation of concerns, testability through protocol-based injection, and a clean call-site syntax.

## Structure

Every use case consists of two parts:

### 1. Protocol

Define a protocol named after the use case's intent (e.g., `ToggleUserReactionUseCase`). The protocol must:

- Inherit from `Sendable`
- Declare a single `callAsFunction()` method with the appropriate signature

```swift
protocol ToggleUserReactionUseCase: Sendable {
    func callAsFunction(for userId: String) async throws
}
```

### 2. Default Implementation

Create a struct prefixed with `Default` that conforms to the protocol:

```swift
struct DefaultToggleUserReactionUseCase: ToggleUserReactionUseCase {
    private let reactionRepository: any ReactionRepository

    init(reactionRepository: any ReactionRepository) {
        self.reactionRepository = reactionRepository
    }

    func callAsFunction(for userId: String) async throws {
        try await reactionRepository.toggleReaction(for: userId)
    }
}
```

## Key Rules

1. **Protocol first** — always define a protocol for the use case.
2. **Sendable** — both the protocol and the struct must be `Sendable`.
3. **Struct, not class** — use cases are value types.
4. **`callAsFunction()`** — the single entry point. This enables clean call-site syntax.
5. **Inject by intent** — consumers receive the use case named by its purpose, not its implementation.
6. **Naming** — protocol: `VerbNounUseCase` (e.g., `ToggleUserReactionUseCase`). Implementation: `DefaultVerbNounUseCase` (e.g., `DefaultToggleUserReactionUseCase`).

## Injection and Invocation

Inject use cases by their protocol, named after their intent:

```swift
struct SomeViewModel {
    private let toggleUserReaction: any ToggleUserReactionUseCase

    init(toggleUserReaction: any ToggleUserReactionUseCase) {
        self.toggleUserReaction = toggleUserReaction
    }

    func onReactionTapped(userId: String) async throws {
        try await toggleUserReaction(for: userId)
    }
}
```

Notice the call site reads as `toggleUserReaction(for: userId)` — the `callAsFunction()` method allows invoking the use case like a function directly on the property.

## Checklist

- [ ] Protocol defined with `Sendable` conformance
- [ ] Protocol declares `callAsFunction()` as its single method
- [ ] Implementation is a `struct` prefixed with `Default`
- [ ] Implementation conforms to `Sendable`
- [ ] Dependencies injected via `init`
- [ ] Consumers inject the use case by its protocol type, named by intent
- [ ] Call site invokes the use case directly (e.g., `toggleUserReaction(...)`)
