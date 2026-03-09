#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
RUNTIME_DIR="$ROOT_DIR/.runtime"
SECRETS_LIST_FILE="${SECRETS_PATHS_FILE:-$ROOT_DIR/secrets-paths.txt}"

mkdir -p "$RUNTIME_DIR/secrets"

if [[ -f "$ROOT_DIR/.env" ]]; then
  # shellcheck disable=SC1090
  source "$ROOT_DIR/.env"
fi

: "${HOST_REPO_PATH:?HOST_REPO_PATH must be set in .env}"
HOST_UID="${HOST_UID:-$(id -u)}"
HOST_GID="${HOST_GID:-$(id -g)}"
WORKSPACE_DIRNAME="${WORKSPACE_DIRNAME:-$(basename "$HOST_REPO_PATH")}"
HOST_HOME="${HOST_HOME:-$HOME}"
HOST_OPENCODE_DIR="${HOST_OPENCODE_DIR:-$HOST_HOME/.local/share/opencode}"
HOST_EMACS_D_DIR="${HOST_EMACS_D_DIR:-$HOST_HOME/.emacs.d-container}"
HOST_CACHE_DIR="${HOST_CACHE_DIR:-$HOST_HOME/.cache}"
HOST_NPM_CACHE_DIR="${HOST_NPM_CACHE_DIR:-$HOST_HOME/.npm}"
HOST_PNPM_STORE_DIR="${HOST_PNPM_STORE_DIR:-$HOST_HOME/.local/share/pnpm/store}"
HOST_PNPM_HOME_DIR="${HOST_PNPM_HOME_DIR:-$HOST_HOME/.local/share/pnpm}"
HOST_PIP_CACHE_DIR="${HOST_PIP_CACHE_DIR:-$HOST_HOME/.cache/pip}"
HOST_SECRETS_BUNDLE_DIR="${HOST_SECRETS_BUNDLE_DIR:-$RUNTIME_DIR/secrets}"

mkdir -p "$HOST_OPENCODE_DIR" "$HOST_EMACS_D_DIR" "$HOST_CACHE_DIR" \
  "$HOST_NPM_CACHE_DIR" "$HOST_PNPM_STORE_DIR" "$HOST_PNPM_HOME_DIR" "$HOST_PIP_CACHE_DIR"

find "$RUNTIME_DIR/secrets" -mindepth 1 -maxdepth 1 -exec rm -rf {} +
if [[ -f "$SECRETS_LIST_FILE" ]]; then
  i=0
  while IFS= read -r path; do
    [[ -z "$path" || "$path" =~ ^# ]] && continue
    if [[ -e "$path" ]]; then
      ln -s "$path" "$RUNTIME_DIR/secrets/$(printf '%03d' "$i")-$(basename "$path")"
      i=$((i + 1))
    else
      echo "Warning: secret path does not exist, skipping: $path"
    fi
  done < "$SECRETS_LIST_FILE"
fi

cat > "$RUNTIME_DIR/compose.env" <<EOF
HOST_UID=$HOST_UID
HOST_GID=$HOST_GID
HOST_REPO_PATH=$HOST_REPO_PATH
WORKSPACE_DIRNAME=$WORKSPACE_DIRNAME
HOST_OPENCODE_DIR=$HOST_OPENCODE_DIR
HOST_EMACS_D_DIR=$HOST_EMACS_D_DIR
HOST_CACHE_DIR=$HOST_CACHE_DIR
HOST_NPM_CACHE_DIR=$HOST_NPM_CACHE_DIR
HOST_PNPM_STORE_DIR=$HOST_PNPM_STORE_DIR
HOST_PNPM_HOME_DIR=$HOST_PNPM_HOME_DIR
HOST_PIP_CACHE_DIR=$HOST_PIP_CACHE_DIR
HOST_SECRETS_BUNDLE_DIR=$HOST_SECRETS_BUNDLE_DIR
EOF

cd "$ROOT_DIR"
docker compose --env-file .env --env-file .runtime/compose.env up -d --build "$@"
