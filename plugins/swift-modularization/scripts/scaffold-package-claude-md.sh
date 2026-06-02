#!/usr/bin/env bash
# scaffold-package-claude-md.sh
# Writes (or idempotently patches) a per-package CLAUDE.md from a lean template,
# keyed by package KIND.
#
# Tiers are ADDITIVE: ancestor CLAUDE.md files (app-project ios/CLAUDE.md, etc.)
# auto-load, so this package tier carries only its own delta and defers upward.
#
# Usage:
#   scaffold-package-claude-md.sh <kind> <package-dir>
#
#   <kind>         domain | infra
#   <package-dir>  path to the package root (where Package.swift lives)
#
# Writes:  <package-dir>/CLAUDE.md   (creates or patches the managed block)
#
# Examples:
#   scaffold-package-claude-md.sh domain App/Packages/Chat
#   scaffold-package-claude-md.sh infra  App/Packages/Networking

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_scaffold-lib.sh
. "$SCRIPT_DIR/_scaffold-lib.sh"

usage() {
  sed -n '2,20p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

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
write_managed_block "$PKG_DIR/CLAUDE.md" "kind=$KIND" "$CONTENT"

echo "✅ package CLAUDE.md scaffolded ($KIND) at $PKG_DIR/CLAUDE.md"
