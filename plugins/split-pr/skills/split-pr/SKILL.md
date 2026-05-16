---
description: Splits a large changeset or PR into smaller, focused PRs — analyzes changes, detects dependencies, and creates JIRA subtasks, branches, and parallel or chained PRs as appropriate.
---

# Split PR

Split changes into smaller, focused PRs. Works at any stage of development: unstaged changes, staged changes, committed but unpushed commits, or an existing PR. Claude analyzes symbol-level dependencies between changed files to create parallel PRs wherever possible, and chains only when one split genuinely depends on another.

## When to Use

Apply when the user wants to break up a large changeset, proactively when a diff exceeds ~400 LOC, or when PR review friction is the concern.

## Step 1: Detect Repo and Input State

Resolve the absolute path to this skill's `scripts/` directory. You just read this file from disk — use the directory that contains it as `{SKILL_DIR}`. All script invocations below use `{SKILL_DIR}/scripts/` as the prefix.

### Prerequisites check

```bash
gh auth status 2>/dev/null
```

If the exit code is non-zero, stop immediately:

> "GitHub CLI is not authenticated — it's required to create PRs. Run `gh auth login` and then re-run this skill."

### Detect state

```bash
python3 {SKILL_DIR}/scripts/detect-state.py > /tmp/split-pr-state.json
```

Read `/tmp/split-pr-state.json`. If `error` is set, report it and stop.

Use `org` and `repo` from the output for all subsequent `gh` commands.

If `state == "clean"` and the user did not provide a PR number or URL, stop:
> "Nothing to split — no uncommitted changes and no commits ahead of the remote."

If `needs_base_confirmation` is true, ask:
> "This branch has no upstream tracking branch. I'll compare against `{base_ref}` — is that the right base?"
Wait for confirmation. If the user provides a different base, use it as `base_ref` going forward.

If `untracked_files` is non-empty, warn:
> "These files are untracked and won't be included in the split. Stage them with `git add -N <file>` first if you want them captured: {untracked_files}"

If the user provided a PR number or URL, fetch PR metadata and override state:
```bash
gh pr view {NUMBER} --repo {ORG}/{REPO} --json number,title,body,baseRefName,headRefName,state
```
Check `state`: stop if `MERGED`; ask before continuing if `CLOSED`. Set `base_ref = origin/{baseRefName}`.

## Step 2: Get the Diff

```bash
# Use diff_command from detect-state.py output for local state:
{diff_command from /tmp/split-pr-state.json}

# Existing PR only:
gh pr diff {NUMBER} --repo {ORG}/{REPO} > /tmp/split-pr-diff.patch
```

If `state` is `uncommitted` or `mixed` and `untracked_files` is non-empty, remind the user those files are excluded.

```bash
python3 {SKILL_DIR}/scripts/parse-diff.py /tmp/split-pr-diff.patch \
  > /tmp/split-pr-parsed.json 2>/tmp/split-pr-parse-warnings.txt
```

If `/tmp/split-pr-parse-warnings.txt` is non-empty, surface the contents to the user before continuing:

> "Some files in the diff could not be parsed and will be excluded from the split:
> {warnings}"

Ask whether to continue without those files or abort.

Read `/tmp/split-pr-parsed.json`. Check `total_additions + total_deletions`:
- **0** — stop: there is nothing to split. Tell the user: "The diff is empty — no changes detected between the selected ref and the working state."
- **Under 100** — flag that splitting may not be necessary, but proceed if the user wants to.
- **100 or more** — proceed.

## Step 3: Analyze and Propose Splits

Read the parsed diff. For each changed file, read the actual file in the working tree to understand what it does.

**Project-specific dependency rules:** check for `.claude/skills/split-pr-context.md` in the repo root. If it exists, read it now and treat its contents as additional grouping and dependency rules that take precedence over the generic guidance below. This is where teams document patterns specific to their language, framework, or codebase.

