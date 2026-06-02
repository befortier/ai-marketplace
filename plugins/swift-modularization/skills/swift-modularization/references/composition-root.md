# Composition root → see the `ios-composition` skill

Composition — wiring the dependency graph and inferring the navigation tree in the
main app (or a dedicated `AppComposition` package) — now has its own dedicated skill:
**`ios-composition`**. It is the authoritative reference and is no longer duplicated here.

That skill covers:

- Why packages do **not** compose — they expose raw initializers and abstractions.
- How the app / `AppComposition` takes in **feature containers + app scopes + local state**
  and returns **composed dependencies + a navigation tree**.
- Why composition is the **only** place it is okay to infer the navigation graph (packages
  defer navigation to the app).
- Why composition is wiring + navigation **only** — no business logic, no analytics, no
  network calls.
- A worked Swift example grounded in this repo's `AppComposition` package
  (`Bootstrap`, `AuthenticatedComposition`, `BootstrapView`, `RootView`).

For the stateless `Composer` enum factory pattern and the signed-in / signed-out scopes
and containers that feed composition, see
[scopes-and-containers.md](scopes-and-containers.md).
