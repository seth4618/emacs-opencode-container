#!/usr/bin/env bash
set -euo pipefail

workspace_name="${WORKSPACE_DIRNAME:-}"
if [[ -z "$workspace_name" && -n "${HOST_REPO_PATH:-}" ]]; then
  workspace_name="$(basename "$HOST_REPO_PATH")"
fi

if [[ -n "$workspace_name" ]]; then
  export PROJECT_WORKSPACE="/workspace/${workspace_name}"
else
  export PROJECT_WORKSPACE="/workspace"
fi

if [[ "$*" == *"sleep infinity"* ]]; then
  exec "$@"
fi

exec "$@"
