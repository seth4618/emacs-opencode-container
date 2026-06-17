#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/_common.sh"

usage() {
  cat <<USAGE
Usage: dev-build-image.sh <base|template-name> [docker build options...]

Build an Emacs/OpenCode layered image.

Images:
  base             builds eoc-base-container:latest from Dockerfile
  <template-name>  builds eoc-<template-name>-container:latest from docker-templates/<template-name>.docker

Environment:
  EOC_BASE_IMAGE   Base image used by template builds (default: eoc-base-container:latest)
USAGE
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" || $# -lt 1 ]]; then
  usage
  [[ $# -lt 1 ]] && exit 1 || exit 0
fi

image_kind="$1"
shift

if [[ "$image_kind" == "base" ]]; then
  image_name="eoc-base-container:latest"
  dockerfile="$TOOL_HOME/Dockerfile"
else
  template="$TOOL_HOME/docker-templates/${image_kind}.docker"
  if [[ ! -f "$template" ]]; then
    echo "Error: unknown image template '$image_kind': $template not found." >&2
    exit 1
  fi
  image_name="eoc-${image_kind}-container:latest"
  dockerfile="$template"
fi

if [[ "${EOC_SKIP_ELISP_SYNC:-}" == "1" ]]; then
  echo "Skipping elisp helper sync for image build (EOC_SKIP_ELISP_SYNC=1)."
else
  echo "Syncing elisp helpers for image build..."
  "$TOOL_HOME/scripts/sync-elisp-helpers.sh"
fi

if toolkit_rev="$(git -C "$TOOL_HOME" rev-parse --short=12 HEAD 2>/dev/null)"; then :; else toolkit_rev="unknown"; fi
if ! git -C "$TOOL_HOME" diff --quiet -- Dockerfile docker/ docker-templates/ .devcontainer/elisp-helpers/ 2>/dev/null; then
  toolkit_rev="${toolkit_rev}-dirty"
fi

if [[ "$image_kind" != "base" ]] && ! docker image inspect "${EOC_BASE_IMAGE:-eoc-base-container:latest}" >/dev/null 2>&1; then
  "$TOOL_HOME/scripts/dev-build-image.sh" base
fi

echo "Building ${image_name} from ${dockerfile} (toolkit revision: ${toolkit_rev})..."
docker build \
  --build-arg "EOC_TOOLKIT_REV=${toolkit_rev}" \
  --build-arg "BASE_IMAGE=${EOC_BASE_IMAGE:-eoc-base-container:latest}" \
  -t "${image_name}" \
  "$@" \
  -f "$dockerfile" \
  "$TOOL_HOME"
