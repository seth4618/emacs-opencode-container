#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/_common.sh"

load_context

missing_init_files=()
[[ -f "$PROJECT_ENV_FILE" ]] || missing_init_files+=("$PROJECT_ENV_FILE")
[[ -f "$PROJECT_DOTDIR/Dockerfile" ]] || missing_init_files+=("$PROJECT_DOTDIR/Dockerfile")
[[ -f "$PROJECT_DOTDIR/.gitignore" ]] || missing_init_files+=("$PROJECT_DOTDIR/.gitignore")
[[ -f "$PROJECT_DOTDIR/opencode.env.template" ]] || missing_init_files+=("$PROJECT_DOTDIR/opencode.env.template")
if (( ${#missing_init_files[@]} > 0 )); then
  echo "dev-up.sh requires initialized dev-container files." >&2
  echo "Missing:" >&2
  printf '  %s\n' "${missing_init_files[@]}" >&2
  echo "Run: scripts/dev-init.sh <base|coding|latex|everything|middle>" >&2
  exit 1
fi

echo "Syncing elisp helpers..."
if ! "$(dirname "$0")/sync-elisp-helpers.sh"; then
  echo "sync-elisp-helpers.sh failed; aborting dev-up." >&2
  exit 1
fi

# shellcheck disable=SC1090
source "$PROJECT_ENV_FILE"

SECRETS_LIST_FILE="${SECRETS_PATHS_FILE:-$REPO_ROOT/secrets-paths.txt}"

: "${HOST_REPO_PATH:=$REPO_ROOT}"
HOST_GIT_COMMON_DIR="${HOST_GIT_COMMON_DIR:-$(resolve_git_common_dir "$HOST_REPO_PATH")}"
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

# Keep OpenCode auth in one canonical shared location so host and container use
# the same OAuth tokens.
PROJECT_OPENCODE_AUTH_LINK_DIR="$PROJECT_OPENCODE_STATE_DIR/opencode"
PROJECT_OPENCODE_AUTH_LINK="$PROJECT_OPENCODE_AUTH_LINK_DIR/auth.json"
mkdir -p "$PROJECT_OPENCODE_AUTH_LINK_DIR"
rm -f "$PROJECT_OPENCODE_AUTH_LINK"
ln -s /opencode-share/auth.json "$PROJECT_OPENCODE_AUTH_LINK"

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
        target="$PROJECT_RUNTIME_DIR/secrets/$(printf '%03d' "$i")-$(basename "$path")"
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
HOST_GIT_COMMON_DIR=$HOST_GIT_COMMON_DIR
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
