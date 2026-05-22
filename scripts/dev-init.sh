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
# HOST_OPENCODE_SHARE_DIR=$HOME/.local/share/opencode
# HOST_OPENCODE_CONFIG_DIR=$HOME/.config/opencode
# HOST_SSH_DIR=$HOME/.ssh
# OPENCODE_MODEL=gpt-5
ENV
  echo "Created $PROJECT_ENV_FILE"
else
  echo "Exists: $PROJECT_ENV_FILE"
fi

OPENCODE_ENV_TEMPLATE="$PROJECT_DOTDIR/opencode.env.template"
if [[ ! -f "$OPENCODE_ENV_TEMPLATE" ]]; then
  cat > "$OPENCODE_ENV_TEMPLATE" <<'ENV'
# OpenCode runtime environment template (repo-specific).
# Copy to .devcontainer/opencode.env and uncomment what you need.

# Model defaults (examples):
# OPENCODE_MODEL=gpt-5
# OPENCODE_MODEL=codex

# Provider credentials (examples):
# OPENAI_API_KEY=
# OPENAI_BASE_URL=
ENV
  echo "Created $OPENCODE_ENV_TEMPLATE"
else
  echo "Exists: $OPENCODE_ENV_TEMPLATE"
fi
