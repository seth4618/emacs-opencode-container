#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/_common.sh"

exec_dev bash -lc '
  set -euo pipefail
  if [[ -z "${WAYLAND_DISPLAY:-}" ]]; then
    echo "WAYLAND_DISPLAY is not set in container. Check .env and docker-compose.yml"
    exit 1
  fi
  if [[ ! -S "${XDG_RUNTIME_DIR}/${WAYLAND_DISPLAY}" ]]; then
    echo "Wayland socket ${XDG_RUNTIME_DIR}/${WAYLAND_DISPLAY} is unavailable."
    echo "Use scripts/start-terminal-emacs.sh as fallback."
    exit 1
  fi

  if [[ -x "${PROJECT_WORKSPACE:-/workspace}/scripts/sync-emacs-base.sh" ]]; then
    "${PROJECT_WORKSPACE:-/workspace}/scripts/sync-emacs-base.sh"
  fi

  cd "${PROJECT_WORKSPACE:-/workspace}"
  exec emacs
'
