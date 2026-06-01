---
name: writing-marketplace-skills
description: Conventions for authoring or editing skills in befortier-marketplace. Use when creating or revising a marketplace skill, or when older authoring guidance conflicts on descriptions, body length, markdown vs XML, naming, or where skills live.
---

# Writing Marketplace Skills

## Overview

The single source of truth for authoring skills that ship in **befortier-marketplace**
(`~/Development/ai-marketplace`). It reconciles two older, partly-conflicting local guides —
`superpowers-bd:writing-skills` (process/discipline skills) and this repo's own
`create-agent-skills` — against **Anthropic's official best practices**, which is the
tie-breaker when they disagree. See [references/reconciliation.md](references/reconciliation.md)
for the evidence and the authoritative ruling behind each rule below.

Authority order: **Anthropic official docs > this skill > the two local guides.**

## Pick the genre first

| Genre | What it is | How to author it |
|-------|-----------|------------------|
| **Discipline / Process** | Behavioral rules that must resist rationalization (TDD, verification-before-completion) | Borrow `superpowers-bd:writing-skills` for its TDD-for-skills, pressure-testing, and rationalization tables — those tools fit this genre. Then apply the **Non-negotiables** below for packaging. |
| **Reference / Convention / Technique** | Knowledge + a structured procedure (how a framework/API/pattern works, a scaffolding recipe). **All befortier iOS/Swift skills are this genre** — `network-layer`, `create-view`, `swift-modularization`, `swift-testing`, `swift-mocking`. | Follow **this** skill: the Non-negotiables + the reference-skill structure below. Pressure-testing and rationalization tables do **not** apply. |

When unsure, it's almost always Reference/Convention. Don't force discipline-skill ceremony onto a knowledge skill.

## Non-negotiables (rulings; Anthropic is the tie-breaker)

1. **Markdown body, never XML tags.** Use `##` headings. Every shipping skill here
   (`create-view`, `network-layer`) and Anthropic's own examples are plain markdown;
   frontmatter may not contain XML at all. (`create-agent-skills` contradicts itself on
   this — ignore its XML-mandating workflows.)
2. **`description` = WHAT + WHEN, third person — but never the step-by-step workflow.**
   Include the capability *and* the triggers/situations that should invoke it (Anthropic),
   written third person ("Scaffolds… Use when…"). **Keep it ≤250 chars** (Claude/the
   validator truncate past that; 1024 is only the hard frontmatter max), no angle brackets,
   no words "anthropic"/"claude". **Do not enumerate the workflow** in the description —
   that makes Claude follow the summary and skip the body (the superpowers trap). Model it on
   `create-view`'s description.
3. **Body concise; hard ceiling 500 lines (Anthropic).** Aim ≤~150–200 so trigger-time
   token cost stays low; move depth into `references/`. Optional check:
   `npx claude-skills-cli validate <skill-dir> --lenient` (it *warns* at 150 lines / 2000
   words — a house-style nudge, not the Anthropic gate).
4. **Naming: consistency within the collection wins.** Gerund is Anthropic's recommendation,
   but noun phrases are an explicit acceptable alternative — and the siblings here are noun/
   area form (`network-layer`, `create-view`, `swift-modularization`). Match them. `name`
   must equal the folder, be lowercase/numbers/hyphens, ≤64 chars, and avoid "anthropic"/"claude".
5. **Packaging = plugin, not `~/.claude/skills`.** A skill lives at
   `plugins/<plugin>/skills/<skill-name>/SKILL.md` with the plugin's
   `.claude-plugin/plugin.json`. A *new plugin* must be registered in
   `/.claude-plugin/marketplace.json`; adding a skill to an *existing* plugin needs **no**
   marketplace.json change. No slash-command file is required.
6. **3-tier progressive disclosure.** Frontmatter (always loaded) → SKILL.md body (on
   trigger) → `references/` (on demand). Keep references **one level deep** from SKILL.md,
   and give any reference file >100 lines a short table of contents.

## Reference-skill structure (copy this shape)

The proven exemplar is `ios-view-architecture`'s `create-view`. Skeleton:

```markdown
---
name: <skill-name>
description: <what it does>. Use when <triggers — not the workflow>.
---

# <Title>

## Overview            ← one paragraph: what + why it matters
## Quick Start         ← inputs to gather / fastest path to value
## <Core convention>   ← the architecture/rules; numbered Steps, each pointing to
                         references/<topic>.md, with a short "Key rules:" list inline
## Guidelines          ← "scan the project first", "don't over-generate", trade-offs
## Common Mistakes     ← top 3–5 failure modes + the fix
## Reference Files     ← table: file | when to read
```

Short, load-bearing code examples belong in the body; long patterns and API detail go
in `references/`. Full annotated template:
[references/reference-skill-template.md](references/reference-skill-template.md).

## Content rules (from Anthropic, apply to every skill)

- **Be concise — Claude is already smart.** Only add context Claude lacks; cut
  explanations of well-known concepts.
- **Concrete examples over abstract prose.** Input/output pairs teach style fastest.
- **Consistent terminology** — pick one term and reuse it.
- **No time-sensitive info** in the main flow; put superseded guidance in an "Old patterns"
  section instead.
- **Match degrees of freedom to the task** — exact commands for fragile/destructive steps,
  general direction where many paths work.
- **Forward-slash paths**; fully-qualify MCP tools as `Server:tool`; don't assume packages
  are installed.

## Authoring steps

1. **Genre** — Discipline or Reference? Route per the table.
2. **Locate/scaffold** — new plugin (`plugins/<name>/.claude-plugin/plugin.json` + register
   in `marketplace.json`) or a new skill folder inside an existing plugin.
3. **Frontmatter** — `name` (matches folder + siblings) + `description` (WHAT + WHEN, no
   workflow).
4. **Draft SKILL.md** — follow the structure; keep it tight (≤~150–200 lines).
5. **Push depth to `references/`** — anything that bloats the body; one level deep.
6. **Validate** — optionally `npx claude-skills-cli validate <skill-dir> --lenient`.
7. **Eval-driven test (real use).** Baseline the task *without* the skill, note the gap,
   then confirm the skill closes it on a real task. This is the test for reference skills —
   not pressure scenarios.

## Common Mistakes

- **XML tags in the body.** This marketplace ships markdown. (The worst contradiction in the
  old local guide.)
- **A description that lists the workflow steps.** Claude then skips the body. Give WHAT +
  WHEN only.
- **Writing to `~/.claude/skills/` or adding a slash command.** Skills here are plugins.
- **Inconsistent naming.** Match the siblings, don't gerund-rename to satisfy an old rule.
- **Over-explaining.** If Claude already knows it, cut it.

## Reference Files

| File | When to read |
|------|-------------|
| [references/reconciliation.md](references/reconciliation.md) | The conflicts between the local guides + Anthropic's ruling and rationale for each |
| [references/reference-skill-template.md](references/reference-skill-template.md) | Full annotated skeleton for a reference/convention skill, modeled on `create-view` |
