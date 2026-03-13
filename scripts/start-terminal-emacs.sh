#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/_common.sh"
exec_dev bash -lc 'if [[ -x "${PROJECT_WORKSPACE:-/workspace}/scripts/sync-emacs-base.sh" ]]; then "${PROJECT_WORKSPACE:-/workspace}/scripts/sync-emacs-base.sh"; fi; cd "${PROJECT_WORKSPACE:-/workspace}" && exec emacs -nw'
