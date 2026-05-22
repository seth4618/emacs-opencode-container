#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/_common.sh"

REPO_ROOT="$(resolve_repo_root)"
HELPERS_DIR="$REPO_ROOT/elisp-helpers"
TARGET_DIR="$HELPERS_DIR/opencode.el"
REMOTE_URL="https://codeberg.org/sczi/opencode.el.git"

mkdir -p "$HELPERS_DIR"

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