**Non-textual files:** files in the parsed diff where `hunks` is empty fall into three categories:
- **Rename-only** (`change_type == "renamed"`, `hunks: []`, **no `Binary files` line in the diff for this path**): no content change, just a path change. The apply script handles these automatically — include them in `file_hunks` as `"all"` and no manual action is needed.
- **Binary files** (`binary: true` in the parsed diff): either side can be `/dev/null` for newly added or deleted binary files. A renamed binary whose content also changed (`change_type == "renamed"` and `binary: true`) falls into this category — do not treat it as rename-only. Note these and handle them after the proposal is confirmed (see end of this step).
- **Mode-only changes** (`hunks: []`, no binary marker, `change_type != "renamed"`): e.g. a `chmod`. These cannot be represented as hunks either. Warn the user that mode changes will be dropped from all split branches and must be re-applied manually.

**Grouping strategy — default to fine-grained, let the user collapse:**
Split as finely as the dependency structure allows. Each distinct logical concern — a new type, a UI component, a protocol change, a set of conformances, tests — is a candidate for its own split. Err toward more splits rather than fewer. The user can always merge two groups into one; they cannot easily separate a group that was lumped together. The only floor is coherence: a split should be reviewable on its own, not a handful of lines with no standalone meaning. When sizing splits, use the formula defined in `.claude/skills/split-pr-context.md` if one is present — repos often weight deletions differently from insertions and exclude generated or non-source files. Fall back to raw `additions + deletions` if no formula is defined.

**Dependency analysis** — for each proposed pair of groups, check whether group B uses any symbols that group A's changes introduce or modify:
- New types, protocols, enums, typealiases
- Modified method signatures or added methods
- New constants, configuration values, or protocol conformances

**Broken-contract rule (common miss):** if group A modifies or adds a **required** method to an interface, protocol, or abstract class, scan all other changed files for types that implement or conform to that interface. Any such file must be in group A or an earlier group — a type that already implements the interface will fail to compile if it's missing the new required method, even if it doesn't call any of the new symbols. This applies across all languages: Swift protocols, Kotlin/Java interfaces, Python ABCs, TypeScript interfaces, Go interfaces.

If group B uses symbols from group A → B depends on A → chain (B's PR targets A's branch).
If no cross-group symbol dependencies exist → parallel (both PRs target the same base branch).

**Prefer parallel over chained.** Only chain when the dependency is real and required for compilation.

**Size sanity check:** after forming groups, flag any split that still exceeds 200 SLOC and look for further internal dependencies to sub-divide it. A split over 200 SLOC is a signal that the grouping is still too coarse, not a hard limit.

For within-file splits (hunks in the same file that belong in different groups): assign hunks by the feature/concern they're modifying, using the hunk `id` field from the parsed JSON to reference them. When showing `+additions -deletions` in the proposal for a group, count only the lines in the hunks assigned to that group — not the full file totals.

**For each proposed split, draft the branch name, commit message / PR title, and body.** The title becomes both the git commit message subject and the PR title — they must match. If a JIRA key is already known (found in the branch or commits), use it now. Otherwise use `JIRA-KEY` as a placeholder — it will be replaced in Step 4.

Branch naming convention: `{type}/JIRA-KEY/{description-of-change}`
- `feature` — new functionality
- `bugfix` — fixing broken behavior
- `refactor` — restructuring existing code without changing behavior

Use kebab-case for the description portion (e.g., `feature/PAE-123/add-user-profile-model`). If JIRA is skipped in Step 4 (Option 3), omit the key segment: `{type}/{description-of-change}`.

Title formatting rules:
- Format: `[JIRA-KEY] Description` (omit the `[JIRA-KEY] ` prefix if JIRA is skipped)
- Sentence case, not title case (`Add new API client`, not `Add New API Client`)
- Imperative mood (`Refactor networking layer`, not `Refactors` or `Refactored`)
- No trailing period or unnecessary punctuation
- 50 characters or less ideally, 72 max — this applies to the full title including the `[JIRA-KEY] ` prefix. If subtask keys are assigned in Step 4 (Option 2), recalculate using the exact prefix length (`len("[") + len(JIRA_KEY) + len("] ")`) and trim descriptions that would push the title past 72 characters

