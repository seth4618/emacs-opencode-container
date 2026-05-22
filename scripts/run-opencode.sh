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

  if ! command -v opencode >/dev/null 2>&1; then
    echo "opencode command not found. Rebuild image and verify OPENCODE_NPM_PACKAGE in .env"
    exit 1
  fi

  exec opencode "$@"
' -- "$@"
