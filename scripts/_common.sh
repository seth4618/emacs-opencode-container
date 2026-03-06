#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPOSE_CMD=(docker compose)
SERVICE_NAME="dev"

run_compose() {
  (cd "$ROOT_DIR" && "${COMPOSE_CMD[@]}" "$@")
}

ensure_running() {
  local cid
  cid="$(run_compose ps -q "$SERVICE_NAME")"
  if [[ -z "$cid" ]]; then
    echo "Container not running; starting with docker compose up -d ..."
    run_compose up -d "$SERVICE_NAME"
  fi
}

exec_dev() {
  ensure_running
  run_compose exec "$SERVICE_NAME" "$@"
}
