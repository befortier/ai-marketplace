Abstraction target (`Foo`): protocols and plain request/response models for this capability.

- One protocol per file; plain `Sendable` models alongside.
- No concrete implementations here — those live in `FooLive`.
- IMPORTANT: no heavy/third-party dependencies; this target stays buildable by every consumer.

See the swift-modularization skill (non-live target) for rationale + structure.
