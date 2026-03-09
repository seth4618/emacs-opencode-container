#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/_common.sh"
exec_dev bash -lc 'cd "${PROJECT_WORKSPACE:-/workspace}" && export PS1="C-$(basename "${PROJECT_WORKSPACE:-/workspace}")$ "; exec bash -i'
