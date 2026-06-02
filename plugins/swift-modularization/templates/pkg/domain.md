Domain package. Slices into targets: `<Domain>Data` → `<Domain>UI` → `<Domain>View`.

- Each target owns its own `CLAUDE.md`; read the one for the target you're editing.
- Targets depend downward only; never depend on another domain's internals — go through its public product.
- Depend on infra **abstractions** (`Foo`), never `FooLive`.
- IMPORTANT: composition lives in `AppComposition`, not here. Packages expose initializers and defer wiring + navigation upward.

See the swift-modularization skill (domain package) for rationale + structure.
