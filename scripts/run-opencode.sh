#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/_common.sh"

exec_dev bash -lc "$(container_runtime_prelude)
if ! command -v opencode >/dev/null 2>&1; then
  echo \"opencode command not found. Rebuild image and verify OPENCODE_NPM_PACKAGE in .env\"
  exit 1
fi

exec opencode \"\$@\"
" -- "$@"
