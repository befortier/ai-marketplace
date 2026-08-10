---
name: localized-strings
description: String containers: feature packages take pre-localized copy from the app instead of shipping their own .xcstrings, one small container per surface. Use when a package needs user-facing copy, removing a package catalog, or deciding where a string lives.
---

# String Containers

A **string container** is a `Sendable` struct of already-localized copy that a feature
package receives from the app. Feature packages ship **no** `Localizable.xcstrings`.
The app owns every string, in one catalog, translated once.

A package catalog looks free and costs twice: the same key gets translated in two catalogs
and they drift, and one screen's copy ends up split across several files. Injection also
makes copy an input you can substitute in a test, instead of a bundle lookup you can't.

## Rules

1. **No `.xcstrings` in a feature target.** No `bundle: .module`, no `NSLocalizedString`.
   The exceptions are narrow — see [When a catalog stays](#when-a-catalog-stays).
2. **One container per surface**, named `<Surface>StringContainer`, declared **beside the
   type that renders it** — not in a target-level `Strings/` folder.
3. **An aggregate container is pure composition.** It holds nested containers and nothing
   else. Nothing downstream takes the aggregate.
4. **Take the smallest container that covers the surface.** A mapper that derives one
   button takes that button's container, never the screen's.
5. **Counts and percentages are closures, not format strings.**
6. **Copy reaches views through the view state.** No view takes a `strings:` parameter.
7. **The app fills it**, in `<Container>+Default.swift`, as `static var default`.
8. **`.preview` lives beside its container, behind `#if DEBUG`.**

## Naming and file structure

| Thing | Name |
|---|---|
| Per-surface container | `HeaderStringContainer`, `UneditPillStringContainer` |
| Screen aggregate | `LongToShortsChatStringContainer` |
| App-side filler | `LongToShortsChatStringContainer+Default.swift` |

Each container sits next to the view or mapper it serves. Only screen-level copy with no
single owning surface — section titles, load-failure text, toasts — goes in the target's
`Strings/` folder next to the aggregate.

```
Sources/FeatureChat/
├── Strings/
│   ├── FeatureChatStringContainer.swift        # aggregate: nested containers only
│   ├── FeatureChatToastStringContainer.swift   # screen-level, no owning surface
│   └── ErrorStringContainer.swift
└── Views/
    ├── Header/
    │   ├── HeaderView.swift
    │   ├── HeaderViewState.swift
    │   └── HeaderStringContainer.swift         # beside what renders it
    └── Footer/
        ├── FooterView.swift
        └── FooterStringContainer.swift
```

App side, beside the `+Init` files that wire the feature:

```
FeatureName/Strings/
├── FeatureChatStringContainer+Default.swift
└── UneditStringContainer+Default.swift
```

## Deferring localization to the app

The app's filler uses `String(localized:)` with **no `bundle:` argument**. Xcode extracts
those literals into the app catalog on build, and the existing translation pipeline picks
them up. That extraction is the whole reason this works — the package needs no catalog
because the app target's literals already generate the keys.

```swift
// App target — one extension per surface container.
extension HeaderStringContainer {
    static var `default`: HeaderStringContainer {
        HeaderStringContainer(
            fallbackTitle: String(localized: "Clips"),
            clipCount: { String(localized: "\($0) clips") },
            selectClips: String(localized: "Select clips")
        )
    }
}
```

Backend-authored copy is **not** container copy. A message the server already localized
rides on the view state as data; don't add a container field for it.

## Inject the smallest container

An aggregate exists for the app's convenience, not as a parameter type. Give each mapper
and view state the nested container it needs, so its dependencies read honestly and its
tests construct three strings instead of thirty.

```swift
// Wrong — the button mapper can now reach every string on the screen.
struct DefaultExportButtonViewStateMapper {
    private let strings: FeatureChatStringContainer
}

// Right — five strings, which is exactly what it derives.
struct DefaultExportButtonViewStateMapper {
    private let strings: ExportStringContainer
}
```

The same applies to types that build view states directly: `ErrorViewState(strings:)` takes
an `ErrorStringContainer`, not the screen's.

## Copy reaches views through the view state

**Do not put the container on the view state, and do not pass it into a view.** Resolve the
copy into the view state the mapper already produces, so every view keeps its
`(viewState:, onAction:)` contract.

The container cannot ride on a view state, for a concrete reason: view states are
`Hashable` (diffing, dedup guards), and containers hold closures for the plurals, which
can't be `Equatable`. Putting one on a view state forces you to drop either `Hashable` or
the closures.

```swift
// The mapper holds the container and fills the state.
HeaderViewState(
    title: group.title.nonEmpty ?? strings.fallbackTitle,
    subtitle: strings.clipCount(group.items.count),
    selectClipsTitle: strings.selectClips
)

// The view reads the state. No `strings:` parameter.
Text(viewState.selectClipsTitle)
```

A view with no view state and no mapper — a leaf card the app builds directly — gets one
rather than a `strings:` parameter, with the container folded in at construction:

```swift
public struct UneditingCardViewState: Sendable, Hashable {
    public let title: String
    public let progress: Int?
    public let progressText: String?

    public init(progress: Int?, strings: UneditingCardStringContainer) {
        self.init(
            title: strings.title,
            progress: progress,
            progressText: progress.map(strings.percentComplete)
        )
    }
}
```

When a value maps to copy by case, put that mapping on the container so the producer and
any expected-value builder can't disagree:

```swift
extension UneditPillStringContainer {
    public func title(for kind: UneditPillViewState.Kind) -> String {
        switch kind {
        case .erase: erase
        case .erasing: erasing
        case .seeErased: seeErased
        }
    }
}
```

## Plurals stay in the catalog

Anything interpolated is a **closure**, never a pre-formatted string. `String(localized:)`
in the app resolves plural variations from the catalog, where Xcode can express them; a
format string handed across the boundary cannot.

```swift
public let clipCount: @Sendable (Int) -> String        // ✅ "1 clip" / "5 clips"
public let clipCountFormat: String                      // ❌ "%lld clips" — no variations
```

Consequence for `.preview`: hand-pluralize any key that has variations in the catalog, or
tests will assert the wrong copy.

```swift
clipCount: { $0 == 1 ? "1 clip" : "\($0) clips" },
```

## Debug previews near the type

Each container carries a `.preview` of untranslated English, in the same file, behind
`#if DEBUG`. Tests use it too — they only build in Debug.

```swift
#if DEBUG
extension HeaderStringContainer {
    /// Untranslated English for previews and tests; the app supplies the
    /// localized container.
    public static let preview = HeaderStringContainer(...)
}
#endif
```

**`#Preview` blocks compile in Release.** A `#Preview` that references a `#if DEBUG`
container fails the Release build:

```
error: type 'UneditStringContainer' has no member 'preview'
```

Build preview view states from literals instead, so `.preview` is reached only from tests.
Don't wrap `#Preview` blocks in `#if DEBUG` to work around it.

## Injecting collaborators, not just strings

Once a mapper takes a container, its sub-mappers need one too. Require them — no
`(any Mapper)? = nil` with an internal fallback, which only exists because a default
argument can't read `strings`.

```swift
init(
    strings: FeatureChatStringContainer,
    exportButtonMapper: any ExportButtonViewStateMapper,
    rowMapper: any ShortItemRowViewStateMapper
)
```

When those protocols are internal the app can't pass them, so the package's **public
convenience init is the single place the production graph is wired** — alongside the
use-case defaults already there. Sub-mappers are injected as `any Protocol`, never as a
concrete type, so they can be stubbed.

## When a catalog stays

- **Another process renders the copy.** A widget or notification extension can't read the
  app bundle's catalog. Copy that a target renders in its own process keeps its catalog
  there.
- **The target's entire job is mapping to strings.** Injecting copy into a
  stage-to-string mapper leaves an empty target; leave it alone.

## Migrating a package catalog

Deleting a catalog throws away every translation in it. Follow these steps in order; the
copy is destructive and two of the steps are easy to get wrong.

1. **Copy the package catalog's entries into the app catalog before deleting it**, with
   their existing translations and plural variations. Do not re-extract them as English and
   wait on the translation pipeline — that ships English to every locale in the meantime.
2. **Skip keys the app catalog already has.** Drop them rather than overwriting; the app's
   value is the one already reviewed.
3. **Append the new keys. Never re-sort the app's `.xcstrings`.** Xcode orders that file
   with a locale-aware collation you cannot reproduce, so a byte-order sort rewrites every
   entry in the file. Xcode slots appended keys into place on its next extraction.
4. **Delete the package catalog**, and remove
   `resources: [.process("Localizable.xcstrings")]` from `Package.swift` if that target
   declared it. Some targets rely on SwiftPM auto-detecting the catalog and declare nothing.
5. **Verify no `bundle: .module` or `NSLocalizedString` remains** in the target.

## Smells

- A container field typed `String` holding `"%lld items"` → rule 5; make it a closure.
- A view init with both `viewState:` and `strings:` → rule 6.
- A mapper whose container has fields it never reads → rule 4; take the nested one.
- An aggregate container with loose `String` fields beside its nested containers → rule 3;
  those strings belong to some surface.
- A container declared in a target-level `Strings/` folder while the view that renders it
  lives three folders away → rule 2.
- `.preview` referenced from a `#Preview` block → the Release build is broken.
- A `static let default` in the package → the package is localizing itself; that belongs in
  the app.

## Cross-links

- **`ios-view-architecture`** — the view state and mapper this pattern fills.
- **`ios-composition`** — where `<Container>+Default.swift` sits, next to the `+Init` files.
