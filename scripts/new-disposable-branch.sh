#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/_common.sh"

BRANCH_NAME="${1:-dispose/$(date +%Y%m%d-%H%M%S)}"
ALLOW_DIRTY="${ALLOW_DIRTY:-0}"

exec_dev bash -lc "
  set -euo pipefail
  cd /workspace
  if [[ '$ALLOW_DIRTY' != '1' ]] && [[ -n \"\$(git status --porcelain)\" ]]; then
    echo 'Workspace is dirty. Commit/stash or re-run with ALLOW_DIRTY=1.'
    exit 1
  fi
  git switch -c '$BRANCH_NAME'
  echo 'Created branch: $BRANCH_NAME'
"