Body formatting rules (omit entirely if nothing meaningful to add):
- Separated from the title with a blank line
- Describes what this split contains and why the changes are needed
- Line length 72 characters or less
- Proper punctuation and capitalization
- No whitespace errors or typos

**Present the proposal:**

```
Proposed split — N PRs:

[1] Description
    Body: {draft body or "none"}
    Files:
      - path/to/File.swift
      - path/to/Other.swift
      (+{additions} -{deletions})
    Branches from: {base} (parallel)

[2] Description
    Body: {draft body or "none"}
    Files:
      - path/to/File.swift
      (+{additions} -{deletions})
    Branches from: {base} (parallel with [1])

[3] Description
    Body: {draft body or "none"}
    Files:
      - path/to/File.swift
      (+{additions} -{deletions})
    Branches from: split [1] (depends on [1])

Options:
1. Proceed
2. Collapse [X] and [Y] into one — if two splits feel too granular
3. Split a group further — divide its files across two new splits
4. Move a file to a different group
5. Edit a title or body
```

Wait for the user to confirm or adjust before continuing. Accept free-form responses (e.g. "collapse 2 and 3", "move Foo.swift to group 1") — map them to the appropriate action and re-present. When the user says something like "that's too many PRs", proactively suggest which adjacent splits are the best candidates to collapse based on their size and relationship.

Once the user confirms the proposal, if any binary files were detected, ask for their assignment:

> "The following binary files can't be split automatically and will be committed directly to a branch after the split runs. Which split should each one belong to?
> - {file path}
> - {file path}"

Write the assignments to `/tmp/split-pr-binary-assignments.json` as `{"path": split_index, ...}` using the file's `path` field from the parsed diff (the new path for renames). Do not include binary files in `file_hunks` in the plan — they are handled in Step 5 after the apply script runs.

## Step 4: Assign JIRA Keys

**Find the parent JIRA ticket:**
1. Check the current branch name for a JIRA key pattern (`[A-Z]+-[0-9]+`)
2. Check PR title/body (if working from an existing PR)
3. Check recent commits: `git log -10 --format="%s" | grep -oE '[A-Z]+-[0-9]+' | head -1`
4. If not found, ask: "What's the JIRA ticket for this work? (or type 'skip' to proceed without one)"

If the user skips or no key is found, omit JIRA keys from branch names and titles and proceed directly to Step 5.

**Ask how to handle JIRA:**

> "Found ticket `{KEY}`. How should I handle JIRA for the splits?
> 1. Reuse `{KEY}` across all branches — e.g. `feature/{KEY}/add-token-validator`, `feature/{KEY}/expand-permissions` (recommended)
> 2. Create a subtask per split — one new JIRA ticket per PR
> 3. Skip JIRA entirely — no ticket references in branch names or titles"

**Option 1 — Reuse parent key (default):** Use `{KEY}` as-is in all branch names and titles. No Atlassian API calls needed. Proceed to Step 5.

**Option 2 — Create subtasks:** Fetch the parent ticket's fields using the Atlassian MCP (`getJiraIssue`). Extract:
- **Labels** — `fields.labels` (array of strings)
- **Sprint** — `fields.customfield_10007` (array of sprint objects with `id`, `name`, `state`). If non-empty, use the sprint with `state: "active"`, or the last element if none is active. When creating the subtask pass `{"id": SPRINT_ID}`. If null or empty, omit.
- **Team** — `fields.customfield_13400` (object with `id` and `name`). When creating the subtask pass `{"id": "TEAM_ID"}`. If null, omit.

Determine the platform prefix by checking the parent ticket's Summary for a prefix pattern:
- `[iOS]`, `[Android]`, `[BE]` → square bracket format
- `(iOS)`, `(Android)`, `(BE)` → parenthesis format
- `iOS:`, `Android:`, `BE:` → colon format

