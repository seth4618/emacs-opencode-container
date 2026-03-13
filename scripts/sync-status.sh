#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/_common.sh"

HOST_PATH="${HOST_REPO_PATH:-}"
if [[ -z "$HOST_PATH" && -f "$(dirname "$0")/../.runtime/compose.env" ]]; then
  HOST_PATH="$(grep -E '^HOST_REPO_PATH=' "$(dirname "$0")/../.runtime/compose.env" | tail -n1 | cut -d= -f2-)"
fi

echo "=== Container workspace status ==="
exec_dev bash -lc 'cd "${PROJECT_WORKSPACE:-/workspace}" && git status -sb || true'

echo
if [[ -n "$HOST_PATH" && -d "$HOST_PATH/.git" ]]; then
  echo "=== Host checkout status ($HOST_PATH) ==="
  git -C "$HOST_PATH" status -sb || true
else
  echo "Host repo path unavailable in runtime environment; skipping host git status."
fi
