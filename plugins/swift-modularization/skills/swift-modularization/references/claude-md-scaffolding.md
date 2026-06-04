# CLAUDE.md scaffolding

How the scaffold scripts generate per-package / per-target `CLAUDE.md` skeletons.

> The authoritative **content model** for a CLAUDE.md — what each per-type file should say, the
> per-type conventions, and the "keep it lean, loads every session" best-practices — lives in the
> **`ios-package-context`** skill. This reference covers only the *generation tooling* (templates +
> scripts) and the additive-tier model; it does not restate those conventions.

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

- `scaffold-package-claude-md.sh <kind> <package-dir> [--force]` → `<package-dir>/CLAUDE.md`
- `scaffold-target-claude-md.sh <role> <package-dir> <target> [--force]` → `…/Sources/<target>/CLAUDE.md`

They render the matching template under a `# <Name> (<kind/role>)` heading and write it as
the whole file — **no marker comments**, so nothing the script adds bloats the context the
`CLAUDE.md` is loaded into.

The scripts are **create-only**: if the target `CLAUDE.md` already exists they leave it
untouched and skip it (printing `⏭  exists — skipped`), so a re-run never silently
overwrites or appends to a file you have since hand-edited. To deliberately regenerate a
file, pass `--force` — it overwrites that file wholesale (an explicit, reviewable act).
Once a file is written, it is yours: edit it freely and the scaffolder won't touch it again.

## Best-practices rationale

The "keep it lean / exclude the inferable / domain knowledge → skills / `IMPORTANT` sparingly"
rationale (from <https://code.claude.com/docs/en/best-practices>) is owned by the
**`ios-package-context`** skill — see it for the content-model conventions these templates follow.
