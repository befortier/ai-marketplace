# Infrastructure packages

## What counts as infrastructure

A cross-cutting technical capability that is provider- and domain-agnostic — nothing
about it is specific to a product feature. Examples: HTTP networking, web sockets,
persistence/Keychain, shared `Sendable` utilities.

If a type only makes sense within one product domain, it is not infrastructure — it
belongs in that domain's `…Data` package.

## The abstraction / `Live` split

Infrastructure that other packages must inject as a dependency is split into two
packages: an **abstraction** package (the protocols plus plain request/response models)
and a **`Live`** package (the concrete implementation). Consumers compile only against
the abstraction; the `Live` implementation is injected at the composition root, so
nothing else can depend on it and tests substitute a mock.

- `Network` (protocols + models) → `NetworkLive` (URLSession)
- `Websockets` (protocols) → `WebsocketsLive`

## When to split (and when not to)

The split is driven by injection need. If other packages must inject this capability as
a dependency, give it the abstraction + `Live` pair. If nothing needs to inject it, it
doesn't need the split — and may not need to be its own package at all. Add the `Live`
pair when a real consumer or test requires injection, not speculatively.
