---
name: Use Case Pattern
description: This skill should be used when the user asks to "create a use case", "add a use case", "implement a use case", "write a use case", "new use case", or when implementing business logic that should be encapsulated as a callable struct conforming to a protocol. Also applies when discussing use case injection, callAsFunction, or the DefaultXxxUseCase naming convention.
---

# Use Case Pattern

Encapsulate a single unit of business logic as a `Sendable` struct that conforms to a protocol and is invoked via `callAsFunction()`. This pattern provides clear separation of concerns, testability through protocol-based injection, and a clean call-site syntax.

## Earn Its Keep

A use case must own a real job: multi-dependency orchestration, a guard (e.g. auth), a vendor side effect. If `callAsFunction` only forwards to one repository or store method, delete the use case and inject the repository (or a closure) directly — pass-throughs don't survive review.

```swift
// Don't — a one-line pass-through; inject the repository instead
struct DefaultToggleUserReactionUseCase: ToggleUserReactionUseCase {
    private let reactionRepository: any ReactionRepository

    func callAsFunction(for userId: String) async throws {
        try await reactionRepository.toggleReaction(for: userId)
    }
}
```

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

Create a struct prefixed with `Default` that conforms to the protocol. Note that it owns a job — orchestrating the repository and a follow-up side effect — not just forwarding:

```swift
struct DefaultToggleUserReactionUseCase: ToggleUserReactionUseCase {
    private let reactionRepository: any ReactionRepository
    private let reminderScheduler: any ReactionReminderScheduling

    init(
        reactionRepository: any ReactionRepository,
        reminderScheduler: any ReactionReminderScheduling
    ) {
        self.reactionRepository = reactionRepository
        self.reminderScheduler = reminderScheduler
    }

    func callAsFunction(for userId: String) async throws {
        let isNowActive = try await reactionRepository.toggleReaction(for: userId)
        if isNowActive {
            try await reminderScheduler.scheduleReminder(for: userId)
        } else {
            await reminderScheduler.cancelReminder(for: userId)
        }
    }
}
```

## Key Rules

1. **Protocol first** — always define a protocol for the use case.
2. **Sendable** — both the protocol and the struct must be `Sendable`.
3. **Struct, not class** — use cases are value types.
4. **`callAsFunction()`** — the single entry point. This enables clean call-site syntax.
5. **Earn its keep** — `callAsFunction` does more than forward to a single dependency (see above).
6. **Inject by intent** — consumers receive the use case named by its purpose, not its implementation.
7. **Naming** — protocol: `VerbNounUseCase` (e.g., `ToggleUserReactionUseCase`). Implementation: `DefaultVerbNounUseCase`. Stream getters: `Get<Thing>StreamUseCase` (e.g., `GetActiveOrdersStreamUseCase`), still invoked via `callAsFunction()`.

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

## Bootstrap Use Cases

A scope's bootstrap use case starts the container's long-lived work and **is** its lifetime owner — no separate starter or observation types. It idempotently stores its own loop task into the container's lock (store-only-if-nil), and the first authenticated surface invokes it once:

```swift
struct DefaultBootstrapFeatureUseCase: BootstrapFeatureUseCase {
    private let container: FeatureContainer

    init(container: FeatureContainer) {
        self.container = container
    }

    func callAsFunction() {
        container.subscription.withLock { task in
            guard task == nil else { return }   // idempotent — a second call is a no-op
            task = Task {
                // observe a stream and feed the container's store
            }
        }
    }
}
```

See the `ios-container` skill for the container half of this pattern.

## Reusable Infrastructure Use Cases

Infrastructure helpers are use cases too — the pattern isn't limited to feature logic. A reusable `OpenRealmUseCase` in the storage package is the canonical example: one protocol, one `Default` struct, injected wherever a store needs to open the database.

## Checklist

- [ ] Protocol defined with `Sendable` conformance
- [ ] Protocol declares `callAsFunction()` as its single method
- [ ] `callAsFunction` owns a real job — not a one-line pass-through
- [ ] Implementation is a `struct` prefixed with `Default`
- [ ] Implementation conforms to `Sendable`
- [ ] Dependencies injected via `init`
- [ ] Consumers inject the use case by its protocol type, named by intent
- [ ] Call site invokes the use case directly (e.g., `toggleUserReaction(...)`)
