---
name: writing-marketplace-skills
description: How to write an effective agent skill (a SKILL.md) — the description field, progressive disclosure, structure, and concision per official best practices. Use when creating or revising a skill.
---

# Writing Skills

## Overview

A skill is a `SKILL.md`: YAML frontmatter (`name` + `description`) plus a markdown body,
optionally backed by reference files that load on demand. This guide distills the
official skill-authoring best practices from Anthropic's documentation. The goal is a
skill that gets discovered and followed reliably.

Two facts drive every rule: the `description` is always in context, and the SKILL.md
body loads only when the skill triggers — so spend tokens deliberately.

## The rules that matter

- **`description` = what it does AND when to use it.** Third person, concrete triggers.
  Keep it tight (≤~250 chars), no angle brackets, no reserved words. This field alone
  decides whether the skill is selected — don't restate the step-by-step workflow in it.
- **Be concise — assume the model is smart.** Add only what it doesn't already know; cut
  explanations of common concepts. Every paragraph must justify its tokens.
- **Progressive disclosure.** SKILL.md is an overview/table-of-contents pointing to
  detail. Keep the body focused (official guidance: under ~500 lines); push depth into
  reference files.
- **References one level deep** from SKILL.md; give any reference file longer than ~100
  lines a short table of contents, since large files may be read only partially.
- **Markdown body, forward-slash paths**, descriptive file names; no XML tags.
- **Concrete examples over prose** — input/output pairs teach style faster than description.
- **Consistent terminology** — pick one term and reuse it.
- **No time-sensitive information** in the main flow; put superseded guidance in an
  "Old patterns" section instead.
- **Match degrees of freedom to the task** — exact commands for fragile or destructive
  steps, general direction where many paths are valid.
- **Naming:** lowercase letters, numbers, hyphens; ≤64 chars; gerund (`processing-pdfs`)
  or noun (`pdf-processing`) form, applied consistently; no reserved words.

## Structure

```
skill-name/
  SKILL.md       # frontmatter + overview + the key rules + a router to references
  references/    # deep detail, one level deep, loaded on demand
```

Develop evaluation-first: attempt the task without the skill, note where the model
fails, write the minimal content that closes those gaps, then iterate on real usage.

## Reference Files

| File | When to read |
|------|-------------|
| references/reference-skill-template.md | A copy-paste skeleton + section-by-section guidance for a new skill |

## Common Mistakes

- A vague description, or one with "what" but no "when" (or the reverse).
- Over-explaining things the model already knows.
- Deeply nested references — link everything one level deep from SKILL.md.
- Time-sensitive statements in the main body.
- Offering many options instead of one sensible default with an escape hatch.
