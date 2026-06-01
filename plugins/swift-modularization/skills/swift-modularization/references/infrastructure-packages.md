# Infrastructure packages

## What counts as infrastructure

A cross-cutting technical capability that is **provider- and domain-agnostic** —
nothing about it is specific to a product feature. Examples: HTTP networking, web
sockets, persistence/Keychain, generated wire models, the execution/bridge engine,
shared `Sendable` utilities.

If a type only makes sense in the context of one product domain, it is **not**
infrastructure — it belongs in that domain's `…Data` package instead.

## The abstraction / `Live` split (optional)

You may split a capability into two packages:

- `Network` — the **protocols** plus pure request/response models. Consumers import
  this and compile against the protocol surface only.
- `NetworkLive` — the **concrete implementation** (e.g. URLSession). Imported only by
  the composition root, which injects it.

Why: domains and other packages never see the implementation, so they can't depend on
it, and tests substitute a mock of the protocol.

Examples in the target shape:

- `Network` → `NetworkLive` (URLSession)
- `Websockets` → `WebsocketsLive`
- `AssistantProto` — generated SwiftProtobuf models (no split; pure data)
- `ProjectFoundation` — Keychain / Core Data stores + `Sendable` utilities
- `Bridge` / execution engine — infrastructure; abstract it so domains implement
  against the abstraction. Whether it needs the protocol/`Live` split is **decided
  when it is built**, not pre-emptively.

## The rule: start combined, shard later

Do **not** create `X` + `XLive` reflexively. Begin with a single package. Split out a
`…Live` package only when a concrete need appears:

- a test needs to substitute the implementation, or
- the composition root needs to inject a different implementation per environment.

Until then, the extra package is overhead. (Reference project: the `Network` package
keeps its protocols and `URLSession`/Bearer composition together under a
`Composition/` folder, splitting only where injection demanded it.)
