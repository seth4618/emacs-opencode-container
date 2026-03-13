#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/_common.sh"

BRANCH_NAME="${1:-}"
TARGET_DIR="${2:-}"
ALLOW_DIRTY="${ALLOW_DIRTY:-0}"

if [[ -z "$BRANCH_NAME" || -z "$TARGET_DIR" ]]; then
  echo "Usage: $0 <branch-name> <target-dir-under-project-workspace>"
  exit 1
fi

exec_dev bash -lc "
  set -euo pipefail
  cd \"\${PROJECT_WORKSPACE:-/workspace}\"
  if [[ '$ALLOW_DIRTY' != '1' ]] && [[ -n \"\$(git status --porcelain)\" ]]; then
    echo 'Workspace is dirty. Commit/stash or re-run with ALLOW_DIRTY=1.'
    exit 1
  fi

  mkdir -p \"\$(dirname '$TARGET_DIR')\"
  git worktree add '$TARGET_DIR' -b '$BRANCH_NAME'
  echo 'Created worktree at $TARGET_DIR on branch $BRANCH_NAME'
"
