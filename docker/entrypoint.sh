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

sync_emacs_base() {
  local sync_script="${PROJECT_WORKSPACE:-/workspace}/scripts/sync-emacs-base.sh"
  if [[ -x "$sync_script" ]]; then
    "$sync_script"
  fi
}

# Ensure ~/.emacs.d in the persistent host mount always gets the base config
# from this repo when the container starts.
sync_emacs_base

exec "$@"
