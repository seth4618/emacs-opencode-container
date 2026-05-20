#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/_common.sh"

REPO_ROOT="$(resolve_repo_root)"
PROJECT_ENV_FILE="$REPO_ROOT/.devcontainer/.env"

"$(dirname "$0")/dev-init.sh" >/dev/null

repo_name="$(basename "$REPO_ROOT")"
default_state_dir="$HOME/.local/share/opencode-$repo_name"
default_common_home="$HOME/.opencode-common-home-$repo_name"

tmp_file="$(mktemp)"
cp "$PROJECT_ENV_FILE" "$tmp_file"

append_if_missing() {
  local key="$1"
  local value="$2"
  if ! grep -Eq "^[[:space:]]*${key}=" "$tmp_file"; then
    printf '%s=%s\n' "$key" "$value" >> "$tmp_file"
    echo "Set ${key}=${value}"
  else
    echo "Kept existing ${key}"
  fi
}

append_if_missing "HOST_OPENCODE_DIR" "$default_state_dir"
append_if_missing "HOST_COMMON_HOME" "$default_common_home"

mv "$tmp_file" "$PROJECT_ENV_FILE"
echo "Updated: $PROJECT_ENV_FILE"
