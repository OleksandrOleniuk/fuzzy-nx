#!/usr/bin/env bash
set -euo pipefail

PREFIX="${PREFIX:-$HOME/.local}"
BIN_DIR="$PREFIX/bin"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

mkdir -p "$BIN_DIR"
install -m 0755 "$SCRIPT_DIR/bin/fnx" "$BIN_DIR/fnx"

printf 'Installed fnx to %s/fnx\n' "$BIN_DIR"
case ":$PATH:" in
  *":$BIN_DIR:"*) ;;
  *) printf 'Add %s to your PATH if needed.\n' "$BIN_DIR" ;;
esac
