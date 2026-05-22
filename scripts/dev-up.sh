#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/_common.sh"

echo "Running dev-init.sh..."
if ! "$(dirname "$0")/dev-init.sh"; then
  echo "dev-init.sh failed; aborting dev-up." >&2
  exit 1
fi

load_context
SECRETS_LIST_FILE="${SECRETS_PATHS_FILE:-$REPO_ROOT/secrets-paths.txt}"

# shellcheck disable=SC1090
source "$PROJECT_ENV_FILE"

: "${HOST_REPO_PATH:=$REPO_ROOT}"
HOST_UID="${HOST_UID:-$(id -u)}"
HOST_GID="${HOST_GID:-$(id -g)}"
WORKSPACE_DIRNAME="${WORKSPACE_DIRNAME:-$(basename "$HOST_REPO_PATH")}" 
HOST_HOME="${HOST_HOME:-$HOME}"
HOST_OPENCODE_SHARE_DIR_SET="${HOST_OPENCODE_SHARE_DIR:-}"
HOST_OPENCODE_SHARE_DIR="${HOST_OPENCODE_SHARE_DIR:-$HOST_HOME/.local/share/opencode}"
HOST_OPENCODE_CONFIG_DIR="${HOST_OPENCODE_CONFIG_DIR:-$HOST_HOME/.config/opencode}"
PROJECT_OPENCODE_STATE_DIR="$PROJECT_DOTDIR/.runtime/opencode-state"
HOST_CACHE_DIR="${HOST_CACHE_DIR:-$HOST_HOME/.cache}"
HOST_NPM_CACHE_DIR="${HOST_NPM_CACHE_DIR:-$HOST_HOME/.npm}"
HOST_PNPM_STORE_DIR="${HOST_PNPM_STORE_DIR:-$HOST_HOME/.local/share/pnpm/store}"
HOST_PNPM_HOME_DIR="${HOST_PNPM_HOME_DIR:-$HOST_HOME/.local/share/pnpm}"
HOST_PIP_CACHE_DIR="${HOST_PIP_CACHE_DIR:-$HOST_HOME/.cache/pip}"
HOST_COMMON_HOME="${HOST_COMMON_HOME:-$HOST_HOME/.opencode-common-home}"
HOST_SECRETS_BUNDLE_DIR="${HOST_SECRETS_BUNDLE_DIR:-$PROJECT_RUNTIME_DIR/secrets}"
HOST_SSH_DIR="${HOST_SSH_DIR:-$HOST_HOME/.ssh}"
if [[ -n "${HOST_OPENCODE_DIR:-}" && -z "$HOST_OPENCODE_SHARE_DIR_SET" ]]; then
  echo "warning: HOST_OPENCODE_DIR is deprecated and ignored; set HOST_OPENCODE_SHARE_DIR/HOST_OPENCODE_CONFIG_DIR instead."
fi

# Resolve default model precedence: repo .env value wins; otherwise fallback to common-home.
if [[ -z "${OPENCODE_MODEL:-}" ]]; then
  COMMON_OPENCODE_ENV_FILE="${HOST_COMMON_HOME}/.opencode-common.env"
  if [[ -f "$COMMON_OPENCODE_ENV_FILE" ]]; then
    common_model="$(grep -E '^[[:space:]]*OPENCODE_MODEL=' "$COMMON_OPENCODE_ENV_FILE" | tail -n1 | cut -d= -f2-)"
    if [[ -n "${common_model:-}" ]]; then
      OPENCODE_MODEL="$common_model"
    fi
  fi
fi

mkdir -p "$HOST_OPENCODE_SHARE_DIR" "$HOST_OPENCODE_CONFIG_DIR" "$PROJECT_OPENCODE_STATE_DIR" "$HOST_CACHE_DIR" "$HOST_NPM_CACHE_DIR" "$HOST_PNPM_STORE_DIR" "$HOST_PNPM_HOME_DIR" "$HOST_PIP_CACHE_DIR" "$PROJECT_RUNTIME_DIR/secrets"
if [[ ! -d "$HOST_SSH_DIR" ]]; then
  mkdir -p "$HOST_SSH_DIR"
  chmod 700 "$HOST_SSH_DIR"
fi
"$TOOL_HOME/scripts/setup-common-home.sh" "$HOST_COMMON_HOME" "/workspace/$WORKSPACE_DIRNAME" >/dev/null

find "$PROJECT_RUNTIME_DIR/secrets" -mindepth 1 -maxdepth 1 -exec rm -rf {} +
if [[ -f "$SECRETS_LIST_FILE" ]]; then
  i=0
  while IFS= read -r path; do
    [[ -z "$path" || "$path" =~ ^# ]] && continue
    if [[ -e "$path" ]]; then
      if [[ -d "$path" ]]; then
        target="$PROJECT_RUNTIME_DIR/secrets/$(printf '%03d' "$i")-$(basename "$path")"
        cp -a "$path" "$target"
      else
        target="$PROJECT_RUNTIME_DIR/secrets/$(printf '%03d' "$i")-$(basename "$path").env"
        cp -aL "$path" "$target"
      fi
      i=$((i + 1))
    fi
  done < "$SECRETS_LIST_FILE"
fi

cat > "$PROJECT_COMPOSE_ENV_FILE" <<ENV
HOST_UID=$HOST_UID
HOST_GID=$HOST_GID
HOST_REPO_PATH=$HOST_REPO_PATH
WORKSPACE_DIRNAME=$WORKSPACE_DIRNAME
HOST_OPENCODE_SHARE_DIR=$HOST_OPENCODE_SHARE_DIR
HOST_OPENCODE_CONFIG_DIR=$HOST_OPENCODE_CONFIG_DIR
HOST_CACHE_DIR=$HOST_CACHE_DIR
HOST_NPM_CACHE_DIR=$HOST_NPM_CACHE_DIR
HOST_PNPM_STORE_DIR=$HOST_PNPM_STORE_DIR
HOST_PNPM_HOME_DIR=$HOST_PNPM_HOME_DIR
HOST_PIP_CACHE_DIR=$HOST_PIP_CACHE_DIR
HOST_COMMON_HOME=$HOST_COMMON_HOME
HOST_SECRETS_BUNDLE_DIR=$HOST_SECRETS_BUNDLE_DIR
HOST_SSH_DIR=$HOST_SSH_DIR
OPENCODE_MODEL=${OPENCODE_MODEL:-}
ENV

run_compose up -d --build "$@"
