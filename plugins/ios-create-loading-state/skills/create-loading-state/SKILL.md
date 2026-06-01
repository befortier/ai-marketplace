---
name: Create Loading State
description: This skill should be used when the user asks to "create a loading state", "add loading state", "add FailableLoadingState", "add LoadingState", "create failable loading state", "add async loading enum", or when implementing a new Swift package or module that needs loading/async state management enums.
---

# Create Loading State

This skill adds `FailableLoadingState` and `LoadingState` enums to the current project. Execute all steps immediately upon trigger — do not ask for confirmation.

## Execution Steps

1. **Find the target directory.** Search the project for Swift source directories. Look for patterns like `Sources/<ModuleName>/`, or an Xcode project group (e.g., `<ProjectName>/<ProjectName>/`). If multiple candidates exist, ask the user which one.

2. **Check for `Nothing` type.** Search the project for `struct Nothing`. If it does not exist, read `scripts/Nothing.swift` and add it to the list of files to write.

3. **Read the script files** from this skill's bundled scripts directory:
   - `scripts/FailableLoadingState.swift`
   - `scripts/LoadingState.swift`
   - `scripts/Nothing.swift` (only if step 2 found no existing `Nothing` type)

4. **Write all files** into the target directory.

5. **Report what was added** — list every file written and its target path.

## What These Types Are

- **`FailableLoadingState<Loading, Success, Failure>`** — Three-case enum (`.loading`, `.success`, `.failure`) for async operations that can fail. Includes `map`/`flatMap` variants for all three cases and bridges to `Result`.
- **`LoadingState<Loading, Completed>`** — Two-case enum (`.loading`, `.completed`) for components where the parent handles failure rendering. Includes `map`/`flatMap` variants and card-action helpers.
