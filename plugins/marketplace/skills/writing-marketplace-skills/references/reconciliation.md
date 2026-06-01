# Reconciliation: resolving the conflicting authoring guides

## Contents
- The three sources
- Conflict table (with the authoritative ruling)
- What each ruling supersedes
- Things the local guides got right (keep using them for these)

## The three sources

1. **Anthropic official best practices** — the canonical authority and tie-breaker:
   https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices
2. **`superpowers-bd:writing-skills`** — strong on *process/discipline* skills: TDD-for-skills
   (RED/GREEN/REFACTOR), pressure-testing with subagents, rationalization tables. Uses
   `claude-skills-cli validate --lenient` (warns at 150 lines / 2000 words).
3. **`create-agent-skills`** (this repo's `marketplace` plugin) — Anthropic-spec oriented,
   router pattern, workflows + templates. **Internally contradictory** (see below).

## Conflict table

| Topic | superpowers-bd | create-agent-skills | Anthropic official | **Ruling for this marketplace** |
|-------|---------------|---------------------|--------------------|----------------------------------|
| Body format | markdown | SKILL.md says "no XML, use markdown"; its **workflows** say "pure XML, no markdown headings" (self-contradiction) | markdown examples throughout; frontmatter may not contain XML | **Markdown, no XML.** |
| Body length | ≤150 lines / ≤2000 words (lenient validator) | "under 500 lines" | "under 500 lines for optimal performance" | **Hard ceiling 500 (Anthropic); aim ≤~150–200 for low trigger cost.** `create-view` is ~163 lines and fine. The 150 figure is a house-style nudge, not a gate. |
| `description` | "triggering conditions ONLY; never summarize workflow" | "what it does AND when" | "what it does AND when to use it"; third person; ≤1024 chars; no XML; no "anthropic"/"claude" | **WHAT + WHEN, third person — but never the step-by-step workflow.** Anthropic wins on including the capability; superpowers wins on *excluding workflow steps* (the real failure mode). These are compatible. |
| Naming | mixed (gerund + noun) | mandatory gerund (`processing-pdfs`) | gerund recommended; **noun phrases explicitly acceptable**; avoid inconsistency within a collection | **Match the siblings (noun/area form here).** Consistency beats the gerund preference. |
| Location | skill dir (superpowers plugin) | `~/.claude/skills/...` + a slash command | n/a (platform-agnostic) | **`plugins/<plugin>/skills/<skill>/` + plugin.json; register new *plugins* in marketplace.json.** No `~/.claude/skills`, no slash command needed. |
| Testing | pressure scenarios + meta-testing | "test with real usage" | eval-driven: baseline without skill → minimal content → iterate (Claude A/Claude B) | **Eval-driven real-use test for reference skills; reserve pressure-testing for discipline skills.** |

## What each ruling supersedes

- The XML-mandating workflows inside `create-agent-skills`
  (`create-new-skill.md`, `create-domain-expertise-skill.md`) are **superseded** — do not emit
  XML-structured skill bodies for this marketplace.
- The "mandatory gerund" naming rule in `create-agent-skills` is **downgraded** to a
  preference; sibling-consistency governs.
- The `~/.claude/skills/...` + slash-command target in `create-agent-skills` workflows is
  **superseded** by plugin packaging.
- superpowers' "triggering conditions ONLY" is **refined**: keep the capability (WHAT) in the
  description; the thing to omit is the *workflow*.

## Things the local guides got right (keep using them for these)

- **superpowers-bd:writing-skills** — for genuine **discipline** skills, its TDD-for-skills,
  pressure-testing, and rationalization/bulletproofing references remain the best tool. Use it.
- **create-agent-skills** — its `audit-skill` checklist and the progressive-disclosure /
  one-level-deep-references guidance are sound and align with Anthropic.
- Both correctly stress **concrete examples**, **consistent terminology**, and **no
  time-sensitive info** — all reaffirmed by Anthropic.

> Note: the contradictions above are documented, not yet fixed in `create-agent-skills`
> itself. A follow-up may reconcile or deprecate that skill; until then, **this** skill is the
> entry point for authoring marketplace skills.
