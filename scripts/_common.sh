#!/usr/bin/env bash
set -euo pipefail

TOOL_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPOSE_CMD=(docker compose)
SERVICE_NAME="dev"

resolve_repo_root() {
  if [[ -n "${DEV_REPO_ROOT:-}" ]]; then
    echo "$DEV_REPO_ROOT"
    return
  fi
  git rev-parse --show-toplevel 2>/dev/null || {
    echo "Error: not inside a git repository. Run from a git worktree or set DEV_REPO_ROOT." >&2
    exit 1
  }
}

load_context() {
  REPO_ROOT="$(resolve_repo_root)"
  PROJECT_DOTDIR="$REPO_ROOT/.devcontainer"
  PROJECT_ENV_FILE="$PROJECT_DOTDIR/.env"
  PROJECT_RUNTIME_DIR="$PROJECT_DOTDIR/.runtime"
  PROJECT_COMPOSE_ENV_FILE="$PROJECT_RUNTIME_DIR/compose.env"

  runtime_env_args=()
  if [[ -f "$PROJECT_ENV_FILE" ]]; then
    runtime_env_args+=(--env-file "$PROJECT_ENV_FILE")
  fi
  if [[ -f "$PROJECT_COMPOSE_ENV_FILE" ]]; then
    runtime_env_args+=(--env-file "$PROJECT_COMPOSE_ENV_FILE")
  fi
}

run_compose() {
  load_context
  (cd "$REPO_ROOT" && "${COMPOSE_CMD[@]}" -f "$TOOL_HOME/docker-compose.yml" "${runtime_env_args[@]}" "$@")
}

ensure_running() {
  local cid
  cid="$(run_compose ps -q "$SERVICE_NAME")"
  if [[ -z "$cid" ]]; then
    echo "Container not running; starting with dev-up ..."
    "$TOOL_HOME/scripts/dev-up.sh"
  fi
}

exec_dev() {
  ensure_running
  run_compose exec "$SERVICE_NAME" "$@"
}

container_runtime_prelude() {
  cat <<'BASH'
set -euo pipefail

workspace_dir="/workspace/${WORKSPACE_DIRNAME:-}"
if [[ -z "${WORKSPACE_DIRNAME:-}" || ! -d "$workspace_dir" ]]; then
  workspace_dir="${PROJECT_WORKSPACE:-$PWD}"
fi
cd "$workspace_dir"

if [[ -d /secrets ]]; then
  shopt -s nullglob
  for non_env_file in /secrets/*; do
    if [[ -f "$non_env_file" && "$non_env_file" != *.env ]]; then
      echo "warning: skipping non-.env file in /secrets: $non_env_file" >&2
    fi
  done
  shopt -u nullglob

  shopt -s nullglob
  for env_file in /secrets/*.env; do
    set -a
    # shellcheck disable=SC1090
    source "$env_file"
    set +a
  done
  shopt -u nullglob
fi

repo_opencode_env="$workspace_dir/.devcontainer/opencode.env"
common_opencode_env="$HOME/.opencode-common.env"
if [[ -f "$common_opencode_env" ]]; then
  set -a; source "$common_opencode_env"; set +a
fi
if [[ -f "$repo_opencode_env" ]]; then
  set -a; source "$repo_opencode_env"; set +a
fi
BASH
}
