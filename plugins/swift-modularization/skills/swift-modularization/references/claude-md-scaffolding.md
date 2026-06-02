# CLAUDE.md scaffolding

How the per-package and per-target `CLAUDE.md` files are structured, why they stay lean,
and how the scaffold scripts generate them.

## The split: skill vs CLAUDE.md

| | Holds | Loads |
|---|---|---|
| **This skill** | the *why* and the judgment — when to split a package, dependency direction, rationale, plus the scripts and templates | on demand, when an agent is reasoning about modularization |
| **CLAUDE.md** | the *what/where* for one folder — the hard rules for editing here — plus a one-line `See the swift-modularization skill (…)` pointer | **every session**, for any folder it sits in or above |

Because a `CLAUDE.md` loads every session, it must be cheap. Domain knowledge, rationale,
and examples belong in the skill; the `CLAUDE.md` carries only the rules that, if missing,
would let an agent make a mistake in that folder.

## Additive, non-redundant tiers

Claude loads **ancestor** `CLAUDE.md` files automatically — for a target that is the
app-project root, then the package, then the target itself. They stack, so each tier must
carry **only its own delta**:

```
ios/CLAUDE.md                              app-project tier  (hand-maintained)
└── <Package>/CLAUDE.md                    package tier      (scripted: domain | infra)
    └── Sources/<Target>/CLAUDE.md         target tier       (scripted: data|ui|view|live|non-live)
```

- The package tier does not restate global rules from `ios/CLAUDE.md`.
- The target tier does not restate the package tier — only what is specific to *this* role.
- No tier duplicates another. If a rule belongs to a broader scope, it lives there and the
  narrower tier stays silent on it.

The **app-project** and **app-target** tiers are hand-maintained: they encode
project-specific wiring (the composition root, build/test commands, app-wide conventions)
that no template can predict. The **package** and **target** tiers are scripted because
their rules are uniform per kind/role.

## The templates

Seven lean templates (in [`templates/`](../../../templates/)), each ~6–18 lines:

| Template | Tier | Key | One hard rule (`IMPORTANT`) |
|---|---|---|---|
| `pkg/domain.md` | package | `domain` | composition lives in `AppComposition`, not the package |
| `pkg/infra.md` | package | `infra` | heavy deps only in `FooLive` |
| `tgt/data.md` | target | `data` | no SwiftUI / view-or-composer logic here |
| `tgt/ui.md` | target | `ui` | presentational only — no Store/Repository/network |
| `tgt/view.md` | target | `view` | no composition/graph wiring; deps are injected |
| `tgt/non-live.md` | target | `non-live` | abstractions only — no heavy deps |
| `tgt/live.md` | target | `live` | the ONLY target importing heavy deps |

Each is bullets + imperative, at most one `IMPORTANT`, and ends with a single
`See the swift-modularization skill (<kind/role>) for …` pointer. The taxonomy in the
target templates (data-layer folders; UI subview-per-folder; protocol/impl separation)
matches the `ios-data-layer` and `ios-view-architecture` skills.

## The scaffold scripts

Two scripts in [`scripts/`](../../../scripts/), sharing `_scaffold-lib.sh`:

- `scaffold-package-claude-md.sh <kind> <package-dir>` → `<package-dir>/CLAUDE.md`
- `scaffold-target-claude-md.sh <role> <package-dir> <target>` → `…/Sources/<target>/CLAUDE.md`

They render the matching template under a `# <Name> (<kind/role>)` heading and write it
into a **managed block** delimited by stable markers:

```
<!-- swift-modularization:managed START role=data -->
…generated content…
<!-- swift-modularization:managed END role=data -->
```

Re-running is **idempotent**: the script replaces only the content between the markers and
leaves any hand-written prose outside them untouched. This lets a folder accumulate
project-specific notes alongside the generated rules without the next run clobbering them.

## Best-practices rationale

These templates follow the CLAUDE.md guidance in
<https://code.claude.com/docs/en/best-practices> ("Write an effective CLAUDE.md"):

- **Keep it short — it loads every session.** Per line, ask *"would removing this cause a
  mistake?"* If not, cut it. A bloated `CLAUDE.md` causes Claude to ignore the real rules.
- **Exclude the inferable.** Anything Claude can read from the code, standard Swift
  conventions, file-by-file descriptions, frequently-changing details, and long
  explanations stay OUT — they go in the skill or nowhere.
- **Additive ancestors.** Nested `CLAUDE.md` files auto-load up the tree, so tiers are
  delta-only and never redundant.
- **Domain knowledge → skills, not CLAUDE.md.** The rationale and judgment live here; the
  `CLAUDE.md` keeps a pointer.
- **`IMPORTANT`/`YOU MUST` sparingly.** One hard rule per template, reserved for the
  constraint most likely to be violated.
