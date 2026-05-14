#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/_common.sh"

exec_dev bash -lc '
  set -euo pipefail

  runtime_dir="${XDG_RUNTIME_DIR:-<unset>}"
  display_name="${WAYLAND_DISPLAY:-<unset>}"
  backend="${GDK_BACKEND:-<unset>}"
  runtime_socket="${XDG_RUNTIME_DIR:-}/$display_name"
  tmp_socket="/tmp/$display_name"

  echo "== Wayland diagnostics =="
  echo "USER: $(id -un) (uid=$(id -u), gid=$(id -g))"
  echo "WAYLAND_DISPLAY: $display_name"
  echo "XDG_RUNTIME_DIR: $runtime_dir"
  echo "GDK_BACKEND: $backend"
  echo

  if [[ "$runtime_dir" == "<unset>" ]]; then
    echo "XDG_RUNTIME_DIR is unset."
  else
    echo "-- XDG_RUNTIME_DIR stats --"
    ls -ld "$runtime_dir" || true
    stat -c "owner=%U group=%G mode=%a type=%F path=%n" "$runtime_dir" || true
  fi
  echo

  echo "-- Socket checks --"
  if [[ "$display_name" == "<unset>" ]]; then
    echo "WAYLAND_DISPLAY is unset."
  else
    [[ -S "$runtime_socket" ]] && echo "OK: runtime socket exists: $runtime_socket" || echo "MISS: runtime socket missing: $runtime_socket"
    [[ -S "$tmp_socket" ]] && echo "OK: tmp socket exists: $tmp_socket" || echo "MISS: tmp socket missing: $tmp_socket"
    if [[ -L "$runtime_socket" ]]; then
      echo "runtime socket symlink target: $(readlink "$runtime_socket")"
    fi
  fi
  echo

  echo "-- Emacs build info --"
  if command -v emacs >/dev/null 2>&1; then
    emacs --version | sed -n "1,2p"
    echo "emacs binary: $(command -v emacs)"
  else
    echo "emacs not found in PATH"
  fi
'
