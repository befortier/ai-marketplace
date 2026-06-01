# Annotated template: a reference/convention skill

## Contents
- When to use this template
- The skeleton (annotated)
- Section-by-section guidance
- Worked exemplar: `create-view`

## When to use this template

For a **Reference / Convention / Technique** skill — one that teaches how a framework, API,
or pattern works, or scaffolds something to a house convention. This is the genre of every
befortier iOS/Swift skill. (For a discipline skill, use `superpowers-bd:writing-skills`
instead.)

## The skeleton (annotated)

```markdown
---
name: <skill-name>                # = folder name; lowercase/hyphens; ≤64 chars
description: <what it does>. Use when <triggers/situations — NOT the steps>.
---

# <Title>

## Overview
One paragraph: what this is and why it matters. Assume Claude is smart — don't define
well-known concepts. State the core principle in 1–2 sentences.

## Quick Start
The fastest path to value. For a scaffolding skill, list the inputs to gather first
(feature name, data source, sections, navigation exits). For an API skill, the minimal
working snippet.

## <Core convention / Architecture>
The non-negotiable rules and structure. Prefer numbered Steps. Each Step:
  - one short paragraph of intent,
  - a "Key rules:" bullet list (3–6 bullets) inline,
  - a pointer "Read references/<topic>.md for the full pattern."
Include short, load-bearing code examples inline. Push long patterns to references/.

## Guidelines
Judgment calls that prevent over/under-application:
  - "Scan the project first" — match existing naming/structure before generating.
  - "Don't over-generate" — skip layers a simple case doesn't need.
  - Trade-offs and degrees of freedom.

## Common Mistakes
Top 3–5 failure modes, each with the fix. Concrete, not abstract.

## Reference Files
| File | When to read |
|------|-------------|
| references/<topic>.md | When you need <specific detail> |
```

## Section-by-section guidance

- **Overview** — resist restating what Claude knows. One paragraph max.
- **Quick Start** — concrete and immediately actionable; gather-inputs list or minimal snippet.
- **Core convention** — this is the spine. Numbered steps, each delegating depth to a
  one-level-deep reference file. Keep "what do I do now" here; "how do I do it well" in
  references.
- **Code examples** — short and real (compilable), not pseudocode. Long examples → references.
- **Guidelines / Common Mistakes** — these are where reference skills earn their keep; they
  encode the judgment that a naive read of the framework docs misses.
- **Reference Files** — every file linked directly from SKILL.md (one level deep). Give any
  reference file >100 lines its own table of contents.

## Worked exemplar: `create-view`

`plugins/ios-view-architecture/skills/create-view/SKILL.md` is the canonical reference-skill
in this marketplace. Study it for:
- a description that states WHAT then "Use when…" (no workflow enumeration),
- Quick Start = inputs to gather,
- numbered Steps each pointing to `references/<topic>.md` with inline "Key rules",
- short inline Swift snippets for the load-bearing structures,
- a Guidelines section with "scan the project first" and "don't over-generate".

Copy its shape; swap in your domain's convention.
