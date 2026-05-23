#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/_common.sh"
exec_dev bash -lc "
source /usr/local/bin/load-runtime-env
export PS1=\"C-\$(basename \"\$PWD\")$ \"
exec bash -i
"
