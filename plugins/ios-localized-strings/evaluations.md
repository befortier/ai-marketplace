# Evaluations — ios-localized-strings

Development material, not runtime content: this file is deliberately **not** linked from
`SKILL.md`, so it never enters an agent's context during normal use.

Each evaluation records the baseline — what an agent actually did on this task *without* the
skill — and the behavior the skill is supposed to produce. Baselines below were observed
while writing [smart-video#10428](https://github.com/bungeeapp/smart-video/pull/10428),
where the first attempt was made with no skill and drew 19 review comments.

**Status: authored, not yet run.** There is no built-in runner for this format; scoring is
manual or via your own harness. Nothing here has been executed against Haiku, Sonnet, or
Opus.

## 1. Adding copy to a package view

Tests rules 2, 4, 6 — container placement, smallest injection, copy through the view state.

```json
{
  "skills": ["localized-strings"],
  "query": "The FeatureChat package target needs a 'Show all' button on its rows section, and a 'N clips' subtitle in its header. Add the copy.",
  "expected_behavior": [
    "Creates no Localizable.xcstrings in the package and uses no bundle: .module",
    "Declares ShortItemRowGroupStringContainer beside ShortItemRowGroupView, and HeaderStringContainer beside HeaderView, rather than one container in a target-level Strings/ folder",
    "Adds a showAllTitle field to ShortItemRowGroupViewState and has the mapper fill it, instead of passing a strings: parameter into the view",
    "Types the clip count as a closure (Int) -> String, not a format string",
    "Adds the literals to the app target in a <Container>+Default.swift using String(localized:) with no bundle: argument"
  ]
}
```

**Baseline without the skill:** produced one flat aggregate container for the whole screen
in a target-level `Strings/` folder, and passed it into leaf views as a `strings:`
parameter. Reviewer comments: *"we should do a better job defining the StringContainer
closer to the use case"*, *"Does this need the whole string container?"*, *"In some of our
components the string container is on the view state in others its not."*

## 2. The plural trap

Tests rule 5 in isolation — the failure is silent, so it needs its own evaluation.

```json
{
  "skills": ["localized-strings"],
  "query": "Add a '%lld Selected' label to the multiselect header of the FeatureChat package. The app catalog has plural variations for this key.",
  "expected_behavior": [
    "Types the field as @Sendable (Int) -> String rather than String",
    "Fills it in the app with { String(localized: \"\\($0) Selected\") } so the catalog resolves the variation",
    "Does not reimplement pluralization in the package",
    "Hand-pluralizes the .preview value so tests assert the same copy the catalog produces"
  ]
}
```

**Baseline without the skill:** the container field was a closure, but `.preview` was
`{ "\($0) clips" }` with no plural handling, so a mapper test asserting `"1 clip"` failed
with `"1 clips"`. The trap is that the production path is right and only the preview path
is wrong, so it surfaces as a confusing test failure rather than a design error.

## 3. The `#if DEBUG` / Release trap

Tests rule 8 plus the non-obvious build consequence.

```json
{
  "skills": ["localized-strings"],
  "query": "Put the .preview containers in the FeatureChat package behind #if DEBUG so they can't ship.",
  "expected_behavior": [
    "Gates each .preview extension behind #if DEBUG in the same file as its container",
    "Recognizes that #Preview blocks compile in Release, so a #Preview referencing .preview breaks the Release build",
    "Resolves it by building preview view states from literals, NOT by wrapping #Preview blocks in #if DEBUG",
    "Notes that tests may keep using .preview because they only build in Debug"
  ]
}
```

**Baseline without the skill:** shipped `.preview` ungated, reasoning that `#if DEBUG`
would break previews — correct diagnosis, wrong conclusion, and the gate was skipped
entirely. Verified empirically that the Release build fails with
`type 'UneditStringContainer' has no member 'preview'`.

## 4. Migrating an existing package catalog

Tests the destructive path. Low freedom by design — the two traps here lose work silently.

```json
{
  "skills": ["localized-strings"],
  "query": "Delete Localizable.xcstrings from the FeatureChat package target and move its copy to the app. The package catalog has 28 keys translated into 33 locales.",
  "expected_behavior": [
    "Copies the existing translations and plural variations into the app catalog rather than re-extracting the keys as English",
    "Skips keys the app catalog already has instead of overwriting them",
    "Appends new keys without re-sorting the app catalog, and can explain that Xcode's ordering is a locale-aware collation a byte sort would rewrite wholesale",
    "Removes resources: [.process(\"Localizable.xcstrings\")] from Package.swift if that target declared it",
    "Confirms no bundle: .module or NSLocalizedString remains in the target"
  ]
}
```

**Baseline without the skill:** re-sorted the app catalog while inserting keys, producing a
113,000-line diff that rewrote all 2,967 existing entries. Caught only because the diffstat
looked absurd.
