# App target CLAUDE.md

The app / executable target (e.g. `iDuc/`): the `@main` entry point, asset catalog,
`Info.plist`, entitlements, and app-level wiring. Thin — it hands almost everything to the
composition-root package.

There is also the **top-level `ios/CLAUDE.md`** above all packages: it owns the
project-wide conventions and the build/test/lint commands. The app-target file does NOT
repeat those — it links up to the top-level file.

## What it contains

- **Blurb** — "the app executable: `@main` entry, asset catalog, Info.plist, entitlements;
  delegates the object graph to <CompositionRoot>."
- **File structure** — `App.swift` / `*App.swift`, `Assets.xcassets`, `Info.plist`,
  entitlements, any launch config.
- **Naming** — the `@main` type, scene/window setup.
- **Gotchas** — what app-level concerns live here (signing, capabilities, launch screen)
  vs. what is delegated to the composition root; the link to `ios/CLAUDE.md` for build
  commands.
- **Cross-link** to the composition-root package's `CLAUDE.md` and `ios-composition`.

## Skeleton

```markdown
# iDuc app target

The app executable: `@main` entry, asset catalog, `Info.plist`, entitlements. Delegates
the object graph to the AppComposition package.

Read [`ios/CLAUDE.md`](../CLAUDE.md) for project-wide conventions and build/test commands.

## File structure

- `iDucApp.swift` — `@main`; builds the composition root's bootstrap and shows RootView.
- `Assets.xcassets`, `Info.plist`, `iDuc.entitlements`.

## Rules

- Only app-level concerns live here (signing, capabilities, launch). Everything else is
  in AppComposition.
- Build/test commands live in `ios/CLAUDE.md`, not here.

See the AppComposition CLAUDE.md and the ios-composition skill.
```

## Gotchas worth surfacing

- The split between app-level config (signing, entitlements, asset catalog) and the graph
  (which lives in the composition-root package).
- Where the full-app build command lives (top-level `ios/CLAUDE.md`), so an agent does not
  re-document it here.
- Any required runtime/simulator note only if it is app-target-specific and not covered
  upstream.

## Anti-pattern

Re-documenting build/test/lint or the dependency graph. Those live once, in
`ios/CLAUDE.md` and the composition-root file respectively. The app-target file lists its
own handful of files and links upward.
