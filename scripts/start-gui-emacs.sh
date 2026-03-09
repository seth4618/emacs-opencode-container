#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/_common.sh"

exec_dev bash -lc '
  set -euo pipefail

  EMACS_DIR="${HOME}/.emacs.d"

  if [[ ! -d "$EMACS_DIR" ]]; then
    mkdir -p "$EMACS_DIR" 2>/dev/null || true
  fi

  if [[ ! -w "$EMACS_DIR" ]]; then
    echo "${EMACS_DIR} is not writable; falling back to /workspace/.emacs.d"
    export HOME=/workspace
    EMACS_DIR="${HOME}/.emacs.d"
    mkdir -p "$EMACS_DIR"
  fi

  if [[ -z "${WAYLAND_DISPLAY:-}" ]]; then
    echo "WAYLAND_DISPLAY is not set in container. Check .env and docker-compose.yml"
    exit 1
  fi
  if [[ ! -S "${XDG_RUNTIME_DIR}/${WAYLAND_DISPLAY}" ]]; then
    echo "Wayland socket ${XDG_RUNTIME_DIR}/${WAYLAND_DISPLAY} is unavailable."
    echo "Use scripts/start-terminal-emacs.sh as fallback."
    exit 1
  fi

  if [[ ! -f "${EMACS_DIR}/init.el" && -d /opt/emacs-base ]]; then
    rsync -a --ignore-existing /opt/emacs-base/ "${EMACS_DIR}/"
  fi

  cd /workspace
  exec emacs
'
