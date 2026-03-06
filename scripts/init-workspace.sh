#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/_common.sh"

MODE="${1:-init}"
if [[ "$MODE" != "init" && "$MODE" != "refresh" ]]; then
  echo "Usage: $0 [init|refresh]"
  exit 1
fi

exec_dev bash -lc "
  set -euo pipefail

  if [[ ! -e /src-host ]]; then
    echo '/src-host is missing; check HOST_REPO_PATH bind mount.'
    exit 1
  fi

  mkdir -p /workspace

  if [[ ! -d /workspace/.git ]]; then
    echo 'Creating writable /workspace clone from read-only /src-host (including .git)...'
    rsync -a --delete /src-host/ /workspace/
    exit 0
  fi

  if [[ '$MODE' == 'init' ]]; then
    echo '/workspace already initialized; leaving existing branch state untouched.'
    exit 0
  fi

  echo 'Refreshing tracked files from /src-host while preserving /workspace/.git ...'
  rsync -a --delete --exclude='.git/' /src-host/ /workspace/
"
