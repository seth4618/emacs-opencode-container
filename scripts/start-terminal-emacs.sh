#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/_common.sh"
exec_dev bash -lc 'if [[ -x /workspace/scripts/sync-emacs-base.sh ]]; then /workspace/scripts/sync-emacs-base.sh; fi; cd /workspace && exec emacs -nw'
