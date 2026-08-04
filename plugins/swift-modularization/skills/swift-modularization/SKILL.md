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

## Compatibility is sacred

- **Never raise a package's platform floors.** A convenient API is not a reason to bump
  `platforms:` — the app's minimum OS is the contract.
- **Never introduce APIs above the app's minimum OS.** `ImageResource` is iOS 17+; on an
  iOS 16 floor use `Image(_:bundle:)` instead.
- If the dependency graph seems to force a bump, it doesn't: scope the dependency with
  `.when(platforms:)` target conditions, or rewrite the API usage.

## Package hygiene

- **Wire payloads stay `package`-access.** Raw `Data` blobs passed between targets are
  `package`, never `public` — no other package should decode them.
- **Register string catalogs with the i18n pipeline.** A package that ships its own
  `.xcstrings` catalog must be added to the repo's localization config, or its strings
  silently never get translated.

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
- **What goes in a per-package / per-target `CLAUDE.md` — the content model, per-type
  conventions, and best-practices** → the **`ios-package-context`** skill (authoritative).
- **Generating the `CLAUDE.md` skeletons (scaffold scripts + templates + the additive-tier
  model)** → [references/claude-md-scaffolding.md](references/claude-md-scaffolding.md)

## Composition is a separate skill

This skill stops at the package boundary: each package exposes raw initializers and
abstractions and does **not** wire itself. The app target is a thin composition root that
pulls the `…Live` products and assembles the graph — but the rules for *how* to compose
(stateless composers, session scopes, navigation inference) belong to the dedicated
**`ios-composition`** skill, and the scope-lived state holders they assemble belong to the
**`ios-container`** skill. Defer all composition and container specifics to those skills.
