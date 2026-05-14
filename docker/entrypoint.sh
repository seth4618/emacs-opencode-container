#!/usr/bin/env bash
set -euo pipefail

workspace_name="${WORKSPACE_DIRNAME:-}"
if [[ -z "$workspace_name" && -n "${HOST_REPO_PATH:-}" ]]; then
  workspace_name="$(basename "$HOST_REPO_PATH")"
fi

if [[ -n "$workspace_name" ]]; then
  export PROJECT_WORKSPACE="/workspace/${workspace_name}"
else
  export PROJECT_WORKSPACE="/workspace"
fi

# Wayland clients require XDG_RUNTIME_DIR to be a user-owned 0700 directory.
# Keep this stable inside the container so `emacs` (without wrapper scripts)
# can start as a GUI app.
if [[ -n "${XDG_RUNTIME_DIR:-}" ]]; then
  mkdir -p "$XDG_RUNTIME_DIR"
  chmod 700 "$XDG_RUNTIME_DIR" || true
fi

exec "$@"
