#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/_common.sh"

exec_dev bash -lc '
set -euo pipefail
source /usr/local/bin/load-runtime-env

if [[ -z "${WAYLAND_DISPLAY:-}" ]]; then
  echo "WAYLAND_DISPLAY is not set in container. Check .env and docker-compose.yml"
  exit 1
fi
if [[ -z "${XDG_RUNTIME_DIR:-}" && "${WAYLAND_DISPLAY}" != /* ]]; then
  echo "XDG_RUNTIME_DIR is not set in container and WAYLAND_DISPLAY is not an absolute path."
  exit 1
fi

export GDK_BACKEND="${GDK_BACKEND:-wayland}"

# Wayland clients interpret WAYLAND_DISPLAY as either an absolute socket path
# or a socket name under XDG_RUNTIME_DIR. Docker bind-mounts the host socket
# at /tmp/$WAYLAND_DISPLAY, and docker/entrypoint.sh normally links that into
# XDG_RUNTIME_DIR on container startup. Recreate the link here as well because
# docker compose exec does not rerun the entrypoint.
if [[ "${WAYLAND_DISPLAY}" == /* ]]; then
  wayland_socket="${WAYLAND_DISPLAY}"
else
  wayland_socket="${XDG_RUNTIME_DIR}/${WAYLAND_DISPLAY}"
  tmp_socket="/tmp/${WAYLAND_DISPLAY}"
  if [[ ! -S "$wayland_socket" && -S "$tmp_socket" && ! -e "$wayland_socket" ]]; then
    mkdir -p "${XDG_RUNTIME_DIR}"
    chmod 700 "${XDG_RUNTIME_DIR}"
    ln -s "$tmp_socket" "$wayland_socket"
  fi
fi

if [[ ! -S "$wayland_socket" ]]; then
  echo "Wayland socket $wayland_socket is unavailable."
  echo "Run scripts/check-wayland.sh for diagnostics or use scripts/start-terminal-emacs.sh as fallback."
  exit 1
fi

exec emacs
'
