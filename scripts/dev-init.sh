#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/_common.sh"

REPO_ROOT="$(resolve_repo_root)"
PROJECT_DOTDIR="$REPO_ROOT/.devcontainer"
PROJECT_RUNTIME_DIR="$PROJECT_DOTDIR/.runtime"
PROJECT_ENV_FILE="$PROJECT_DOTDIR/.env"

is_valid_compose_project_name() {
  [[ "$1" =~ ^[a-z0-9][a-z0-9_-]*$ ]]
}

sanitize_compose_project_name() {
  local raw="$1"
  local sanitized
  sanitized="$(printf '%s' "$raw" \
    | tr '[:upper:]' '[:lower:]' \
    | sed -E 's/[^a-z0-9_-]+/-/g; s/^[^a-z0-9]+//; s/[-_]+$//')"
  if [[ -z "$sanitized" ]]; then
    sanitized="dev"
  fi
  printf '%s' "$sanitized"
}

repo_dirname="$(basename "$REPO_ROOT")"
if [[ "${repo_dirname,,}" == *-dev ]]; then
  DEFAULT_COMPOSE_PROJECT_NAME="$(sanitize_compose_project_name "$repo_dirname")"
else
  DEFAULT_COMPOSE_PROJECT_NAME="$(sanitize_compose_project_name "${repo_dirname}-dev")"
fi

ensure_valid_compose_project_name() {
  local current_line current_value replacement tmp_file
  current_line="$(grep -E '^[[:space:]]*COMPOSE_PROJECT_NAME=' "$PROJECT_ENV_FILE" | tail -n1 || true)"
  if [[ -z "$current_line" ]]; then
    printf '\nCOMPOSE_PROJECT_NAME=%s\n' "$DEFAULT_COMPOSE_PROJECT_NAME" >> "$PROJECT_ENV_FILE"
    echo "Added COMPOSE_PROJECT_NAME=$DEFAULT_COMPOSE_PROJECT_NAME"
    return
  fi

  current_value="${current_line#*=}"
  current_value="${current_value%$'\r'}"
  if is_valid_compose_project_name "$current_value"; then
    return
  fi

  replacement="$(sanitize_compose_project_name "$current_value")"
  tmp_file="$(mktemp)"
  awk -v replacement="COMPOSE_PROJECT_NAME=$replacement" '
    BEGIN { replaced = 0 }
    /^[[:space:]]*COMPOSE_PROJECT_NAME=/ && !replaced { print replacement; replaced = 1; next }
    { print }
  ' "$PROJECT_ENV_FILE" > "$tmp_file"
  mv "$tmp_file" "$PROJECT_ENV_FILE"
  echo "Updated invalid COMPOSE_PROJECT_NAME=$current_value to COMPOSE_PROJECT_NAME=$replacement"
}

mkdir -p "$PROJECT_RUNTIME_DIR/secrets"

if [[ ! -f "$PROJECT_ENV_FILE" ]]; then
  cat > "$PROJECT_ENV_FILE" <<ENV
# Required
HOST_REPO_PATH=$REPO_ROOT
WAYLAND_SOCKET_PATH=/run/user/$(id -u)/wayland-0

# Optional
# Docker Compose project names must be lowercase [a-z0-9_-] and start with [a-z0-9].
COMPOSE_PROJECT_NAME=$DEFAULT_COMPOSE_PROJECT_NAME
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

ensure_valid_compose_project_name

PROJECT_GITIGNORE="$PROJECT_DOTDIR/.gitignore"
if [[ ! -f "$PROJECT_GITIGNORE" ]]; then
  cat > "$PROJECT_GITIGNORE" <<'GITIGNORE'
.env
.runtime/
opencode.env
GITIGNORE
  echo "Created $PROJECT_GITIGNORE"
else
  echo "Exists: $PROJECT_GITIGNORE"
fi

PROJECT_DOCKERFILE="$PROJECT_DOTDIR/Dockerfile"
if [[ ! -f "$PROJECT_DOCKERFILE" ]]; then
  cat > "$PROJECT_DOCKERFILE" <<'DOCKERFILE'
ARG BASE_IMAGE=eoc-base-container:latest
FROM ${BASE_IMAGE}

ARG DEBIAN_FRONTEND=noninteractive
ARG USERNAME=dev
ARG USER_UID=1000
ARG USER_GID=1000
ARG OPENCODE_NPM_PACKAGE=opencode-ai

# Baseline language tooling and OpenCode CLI. Delete this block if the repo
# does not need the bundled JavaScript/Python/Solidity tools or OpenCode CLI.
RUN npm install -g \
    pnpm \
    typescript \
    typescript-language-server \
    pyright \
    solhint \
    hardhat \
    @nomicfoundation/solidity-language-server \
    "$OPENCODE_NPM_PACKAGE"

# LaTeX / TeX Live support. Delete this block if the repo does not build LaTeX.
RUN apt-get update && apt-get install -y --no-install-recommends \
    latexmk \
    texlive-latex-recommended \
    texlive-latex-extra \
    texlive-fonts-recommended \
    texlive-bibtex-extra \
    biber \
    chktex \
    && rm -rf /var/lib/apt/lists/*

# Required project user layer. Keep this even if you delete all optional tooling
# above; it makes the final image match the host UID/GID used by Docker Compose.
RUN set -eux; \
    if ! getent group "${USER_GID}" >/dev/null; then \
      groupadd --gid "${USER_GID}" "${USERNAME}"; \
    fi; \
    if id -u "${USERNAME}" >/dev/null 2>&1; then \
      usermod --uid "${USER_UID}" --gid "${USER_GID}" "${USERNAME}"; \
    else \
      useradd --uid "${USER_UID}" --gid "${USER_GID}" --create-home --shell /bin/bash "${USERNAME}"; \
    fi; \
    mkdir -p "/home/${USERNAME}" /workspace; \
    chown -R "${USER_UID}:${USER_GID}" "/home/${USERNAME}" /workspace

USER ${USERNAME}
WORKDIR /workspace

ENV HOME=/home/${USERNAME}
ENV PATH=${HOME}/.local/bin:${PATH}
DOCKERFILE
  echo "Created $PROJECT_DOCKERFILE"
else
  echo "Exists: $PROJECT_DOCKERFILE"
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
