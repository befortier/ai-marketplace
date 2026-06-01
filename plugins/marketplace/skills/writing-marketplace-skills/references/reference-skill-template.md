# Skill template

## Contents
- The skeleton
- Section-by-section guidance

## The skeleton

```markdown
---
name: <skill-name>                # = folder name; lowercase/hyphens; ≤64 chars
description: <what it does>. Use when <triggers/situations — not the step-by-step>.
---

# <Title>

## Overview
One paragraph: what this is and why it matters. Assume the reader is smart — don't
define well-known concepts; state the core idea in a sentence or two.

## Quick Start
The fastest path to value — the minimal working example, or the inputs to gather first.

## <Core content>
The non-negotiable rules, patterns, or steps. Keep "what do I do now" here; push
"how to do it well" into references/. Include short, real examples inline.

## Guidelines
Judgment calls that prevent misuse — when to apply, when not to, trade-offs.

## Common Mistakes
The top 3–5 failure modes, each with the fix. Concrete, not abstract.

## Reference Files
| File | When to read |
|------|-------------|
| references/<topic>.md | When you need <specific detail> |
```

## Section-by-section guidance

- **Overview** — one paragraph; don't restate what the reader already knows.
- **Quick Start** — concrete and immediately actionable.
- **Core content** — the spine; delegate depth to one-level-deep reference files.
- **Examples** — short and real, not pseudocode; long examples go in references/.
- **Guidelines / Common Mistakes** — where a skill earns its keep: the judgment a naive
  read of the underlying docs would miss.
- **Reference Files** — link each directly from SKILL.md; give any file over ~100 lines
  its own table of contents.
