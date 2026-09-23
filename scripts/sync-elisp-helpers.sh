#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/_common.sh"

REPO_ROOT="$TOOL_HOME"
HELPERS_DIR="$REPO_ROOT/.devcontainer/elisp-helpers"
TARGET_DIR="$HELPERS_DIR/opencode.el"
LEGACY_HELPERS_DIR="$REPO_ROOT/elisp-helpers"
LEGACY_TARGET_DIR="$LEGACY_HELPERS_DIR/opencode.el"
REMOTE_URL="https://codeberg.org/sczi/opencode.el.git"
CLAUDE_CODE_IDE_TARGET_DIR="$HELPERS_DIR/claude-code-ide.el"
CLAUDE_CODE_IDE_REMOTE_URL="https://github.com/manzaltu/claude-code-ide.el.git"
ELISP_SYNC_TIMEOUT_SECONDS="${ELISP_SYNC_TIMEOUT_SECONDS:-30}"

mkdir -p "$HELPERS_DIR"

if [[ ! -e "$TARGET_DIR" && -d "$LEGACY_TARGET_DIR/.git" ]]; then
  echo "Migrating legacy helper checkout from $LEGACY_TARGET_DIR to $TARGET_DIR"
  mv "$LEGACY_TARGET_DIR" "$TARGET_DIR"
  rmdir "$LEGACY_HELPERS_DIR" 2>/dev/null || true
fi

sync_checkout() {
  local target_dir="$1" remote_url="$2"

  if [[ -d "$target_dir/.git" ]]; then
    echo "Updating $target_dir"
    if ! GIT_TERMINAL_PROMPT=0 timeout --foreground "$ELISP_SYNC_TIMEOUT_SECONDS" \
      git -c credential.interactive=never -C "$target_dir" pull --ff-only; then
      if [[ "${ELISP_SYNC_STRICT:-0}" == "1" ]]; then
        echo "error: failed to update $target_dir" >&2
        return 1
      fi
      echo "warning: failed to update $target_dir; using the existing checkout" >&2
    fi
    return
  fi

  if [[ -e "$target_dir" ]]; then
    echo "error: $target_dir exists but is not a git repo" >&2
    return 1
  fi

  echo "Cloning $remote_url into $target_dir"
  if ! GIT_TERMINAL_PROMPT=0 timeout --foreground "$ELISP_SYNC_TIMEOUT_SECONDS" \
    git -c credential.interactive=never clone "$remote_url" "$target_dir"; then
    rm -rf "$target_dir"
    echo "error: failed to clone $remote_url" >&2
    return 1
  fi
}

sync_checkout "$TARGET_DIR" "$REMOTE_URL"
sync_checkout "$CLAUDE_CODE_IDE_TARGET_DIR" "$CLAUDE_CODE_IDE_REMOTE_URL"
