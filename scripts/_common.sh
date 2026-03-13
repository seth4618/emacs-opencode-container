#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPOSE_CMD=(docker compose)
SERVICE_NAME="dev"
RUNTIME_ENV_FILE="$ROOT_DIR/.runtime/compose.env"

runtime_env_args=()
if [[ -f "$ROOT_DIR/.env" ]]; then
  runtime_env_args+=(--env-file "$ROOT_DIR/.env")
fi
if [[ -f "$RUNTIME_ENV_FILE" ]]; then
  runtime_env_args+=(--env-file "$RUNTIME_ENV_FILE")
fi

run_compose() {
  (cd "$ROOT_DIR" && "${COMPOSE_CMD[@]}" "${runtime_env_args[@]}" "$@")
}

ensure_running() {
  local cid
  cid="$(run_compose ps -q "$SERVICE_NAME")"
  if [[ -z "$cid" ]]; then
    echo "Container not running; starting with scripts/dev-up.sh ..."
    "$ROOT_DIR/scripts/dev-up.sh"
  fi
}

exec_dev() {
  ensure_running
  run_compose exec "$SERVICE_NAME" "$@"
}
