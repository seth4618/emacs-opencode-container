#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/_common.sh"

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
if [[ ! -f "$ROOT_DIR/.env" ]]; then
  echo "Missing $ROOT_DIR/.env. Copy .env.example to .env first."
  exit 1
fi

# shellcheck disable=SC1090
source "$ROOT_DIR/.env"

if [[ -z "${HOST_REPO_PATH:-}" ]]; then
  echo "HOST_REPO_PATH is not set in .env"
  exit 1
fi

if [[ ! -d "$HOST_REPO_PATH/.git" ]]; then
  echo "HOST_REPO_PATH does not look like a git checkout: $HOST_REPO_PATH"
  exit 1
fi

if [[ "${FORCE:-0}" != "1" ]]; then
  if [[ -n "$(git -C "$HOST_REPO_PATH" status --porcelain)" ]]; then
    echo "Host checkout is dirty. Re-run with FORCE=1 to override."
    exit 1
  fi
fi

echo "Exporting /workspace into $HOST_REPO_PATH (explicit one-way action)..."
exec_dev bash -lc 'cd /workspace && tar -cf - .' | tar -C "$HOST_REPO_PATH" -xf -

echo "Export complete. Review host changes with: git -C "$HOST_REPO_PATH" status"
