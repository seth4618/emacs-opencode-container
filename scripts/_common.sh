#!/usr/bin/env bash
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

resolve_git_common_dir() {
  local repo_root="$1"
  local git_common_dir
  if git_common_dir="$(git -C "$repo_root" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)"; then
    echo "$git_common_dir"
    return
  fi
  echo "$repo_root/.git"
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
  if [[ -z "${HOST_GIT_COMMON_DIR:-}" ]] \
    && ! { [[ -f "$PROJECT_ENV_FILE" ]] && grep -Eq '^[[:space:]]*HOST_GIT_COMMON_DIR=' "$PROJECT_ENV_FILE"; } \
    && ! { [[ -f "$PROJECT_COMPOSE_ENV_FILE" ]] && grep -Eq '^[[:space:]]*HOST_GIT_COMMON_DIR=' "$PROJECT_COMPOSE_ENV_FILE"; }; then
    HOST_GIT_COMMON_DIR="$(resolve_git_common_dir "$REPO_ROOT")"
    export HOST_GIT_COMMON_DIR
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
