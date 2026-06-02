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

## One type per file

A file holds **one primary type**. Name the file after it (`ChatMessage.swift` holds
`ChatMessage`). Small, tightly-coupled companions of that type may share its file — a
private helper, a nested enum, the type's own `extension`s — but a second top-level type
that stands on its own gets its own file. If a file accretes unrelated types, split it.
This keeps types findable by filename and packages reviewable by directory.

## Where to look

Open the reference for what you're doing:

- **An infrastructure capability and its abstraction / `Live` target split** →
  [references/infrastructure-packages.md](references/infrastructure-packages.md)
- **Slicing a product domain into targets (Data / UI / per-experience) within one
  package, and the dependency direction between them** →
  [references/domain-clusters.md](references/domain-clusters.md)
- **Authoring a package that exposes multiple targets/products** →
  [references/package-new-package.md](references/package-new-package.md)
- **Maintaining the app target's `Package.swift` dependencies** →
  [references/package-app-dependencies.md](references/package-app-dependencies.md)
- **Scaffolding the per-package / per-target `CLAUDE.md` files (the content model + scripts)** →
  [references/claude-md-scaffolding.md](references/claude-md-scaffolding.md)

## CLAUDE.md scaffolding

A package and each of its targets carry a thin `CLAUDE.md` so an agent editing that folder
sees the rules for *that tier* without loading the whole skill. The skill holds the *why*
and the judgment; each `CLAUDE.md` holds *what/where* plus a one-line pointer back here.

**Tiers are additive.** Ancestor `CLAUDE.md` files auto-load (the app-project
`ios/CLAUDE.md`, then the package, then the target), so each tier carries **only its own
delta** and defers everything else upward — no tier repeats what an ancestor already says.

| Tier | `CLAUDE.md` location | Authored by |
|---|---|---|
| App project | `ios/CLAUDE.md` | **hand-maintained** |
| App target | `Sources/<AppTarget>/CLAUDE.md` | **hand-maintained** |
| Package | `<Package>/CLAUDE.md` | **scripted** (KIND: `domain` \| `infra`) |
| Target | `<Package>/Sources/<Target>/CLAUDE.md` | **scripted** (ROLE: `data` \| `ui` \| `view` \| `live` \| `non-live`) |

Run the scaffolders to write/patch the scripted tiers from the lean templates in
[templates/](../../templates/). They are **idempotent** — re-running replaces only the
managed block (between stable markers) and preserves any hand-written content around it.

```bash
# Package tier (KIND = domain | infra)
plugins/swift-modularization/scripts/scaffold-package-claude-md.sh <kind> <package-dir>

# Target tier (ROLE = data | ui | view | live | non-live)
plugins/swift-modularization/scripts/scaffold-target-claude-md.sh <role> <package-dir> <target>
```

The app-project and app-target tiers are **not** scripted — they hold project-specific
wiring that stays hand-maintained. See
[references/claude-md-scaffolding.md](references/claude-md-scaffolding.md) for the content
model and the best-practices rationale.

## Composition is a separate skill

This skill stops at the package boundary: each package exposes raw initializers and
abstractions and does **not** wire itself. The app target is a thin composition root that
pulls the `…Live` products and assembles the graph — but the rules for *how* to compose
(stateless composers, session scopes, navigation inference) belong to the dedicated
**`ios-composition`** skill, and the scope-lived state holders they assemble belong to the
**`ios-container`** skill. Defer all composition and container specifics to those skills.
