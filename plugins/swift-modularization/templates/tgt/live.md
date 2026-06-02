Live target (`FooLive`): the concrete `Default*` / `*Live` implementations of this capability's abstractions.

- Depends on the abstraction target (`Foo`); conforms its types to those protocols.
- Pulled only at the composition root — nothing else depends on `FooLive`.
- Each implementation in its own file, separate from the protocol it conforms to.
- IMPORTANT: this is the ONLY target that imports heavy/third-party dependencies (SwiftProtobuf, CoreData, URLSession glue).

See the swift-modularization skill (live target) for rationale + structure.
