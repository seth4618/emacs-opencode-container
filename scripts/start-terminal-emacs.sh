#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/_common.sh"
exec_dev bash -lc "$(container_runtime_prelude)
exec emacs -nw
"
