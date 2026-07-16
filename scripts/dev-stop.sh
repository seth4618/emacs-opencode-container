#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/_common.sh"

load_context
cid="$(run_compose ps --all --quiet "$SERVICE_NAME")"
if [[ -z "$cid" ]]; then
  echo "No existing dev container to stop."
  exit 0
fi

if [[ -z "$(run_compose ps --quiet "$SERVICE_NAME")" ]]; then
  echo "Dev container is already stopped."
  exit 0
fi

run_compose stop "$SERVICE_NAME"
mkdir -p "$PROJECT_RUNTIME_DIR"
{
  printf 'stopped_container_id=%s\n' "$cid"
  printf 'stopped_at=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
} >> "$DEV_CONTAINER_STATE_FILE"
echo "Dev container stopped without removing it; use dev-resume.sh to restart it."
