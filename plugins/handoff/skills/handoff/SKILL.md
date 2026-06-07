---
name: handoff
description: Compacts the current conversation into a handoff document so a fresh agent can continue the work. Use when ending a session or transferring work to another agent.
argument-hint: "What will the next session be used for?"
---

# Handoff

Write a handoff document summarising the current conversation so a fresh agent can continue the work. Save to the temporary directory of the user's OS - not the current workspace.

Include a "suggested skills" section in the document, which suggests skills that the agent should invoke.

Do not duplicate content already captured in other artifacts (PRDs, plans, ADRs, issues, commits, diffs). Reference them by path or URL instead.

Redact any sensitive information, such as API keys, passwords, or personally identifiable information.

If the user passed arguments, treat them as a description of what the next session will focus on and tailor the doc accordingly.

---

_Vendored from mattpocock/skills (https://github.com/mattpocock/skills, path skills/productivity/handoff/SKILL.md) — MIT © 2026 Matt Pocock. Instructional body preserved verbatim; frontmatter description adapted to marketplace WHAT+WHEN convention._
