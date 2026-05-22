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
  exec emacs -nw
'
