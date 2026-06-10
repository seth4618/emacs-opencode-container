#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/_common.sh"

load_context
if [[ -f "$PROJECT_ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$PROJECT_ENV_FILE"
fi
if [[ -f "$PROJECT_COMPOSE_ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$PROJECT_COMPOSE_ENV_FILE"
fi

HOST_PATH="${HOST_REPO_PATH:-$REPO_ROOT}"

printf '=== Container workspace status ===\n'
exec_dev bash -lc 'cd "${PROJECT_WORKSPACE:-/workspace/${WORKSPACE_DIRNAME:-}}" && git status -sb || true'

printf '\n'
if [[ -n "$HOST_PATH" && -d "$HOST_PATH/.git" ]]; then
  printf '=== Host checkout status (%s) ===\n' "$HOST_PATH"
  git -C "$HOST_PATH" status -sb || true
else
  printf 'Host repo path unavailable in runtime environment; skipping host git status.\n'
fi
