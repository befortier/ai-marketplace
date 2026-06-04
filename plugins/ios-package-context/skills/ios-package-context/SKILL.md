---
name: ios-package-context
description: Authoring per-package and per-target CLAUDE.md files for a modularized iOS app — blurb plus file structure, naming, and non-obvious gotchas only, never implementation detail or intention. Use when writing or slimming a package or target CLAUDE.md.
---

# iOS Package Context

## Overview

In a package-per-area iOS app, every package and every target carries a `CLAUDE.md`. Its
job is **orientation, not documentation**: tell an agent where things live, what to name
them, and the one or two things that would trip them up — then get out of the way. The
authoritative description of behaviour is the code; the authoritative description of
*patterns* is the matching skill (`swift-modularization`, `ios-view-architecture`,
`ios-data-layer`, …). A `CLAUDE.md` links to those and stays thin.

## The one rule

A `CLAUDE.md` contains only four things:

1. **Blurb** — 1–2 sentences: what this package/target is and its role in the graph.
2. **File structure** — the folders/files an agent will navigate, by name.
3. **Naming patterns** — the conventions for new files/types here.
4. **Non-obvious gotchas** — the few things that are surprising, easy to get wrong, or
   must-not-regress. Mark the load-bearing ones `IMPORTANT:`.

Then a closing **cross-link** line: `See the <skill> skill for rationale + structure.`

**Never** put in a `CLAUDE.md`:

- **Implementation detail** — how a function works, control-flow walk-throughs, ASCII
  data-flow diagrams of a contract. This drifts the moment the code changes; the code is
  the source of truth. Document the *contract's existence and name*, not its mechanics.
- **Intention / rationale / history** — "we did this because…", "lifted from resy",
  "the E3.T1 addition is…". Why-we-built-it lives in the PR/commit and the skill, not in
  a file agents read as current truth.
- **Build/test/lint commands** — those live once, in the top-level `ios/CLAUDE.md`.
- **Anything the matching skill already says** — link to it instead of restating it.

If you are explaining *behaviour*, you are writing the wrong document. Stop and link a
skill, or trust the code.

## Two altitudes

- **Package-level `CLAUDE.md`** (`Packages/Foo/CLAUDE.md`): names the package kind
  (infra vs domain), lists its targets and their dependency direction, and points each
  target's editor at its own `CLAUDE.md`. Short — the targets carry the detail.
- **Target-level `CLAUDE.md`** (`Packages/Foo/Sources/FooBar/CLAUDE.md`): the working
  document for someone editing that target. Pick the reference below that matches the
  target type.

## Quick Start

1. Identify the target type (abstraction, Live, Data, UI, View, composition root, app).
2. Open the matching reference file below — each has a copy-paste skeleton.
3. Fill blurb → structure → naming → gotchas. Resist adding a fifth thing.
4. End with the cross-link line to the governing skill.
5. Keep a target file roughly under a screen; a package file shorter still.

## Reference Files

One reference per package/target **type**. Each gives the skeleton, a good example, and
the type-specific gotchas worth surfacing.

| File | When to read |
|------|-------------|
| references/package-level.md | Authoring a package-level `CLAUDE.md` (the folder above the targets) |
| references/infra-abstraction-target.md | An infra abstraction target (`Foo`) — protocols + plain models |
| references/infra-live-target.md | An infra implementation target (`FooLive`) — the concrete impl |
| references/domain-data-target.md | A `<Domain>Data` target — models, mappers, stores, services |
| references/domain-ui-target.md | A `<Domain>UI` target — reusable presentational components |
| references/domain-view-target.md | A `<Domain><Experience>` / View target — a feature screen |
| references/composition-root.md | The composition-root package (wires the `…Live` graph) |
| references/app-target.md | The app/executable target (entry point, asset catalog, Info.plist) |

## Common Mistakes

- **Narrating the code.** A paragraph that re-describes what a function does is a future
  lie — delete it; the code already says it.
- **Embedding rationale.** "We chose X because Y" belongs in the commit and the skill,
  not in the always-read context file.
- **Duplicating the skill.** If the pattern is generic, link the skill in one line rather
  than restating it per package.
- **Growing without end.** A `CLAUDE.md` over a screenful is a smell — it has started
  documenting behaviour. Cut back to blurb + structure + naming + gotchas.
- **Skipping the cross-link.** Without the `See the <skill> skill` line, the agent can't
  find the authoritative pattern.
