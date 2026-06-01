---
name: swift-modularization
description: Conventions for structuring a Swift app into SwiftPM packages — infrastructure vs domain clusters, Live/non-Live splits for injection, dependency direction, and a thin composition root. Use when organizing modules or deciding where code lives.
---

# Swift Modularization

## Overview

Structure a Swift app as SwiftPM packages organized **by area** — one package per
infrastructure capability or product domain, each exposing several small library
**targets** — with a clear dependency direction and a thin app target that only wires
things together. There are two package kinds — infrastructure and domain — and
everything testable is a protocol.

**Group by area, not by module.** The package is the unit for a capability or domain;
the modules inside it are targets + products. A `Networking` package exposes `Networking`
+ `NetworkingLive`; a `Chat` package exposes `ChatData` + `ChatUI` + `ChatView`. Prefer one
package with several targets over a package per module — far fewer manifests, cleaner
area boundaries, same enforced dependency direction.

## Where to look

Open the reference for what you're doing:

- **An infrastructure capability and its abstraction / `Live` target split** →
  [references/infrastructure-packages.md](references/infrastructure-packages.md)
- **Slicing a product domain into targets (Data / UI / per-experience) within one
  package, and the dependency direction between them** →
  [references/domain-clusters.md](references/domain-clusters.md)
- **Wiring the object graph in the thin app target — the Composer pattern and the
  session-gated key/lock root** → [references/composition-root.md](references/composition-root.md)
- **Authoring a package that exposes multiple targets/products** →
  [references/package-new-package.md](references/package-new-package.md)
- **Maintaining the app target's `Package.swift` dependencies** →
  [references/package-app-dependencies.md](references/package-app-dependencies.md)