If no prefix is found in the Summary, check labels, then infer from the repo name (`ios-*` → `iOS`, `android-*` → `Android`). Default to square brackets if still ambiguous. Use the detected format consistently for all subtask summaries.

Create one subtask per split using `createJiraIssue`:
- Summary: `{PREFIX} {description}` — the description is the text after the first `] ` in the proposed title (or the full title if there is no `] `)
- Issue type: Sub-task
- Parent: the parent ticket key
- Labels, Sprint, Team: copied from parent (omit any that are null/empty)

If a subtask creation fails, note which were already created and ask:
> "Subtask creation failed for split [{index}]: {error}. Already created: {keys}. Continue with those keys and skip the failed split, or stop entirely?"

After all subtasks are created, update both titles and branch names to use the real subtask keys (replace the placeholder key, keep the type prefix and description slug unchanged).

**Option 3 — Skip JIRA:** Use generic branch names without a ticket key: `{type}/{description-slug}`. Omit `[KEY]` from titles.

## Step 5: Build and Execute the Split Plan

Construct `/tmp/split-pr-plan.json`:

```json
{
  "base_ref": "{BASE_REF}",
  "splits": [
    {
      "index": 0,
      "branch": "{feature|bugfix|refactor}/{JIRA-KEY}/{description-of-change}",
      "title": "[{JIRA-KEY}] {description}",
      "body": "{commit body or empty string}",
      "depends_on": null,
      "file_hunks": {
        "path/to/File.swift": "all",
        "path/to/Shared.swift": ["0", "2"]
      }
    },
    {
      "index": 1,
      "branch": "{feature|bugfix|refactor}/{JIRA-KEY}/{description-of-change}",
      "title": "[{JIRA-KEY}] {description}",
      "body": "{commit body or empty string}",
      "depends_on": 0,
      "file_hunks": {
        "path/to/Other.swift": "all",
        "path/to/Shared.swift": ["1", "3"]
      }
    }
  ]
}
```

`title` is used as both the git commit message subject and the GitHub PR title. `body` is used as both the git commit message body and the base of the PR description.

`file_hunks` values: `"all"` applies every hunk for that file; a list of hunk IDs (strings from `parsed-diff.json`) applies only those hunks.

Run the apply script:
```bash
python3 {SKILL_DIR}/scripts/apply-split.py \
  --plan /tmp/split-pr-plan.json \
  --parsed-diff /tmp/split-pr-parsed.json \
  > /tmp/split-pr-apply-output.json || true
```

Read `/tmp/split-pr-apply-output.json`. Check for a top-level `"error"` field first — if present, the script failed before processing any splits (e.g. circular dependency in the plan); report the error and stop. Each split reports `status` (`success`, `warning`, `conflict`, or `failed`) and any `warnings`. A `status: failed` with an `error` containing `git apply failed:` means the patch did not apply cleanly — the most likely cause is a hunk whose context lines no longer match the base (e.g. the base branch advanced since the diff was taken). Report the error verbatim and ask the user to re-generate the diff against the current base.

Before handling conflicts, check for empty splits: any split whose `warnings` array contains the string `"No changes to commit — split may be empty"`. (`status: warning` alone is not sufficient — other non-empty warnings also produce that status.) If an empty split has other splits that depend on it, surface this immediately:

> "Split [{index}] `{branch}` produced no changes. The following splits depend on it:
> - [{index}] `{branch}`
>
> This usually means the grouping is wrong — those files may already be identical to the base. Would you like to:
> 1. Revise the plan — go back to Step 3 to regroup
> 2. Continue anyway — the dependent splits will be based on an empty branch"

If the user chooses to revise, stop and return to Step 3. If they continue, note that the dependent PRs will have no meaningful base diff.

If any splits have `status: conflict`, first show all conflicts at once so the user has the full picture:

