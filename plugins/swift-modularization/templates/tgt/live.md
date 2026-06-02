Live target (`FooLive`): the concrete `Default*` / `*Live` implementations of this capability's abstractions. Mirror the non-live target's folder structure; common folders include `Model/`, `Data/`, `Container/`.

- Depends on the abstraction target (`Foo`); conforms its types to those protocols.
- Each implementation in its own file, separate from the protocol it conforms to.
