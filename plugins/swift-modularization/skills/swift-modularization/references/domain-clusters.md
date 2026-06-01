# Domain clusters

A domain is a cluster of small packages, never one fat package. Slice it by concern.

## The three slices

### `<Domain>Data`
The domain's shared core: domain models, network services (built on the `Network`
abstraction), and data stores.

### `<Domain>UI`
Small, reusable SwiftUI components for the domain. Depends on `<Domain>Data` for the
value types it renders.

### `<Domain><Experience>` — one package per screen
Each screen/experience is its own package (its View, ViewModel, ViewState, mapper). A
new experience is a new package, not a fatter existing one.

## Dependency direction

```
<Domain><Experience>  →  <Domain>UI  →  <Domain>Data  →  infra ABSTRACTIONS
                                                          (never …Live)
```

- An experience depends on its domain's UI and Data, plus infrastructure abstractions —
  never on `…Live`.
- Domains do not reach into other domains' internals. If two domains need the same
  thing, go through the other domain's public surface, or lift the shared piece into an
  infrastructure package.
