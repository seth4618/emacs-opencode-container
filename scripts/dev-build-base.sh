#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/_common.sh"

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  cat <<USAGE
Usage: dev-build-base.sh [docker build options...]

Build the shared Emacs/OpenCode base image used by layered dev-container images.

Environment:
  EOC_BASE_IMAGE is ignored by this compatibility wrapper; the image tag is eoc-base-container:latest.
USAGE
  exit 0
fi

"$TOOL_HOME/scripts/dev-build-image.sh" base "$@"
