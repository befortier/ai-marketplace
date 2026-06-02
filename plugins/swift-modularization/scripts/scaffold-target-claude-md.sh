#!/usr/bin/env bash
# scaffold-target-claude-md.sh
# Writes (or idempotently patches) a per-target CLAUDE.md from a lean template,
# keyed by target ROLE.
#
# Tiers are ADDITIVE: the package CLAUDE.md and other ancestors auto-load, so
# this target tier carries only its own delta and defers upward.
#
# Usage:
#   scaffold-target-claude-md.sh <role> <package-dir> <target-name>
#
#   <role>         data | ui | view | live | non-live
#   <package-dir>  path to the package root (where Package.swift lives)
#   <target-name>  the target's Sources/ subdirectory name (e.g. ChatData)
#
# Writes:  <package-dir>/Sources/<target-name>/CLAUDE.md  (creates or patches)
#
# Examples:
#   scaffold-target-claude-md.sh data     App/Packages/Chat       ChatData
#   scaffold-target-claude-md.sh view     App/Packages/Chat       ChatView
#   scaffold-target-claude-md.sh non-live App/Packages/Networking Networking
#   scaffold-target-claude-md.sh live     App/Packages/Networking NetworkingLive

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_scaffold-lib.sh
. "$SCRIPT_DIR/_scaffold-lib.sh"

usage() {
  sed -n '2,24p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

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
write_managed_block "$TARGET_DIR/CLAUDE.md" "role=$ROLE" "$CONTENT"

echo "✅ target CLAUDE.md scaffolded ($ROLE) at $TARGET_DIR/CLAUDE.md"
