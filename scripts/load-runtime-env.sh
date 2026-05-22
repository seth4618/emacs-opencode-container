#!/usr/bin/env bash
set -euo pipefail

load_runtime_env() {
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

  repo_opencode_env="${PROJECT_WORKSPACE:-/workspace}/.devcontainer/opencode.env"
  common_opencode_env="$HOME/.opencode-common.env"

  if [[ -f "$common_opencode_env" ]]; then
    set -a
    # shellcheck disable=SC1090
    source "$common_opencode_env"
    set +a
  fi
  if [[ -f "$repo_opencode_env" ]]; then
    set -a
    # shellcheck disable=SC1090
    source "$repo_opencode_env"
    set +a
  fi
}
