#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/_common.sh"

BASE_IMAGE_NAME="${EOC_BASE_IMAGE:-eoc-base-container:latest}"

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  cat <<USAGE
Usage: dev-build-base.sh [docker build options...]

Build the shared Emacs/OpenCode base image used by per-repo .devcontainer/Dockerfile files.

Environment:
  EOC_BASE_IMAGE   Image tag to build (default: eoc-base-container:latest)
USAGE
  exit 0
fi

if [[ "${EOC_SKIP_ELISP_SYNC:-}" == "1" ]]; then
  echo "Skipping elisp helper sync for base image build (EOC_SKIP_ELISP_SYNC=1)."
else
  echo "Syncing elisp helpers for base image build..."
  "$TOOL_HOME/scripts/sync-elisp-helpers.sh"
fi

if toolkit_rev="$(git -C "$TOOL_HOME" rev-parse --short=12 HEAD 2>/dev/null)"; then
  :
else
  toolkit_rev="unknown"
fi

if ! git -C "$TOOL_HOME" diff --quiet -- Dockerfile docker/ .devcontainer/elisp-helpers/ 2>/dev/null; then
  toolkit_rev="${toolkit_rev}-dirty"
fi

echo "Building ${BASE_IMAGE_NAME} from ${TOOL_HOME}/Dockerfile (toolkit revision: ${toolkit_rev})..."
docker build \
  --build-arg "EOC_TOOLKIT_REV=${toolkit_rev}" \
  -t "${BASE_IMAGE_NAME}" \
  "$@" \
  -f "$TOOL_HOME/Dockerfile" \
  "$TOOL_HOME"
