Infrastructure package: a cross-cutting capability, split into two targets — `Foo` (abstraction) and `FooLive` (implementation), each its own `.library` product.

- Consumers import `Foo` (protocols + plain models), never `FooLive`.
- `FooLive` is pulled only at the composition root, so tests substitute a mock.
- Each target owns its own `CLAUDE.md`; read the one for the target you're editing.
- IMPORTANT: heavy/third-party dependencies (SwiftProtobuf, CoreData, URLSession glue) live ONLY in `FooLive`.

See the swift-modularization skill (infra package) for rationale + structure.
