#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/_common.sh"

REPO_ROOT="$TOOL_HOME"
HELPERS_DIR="$REPO_ROOT/.devcontainer/elisp-helpers"
TARGET_DIR="$HELPERS_DIR/opencode.el"
LEGACY_HELPERS_DIR="$REPO_ROOT/elisp-helpers"
LEGACY_TARGET_DIR="$LEGACY_HELPERS_DIR/opencode.el"
REMOTE_URL="https://codeberg.org/sczi/opencode.el.git"

mkdir -p "$HELPERS_DIR"

if [[ ! -e "$TARGET_DIR" && -d "$LEGACY_TARGET_DIR/.git" ]]; then
  echo "Migrating legacy helper checkout from $LEGACY_TARGET_DIR to $TARGET_DIR"
  mv "$LEGACY_TARGET_DIR" "$TARGET_DIR"
  rmdir "$LEGACY_HELPERS_DIR" 2>/dev/null || true
fi

if [[ -d "$TARGET_DIR/.git" ]]; then
  echo "Updating $TARGET_DIR"
  git -C "$TARGET_DIR" pull --ff-only
else
  if [[ -e "$TARGET_DIR" ]]; then
    echo "error: $TARGET_DIR exists but is not a git repo" >&2
    exit 1
  fi
  echo "Cloning $REMOTE_URL into $TARGET_DIR"
  git clone "$REMOTE_URL" "$TARGET_DIR"
fi
