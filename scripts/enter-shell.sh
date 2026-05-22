#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/_common.sh"
exec_dev bash -lc '
  set -euo pipefail
  cd "${PROJECT_WORKSPACE:-/workspace}"
  source "${PROJECT_WORKSPACE:-/workspace}/scripts/load-runtime-env.sh"
  load_runtime_env
  export PS1="C-$(basename "${PROJECT_WORKSPACE:-/workspace}")$ "
  exec bash -i
'
