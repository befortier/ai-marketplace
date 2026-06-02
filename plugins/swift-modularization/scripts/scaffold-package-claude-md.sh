#!/usr/bin/env bash
# scaffold-package-claude-md.sh
# Creates a per-package CLAUDE.md from a lean template, keyed by package KIND.
# CREATE-ONLY: if the CLAUDE.md already exists it is left untouched and skipped;
# pass --force to overwrite it.
#
# Tiers are ADDITIVE: ancestor CLAUDE.md files (app-project ios/CLAUDE.md, etc.)
# auto-load, so this package tier carries only its own delta and defers upward.
#
# Usage:
#   scaffold-package-claude-md.sh <kind> <package-dir> [--force]
#
#   <kind>         domain | infra
#   <package-dir>  path to the package root (where Package.swift lives)
#   --force, -f    overwrite an existing CLAUDE.md instead of skipping it
#
# Writes:  <package-dir>/CLAUDE.md   (only if absent, unless --force)
#
# Examples:
#   scaffold-package-claude-md.sh domain App/Packages/Chat
#   scaffold-package-claude-md.sh infra  App/Packages/Networking --force

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_scaffold-lib.sh
. "$SCRIPT_DIR/_scaffold-lib.sh"

usage() {
  sed -n '2,21p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
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

KIND="${1:-}"
PKG_DIR="${2:-}"

if [ -z "$KIND" ] || [ -z "$PKG_DIR" ]; then
  echo "error: missing arguments" >&2
  echo >&2
  usage >&2
  exit 2
fi

if [ ! -d "$PKG_DIR" ]; then
  echo "error: package directory not found: $PKG_DIR" >&2
  exit 1
fi

case "$KIND" in
  domain)
    TEMPLATE="pkg/domain.md"
    HEADING="$(basename "$PKG_DIR") package (domain)"
    ;;
  infra)
    TEMPLATE="pkg/infra.md"
    HEADING="$(basename "$PKG_DIR") package (infrastructure)"
    ;;
  *)
    echo "error: unknown kind '$KIND' (expected: domain | infra)" >&2
    echo >&2
    usage >&2
    exit 2
    ;;
esac

CONTENT="$(render_template "$TEMPLATE" "$HEADING")"
write_claude_md "$PKG_DIR/CLAUDE.md" "$CONTENT"
