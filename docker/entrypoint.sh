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


# Load OpenCode-related env defaults for interactive shells and direct `opencode`.
if [[ -d /secrets ]]; then
  shopt -s nullglob
  for secrets_file in /secrets/*.env; do
    set -a
    # shellcheck disable=SC1090
    source "$secrets_file"
    set +a
  done
  shopt -u nullglob
fi

common_opencode_env="$HOME/.opencode-common.env"
repo_opencode_env="${PROJECT_WORKSPACE}/.devcontainer/opencode.env"

if [[ -f "$common_opencode_env" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$common_opencode_env"
  set +a
fi

if [[ -f "$repo_opencode_env" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$repo_opencode_env"
  set +a
fi

# Wayland clients require XDG_RUNTIME_DIR to be a user-owned 0700 directory.
# Keep this stable inside the container so `emacs` (without wrapper scripts)
# can start as a GUI app.
if [[ -n "${XDG_RUNTIME_DIR:-}" ]]; then
  mkdir -p "$XDG_RUNTIME_DIR"
  chmod 700 "$XDG_RUNTIME_DIR"
fi

# Docker may create bind-mount parent directories as root. Keep the socket
# bind target in /tmp and link it into the per-user XDG runtime dir.
if [[ -n "${XDG_RUNTIME_DIR:-}" && -n "${WAYLAND_DISPLAY:-}" ]]; then
  wayland_socket_in_tmp="/tmp/${WAYLAND_DISPLAY}"
  wayland_socket_in_runtime="${XDG_RUNTIME_DIR}/${WAYLAND_DISPLAY}"
  if [[ -S "$wayland_socket_in_tmp" && ! -e "$wayland_socket_in_runtime" ]]; then
    ln -s "$wayland_socket_in_tmp" "$wayland_socket_in_runtime"
  fi
fi


# Make shared OpenCode auth/config discoverable for direct `opencode` CLI usage.
if [[ -n "${OPENCODE_HOME:-}" ]]; then
  mkdir -p "$OPENCODE_HOME"

  if [[ -f /opencode-share/auth.json && ! -e "$OPENCODE_HOME/auth.json" ]]; then
    ln -s /opencode-share/auth.json "$OPENCODE_HOME/auth.json"
  fi

  if [[ -f /opencode-config/opencode.jsonc && ! -e "$OPENCODE_HOME/opencode.jsonc" ]]; then
    ln -s /opencode-config/opencode.jsonc "$OPENCODE_HOME/opencode.jsonc"
  fi
fi

exec "$@"
