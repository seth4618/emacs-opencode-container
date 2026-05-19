#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/_common.sh"

REPO_ROOT="$(resolve_repo_root)"
PROJECT_DOTDIR="$REPO_ROOT/.devcontainer"
PROJECT_RUNTIME_DIR="$PROJECT_DOTDIR/.runtime"
PROJECT_ENV_FILE="$PROJECT_DOTDIR/.env"

mkdir -p "$PROJECT_RUNTIME_DIR/secrets"

if [[ ! -f "$PROJECT_ENV_FILE" ]]; then
  cat > "$PROJECT_ENV_FILE" <<ENV
# Required
HOST_REPO_PATH=$REPO_ROOT
WAYLAND_SOCKET_PATH=/run/user/$(id -u)/wayland-0

# Optional
COMPOSE_PROJECT_NAME=$(basename "$REPO_ROOT")-dev
# HOST_COMMON_HOME=$HOME/.opencode-common-home
ENV
  echo "Created $PROJECT_ENV_FILE"
else
  echo "Exists: $PROJECT_ENV_FILE"
fi
