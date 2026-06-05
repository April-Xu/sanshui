#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SOURCE_DIR="$SKILL_DIR/assets/pet"
CODEX_ROOT="${CODEX_HOME:-$HOME/.codex}"
TARGET_DIR="$CODEX_ROOT/pets/sanshui"
TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"

if [[ ! -f "$SOURCE_DIR/pet.json" || ! -f "$SOURCE_DIR/spritesheet.webp" ]]; then
  echo "Missing bundled pet assets under $SOURCE_DIR" >&2
  exit 1
fi

mkdir -p "$CODEX_ROOT/pets"

if [[ -d "$TARGET_DIR" ]]; then
  BACKUP_DIR="${TARGET_DIR}.bak-${TIMESTAMP}"
  rm -rf "$BACKUP_DIR"
  mv "$TARGET_DIR" "$BACKUP_DIR"
  echo "Backed up existing pet to $BACKUP_DIR"
fi

mkdir -p "$TARGET_DIR"
cp "$SOURCE_DIR/pet.json" "$TARGET_DIR/pet.json"
cp "$SOURCE_DIR/spritesheet.webp" "$TARGET_DIR/spritesheet.webp"

echo "Installed Sanshui pet to $TARGET_DIR"
echo "Restart the Codex desktop app to reload custom pets."
