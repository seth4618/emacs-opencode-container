#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/_common.sh"

exec_dev bash -lc '
  set -euo pipefail
  workspace_dir="${PROJECT_WORKSPACE:-/workspace}"
  if [[ ! -f "$workspace_dir/scripts/load-runtime-env.sh" && -n "${WORKSPACE_DIRNAME:-}" && -f "/workspace/${WORKSPACE_DIRNAME}/scripts/load-runtime-env.sh" ]]; then
    workspace_dir="/workspace/${WORKSPACE_DIRNAME}"
  fi

  cd "$workspace_dir"
  source "$workspace_dir/scripts/load-runtime-env.sh"
  load_runtime_env

  if [[ -z "${WAYLAND_DISPLAY:-}" ]]; then
    echo "WAYLAND_DISPLAY is not set in container. Check .env and docker-compose.yml"
    exit 1
  fi
  export GDK_BACKEND="${GDK_BACKEND:-wayland}"

  if [[ ! -S "${XDG_RUNTIME_DIR}/${WAYLAND_DISPLAY}" ]]; then
    echo "Wayland socket ${XDG_RUNTIME_DIR}/${WAYLAND_DISPLAY} is unavailable."
    echo "Use scripts/start-terminal-emacs.sh as fallback."
    exit 1
  fi

  exec emacs
'
