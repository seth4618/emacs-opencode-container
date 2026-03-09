#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/_common.sh"

exec_dev bash -lc '
  set -euo pipefail
  cd "${PROJECT_WORKSPACE:-/workspace}"

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

  if ! command -v opencode >/dev/null 2>&1; then
    echo "opencode command not found. Rebuild image and verify OPENCODE_NPM_PACKAGE in .env"
    exit 1
  fi

  exec opencode "$@"
' -- "$@"
