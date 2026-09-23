#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/_common.sh"

exec_dev bash -lc '
source /usr/local/bin/load-runtime-env
if ! command -v claude >/dev/null 2>&1; then
  echo "claude command not found. Rebuild the selected image with cdev build-image, then run cdev up." >&2
  exit 1
fi

exec claude "$@"
' -- "$@"
