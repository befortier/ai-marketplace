#!/usr/bin/env bash
# _scaffold-lib.sh
# Shared helpers for the swift-modularization CLAUDE.md scaffolders.
# Not meant to be run directly — sourced by scaffold-package-claude-md.sh
# and scaffold-target-claude-md.sh.
#
# The scaffolders are CREATE-ONLY: they write a CLAUDE.md only if one does not
# already exist. An existing file is left untouched and skipped, so the script
# never silently overwrites or appends to a file you may have hand-edited.
# Pass --force to consciously regenerate (overwrite) the whole file.

set -euo pipefail

# Resolve this library's own directory so we can find ../templates regardless
# of the caller's working directory.
SCAFFOLD_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATES_DIR="$SCAFFOLD_LIB_DIR/../templates"

# render_template <relative-template-path> <heading>
# Prints the heading followed by the named template's body, leaving the literal
# placeholders (`<Domain>`/`Foo`) as-is for the author to fill in. Errors if the
# template is missing.
render_template() {
  local tpl="$TEMPLATES_DIR/$1"
  local heading="$2"
  if [ ! -f "$tpl" ]; then
    echo "error: missing template: $tpl" >&2
    exit 1
  fi
  printf '# %s\n\n' "$heading"
  cat "$tpl"
}

# write_claude_md <file> <content>
# Create-only writer. Writes <content> to <file> when <file> does NOT exist.
# When <file> already exists it is LEFT UNTOUCHED and skipped — unless
# SCAFFOLD_FORCE=1, in which case the whole file is overwritten. Always
# returns 0 (a skip is the safe default, not an error) so batch callers
# don't abort. Prints one status line per file.
write_claude_md() {
  local file="$1"
  local content="$2"

  mkdir -p "$(dirname "$file")"

  if [ -e "$file" ] && [ ! -f "$file" ]; then
    echo "error: target exists but is not a regular file: $file" >&2
    return 1
  fi

  if [ -e "$file" ] && [ "${SCAFFOLD_FORCE:-0}" != "1" ]; then
    echo "  ⏭  exists — skipped (pass --force to overwrite): $file"
    return 0
  fi

  local verb="wrote"
  [ -e "$file" ] && verb="overwrote (--force)"
  printf '%s\n' "$content" > "$file"
  echo "  ✓ $verb: $file"
}