> The following branches already exist:
> - `{branch}` (local and remote)
> - `{branch}` (remote only)
> - `{branch}` (local only)

Then step through each one individually and ask:

> `{branch}` — overwrite, skip, or cancel?
> 1. Overwrite — delete and recreate the branch
> 2. Skip — leave the branch as-is and don't create a PR for it
> 3. Cancel — stop the entire split

After all decisions are collected:

- If **cancel** was chosen for any split, stop entirely.
- If **no** split was chosen for "overwrite" (all conflicts were skipped), skip directly to Step 6 — there is nothing to re-run.
- Filter the plan to only the overwrite splits, their ancestors, and their transitive descendants:

```bash
python3 {SKILL_DIR}/scripts/filter-plan.py \
  --plan /tmp/split-pr-plan.json \
  --overwrite-indices {comma-separated indices, e.g. "0,2"} \
  --output /tmp/split-pr-plan.json
```

  Read the output. The `kept` and `removed` arrays tell you which branches will be recreated. Tell the user:

  > "To proceed, I'll force-push the following branches:
  > - `{branch}` (overwrite requested)
  > - `{branch}` (recreated to preserve dependency chain)
  >
  > Any open PRs against these branches will be updated in place, not closed."

  Before re-running, check each branch-to-be-overwritten for open PRs:

```bash
# Run for each branch in the overwrite set
gh pr list --repo {ORG}/{REPO} --head {branch} --state open --json number,url
```

If any open PRs are found, tell the user:

> "The following branches have open PRs. The re-run will **force-push** to update them in place — the PRs will stay open with updated diffs:
> - `{branch}` → #{number} {url}"

Wait for confirmation, then re-run.

```bash
python3 {SKILL_DIR}/scripts/apply-split.py \
  --plan /tmp/split-pr-plan.json \
  --parsed-diff /tmp/split-pr-parsed.json \
  --force \
  > /tmp/split-pr-apply-output.json || true
```

Do not create PRs for branches with `status: failed` or that were skipped.

**Commit binary files** (if any were identified in Step 3):

```bash
python3 {SKILL_DIR}/scripts/commit-binaries.py \
  --assignments /tmp/split-pr-binary-assignments.json \
  --parsed-diff /tmp/split-pr-parsed.json \
  --apply-output /tmp/split-pr-apply-output.json \
  --state-file /tmp/split-pr-state.json \
  --plan /tmp/split-pr-plan.json \
  > /tmp/split-pr-binary-output.json || true
```

For an existing PR, also pass `--pr-head-ref origin/{headRefName}`.

Read `/tmp/split-pr-binary-output.json`. Surface any entries in `skipped` to the user — these are binary files that couldn't be committed (failed split, or path not in diff) and will need to be added manually.

## Step 6: Create GitHub PRs

```bash
python3 {SKILL_DIR}/scripts/create-prs.py \
  --plan /tmp/split-pr-plan.json \
  --apply-output /tmp/split-pr-apply-output.json \
  --repo {ORG}/{REPO} \
  [--jira-base-url https://fetchrewards.atlassian.net/browse] \
  > /tmp/split-pr-prs.json
```

Include `--jira-base-url` only if a JIRA key is present in the split titles (Options 1 or 2 from Step 4). Read `/tmp/split-pr-prs.json`. If a top-level `error` field is set, report it and stop.

The script creates PRs in dependency order, then updates every body with `**Part N of TOTAL**`, `Depends on`, and `Parallel with` cross-references automatically.

## Step 7: Handle the Original PR (if applicable)

If the user was working from an existing PR, ask:

> "Do these splits fully replace {ORIGINAL_TITLE} (#{ORIGINAL_NUMBER})? Want me to close it?"

If yes, close it and post a comment listing the split PRs:

```bash
gh pr close {ORIGINAL_NUMBER} --repo {ORG}/{REPO}
gh pr comment {ORIGINAL_NUMBER} --repo {ORG}/{REPO} --body "$(cat <<'EOF'
Split into smaller PRs:
- #{PR1}: {title}
- #{PR2}: {title}
- #{PR3}: {title}
EOF
)"
```

