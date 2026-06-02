#!/usr/bin/env bash
# scaffold-target-claude-md.sh
# Creates a per-target CLAUDE.md from a lean template, keyed by target ROLE.
# CREATE-ONLY: if the CLAUDE.md already exists it is left untouched and skipped;
# pass --force to overwrite it.
#
# Tiers are ADDITIVE: the package CLAUDE.md and other ancestors auto-load, so
# this target tier carries only its own delta and defers upward.
#
# Usage:
#   scaffold-target-claude-md.sh <role> <package-dir> <target-name> [--force]
#
#   <role>         data | ui | view | live | non-live
#   <package-dir>  path to the package root (where Package.swift lives)
#   <target-name>  the target's Sources/ subdirectory name (e.g. ChatData)
#   --force, -f    overwrite an existing CLAUDE.md instead of skipping it
#
# Writes:  <package-dir>/Sources/<target-name>/CLAUDE.md  (only if absent, unless --force)
#
# Examples:
#   scaffold-target-claude-md.sh data     App/Packages/Chat       ChatData
#   scaffold-target-claude-md.sh view     App/Packages/Chat       ChatView
#   scaffold-target-claude-md.sh non-live App/Packages/Networking Networking
#   scaffold-target-claude-md.sh live     App/Packages/Networking NetworkingLive --force

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_scaffold-lib.sh
. "$SCRIPT_DIR/_scaffold-lib.sh"

usage() {
  sed -n '2,25p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

# Extract --force/-f, leave the positional args.
SCAFFOLD_FORCE="${SCAFFOLD_FORCE:-0}"
POSITIONAL=()
while [ $# -gt 0 ]; do
  case "$1" in
    --force|-f) SCAFFOLD_FORCE=1; shift ;;
    --*) echo "error: unknown option: $1" >&2; echo >&2; usage >&2; exit 2 ;;
    *) POSITIONAL+=("$1"); shift ;;
  esac
done
if [ ${#POSITIONAL[@]} -gt 0 ]; then set -- "${POSITIONAL[@]}"; else set --; fi
export SCAFFOLD_FORCE

ROLE="${1:-}"
PKG_DIR="${2:-}"
TARGET="${3:-}"

if [ -z "$ROLE" ] || [ -z "$PKG_DIR" ] || [ -z "$TARGET" ]; then
  echo "error: missing arguments" >&2
  echo >&2
  usage >&2
  exit 2
fi

if [ ! -d "$PKG_DIR" ]; then
  echo "error: package directory not found: $PKG_DIR" >&2
  exit 1
fi

case "$ROLE" in
  data)     TEMPLATE="tgt/data.md";     LABEL="data" ;;
  ui)       TEMPLATE="tgt/ui.md";       LABEL="ui" ;;
  view)     TEMPLATE="tgt/view.md";     LABEL="view" ;;
  live)     TEMPLATE="tgt/live.md";     LABEL="live" ;;
  non-live) TEMPLATE="tgt/non-live.md"; LABEL="abstraction" ;;
  *)
    echo "error: unknown role '$ROLE' (expected: data | ui | view | live | non-live)" >&2
    echo >&2
    usage >&2
    exit 2
    ;;
esac

TARGET_DIR="$PKG_DIR/Sources/$TARGET"
HEADING="$TARGET target ($LABEL)"

CONTENT="$(render_template "$TEMPLATE" "$HEADING")"
write_claude_md "$TARGET_DIR/CLAUDE.md" "$CONTENT"
