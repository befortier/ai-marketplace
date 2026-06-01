---
name: swift-modularization
description: Conventions for structuring a Swift app into SwiftPM packages — infrastructure vs domain clusters, Live/non-Live splits for injection, dependency direction, and a thin composition root. Use when organizing modules or deciding where code lives.
---

# Swift Modularization

## Overview

Structure a Swift app as small SwiftPM packages with a clear dependency direction and a
thin app target that only wires things together. There are exactly two package kinds —
infrastructure and domain — and everything testable is a protocol.

## Where to look

Open the reference for what you're doing:

- **Is this capability infrastructure, and does it need a `Live`/non-`Live` split for
  injection?** → [references/infrastructure-packages.md](references/infrastructure-packages.md)
- **Slicing a product domain into packages (Data / UI / per-experience) and the
  dependency direction between them** → [references/domain-clusters.md](references/domain-clusters.md)
- **Wiring the object graph in the thin app target (the Composer pattern)** →
  [references/composition-root.md](references/composition-root.md)
- **Authoring a new package's `Package.swift`** →
  [references/package-new-package.md](references/package-new-package.md)
- **Maintaining the app target's `Package.swift` dependencies** →
  [references/package-app-dependencies.md](references/package-app-dependencies.md)