Save the comment ID returned by `gh pr comment` (parse from the URL it prints, e.g. `https://github.com/{org}/{repo}/pull/{n}#issuecomment-{ID}`). Store it as `SPLIT_COMMENT_ID`.

If a re-run later produces different PR numbers (e.g. after a plan correction), **edit** the existing comment rather than posting a new one:

```bash
gh api --method PATCH repos/{ORG}/{REPO}/issues/comments/{SPLIT_COMMENT_ID} \
  --field body="Split into smaller PRs:
- #{PR1}: {title}
- #{PR2}: {title}"
```

This keeps the original PR's comment thread clean — one comment that stays accurate.

## Step 8: Clean Up and Report

```bash
rm -f /tmp/split-pr-diff.patch /tmp/split-pr-parsed.json /tmp/split-pr-plan.json \
      /tmp/split-pr-parse-warnings.txt /tmp/split-pr-apply-output.json \
      /tmp/split-pr-prs.json /tmp/split-pr-state.json \
      /tmp/split-pr-binary-assignments.json /tmp/split-pr-binary-output.json
```

Report:
- JIRA subtasks created (keys + links)
- PRs created (numbers + links)
- Dependency structure (which PRs chain, which are parallel)

Then offer to clean up the original working state — the split used worktrees and never touched the current branch. Offer based on input state:

- **Uncommitted changes:**
  > "Your working tree still has all the original changes (already captured in the split branches). What would you like to do?
  > 1. Stash and check out a split branch — which branch? (safe, recoverable)
  > 2. Stash and stay on this branch (safe, recoverable)
  > 3. Discard permanently and check out a split branch — which branch?
  > 4. Discard permanently and stay on this branch"

  For option 1, run:
  ```bash
  git stash push -m "pre-split original changes"
  git checkout {CHOSEN_SPLIT_BRANCH}
  ```
  For option 2, run:
  ```bash
  git stash push -m "pre-split original changes"
  ```
  For option 3, run:
  ```bash
  git restore --staged . && git restore .
  git checkout {CHOSEN_SPLIT_BRANCH}
  ```
  For option 4, run:
  ```bash
  git restore --staged . && git restore .
  ```

- **Committed unpushed:**
  > "Your current branch `{branch}` still has the original commits. What would you like to do?
  > 1. Check out a split branch and delete `{branch}` — which branch do you want to land on?
  > 2. Reset `{branch}` to `origin/{BASE}` in place (`git reset --hard origin/{BASE}`)
  > 3. Leave it as-is"

  `{BASE}` here is the base ref confirmed in Step 1 (e.g. `main`, or the user-corrected value if they overrode the default).

  For option 1, run:
  ```bash
  git checkout {CHOSEN_SPLIT_BRANCH}
  git branch -D {ORIGINAL_BRANCH}
  ```
  Guard: if `{CHOSEN_SPLIT_BRANCH}` equals `{ORIGINAL_BRANCH}`, skip the `git branch -D` — the branch is already checked out and cannot be deleted.

  For option 2, run:
  ```bash
  git reset --hard origin/{BASE}
  ```

- **Mixed:** handle the uncommitted changes first (they are already captured in the split branches):
  > "Your working tree has uncommitted changes. What would you like to do with them?
  > 1. Stash them — safe, recoverable if something went wrong with the split
  > 2. Discard permanently"

  For option 1, run:
  ```bash
  git stash push -m "pre-split original changes"
  ```
  For option 2, run:
  ```bash
  git restore --staged . && git restore .
  ```

  Then follow the committed-unpushed flow above for the commits on the branch.

- **Existing PR:** handled by Step 7. No cleanup needed unless the user is also on the original branch locally, in which case offer the same committed-unpushed options above.

---

## Memory Keys

- `split_pr_clone_{repo-slug}` — absolute local path to a specific repo clone
