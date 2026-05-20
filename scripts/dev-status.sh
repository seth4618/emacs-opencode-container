#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/_common.sh"
load_context
echo "REPO_ROOT=$REPO_ROOT"
echo "PROJECT_DOTDIR=$PROJECT_DOTDIR"
echo "PROJECT_ENV_FILE=$PROJECT_ENV_FILE"
echo "PROJECT_RUNTIME_DIR=$PROJECT_RUNTIME_DIR"
if [[ -f "$PROJECT_ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$PROJECT_ENV_FILE"
fi
echo "HOST_REPO_PATH=${HOST_REPO_PATH:-}"
echo "WORKSPACE_DIRNAME=${WORKSPACE_DIRNAME:-}"
echo "HOST_COMMON_HOME=${HOST_COMMON_HOME:-}"
run_compose ps

if [[ -f "$PROJECT_RUNTIME_DIR/compose.env" ]]; then
  echo "EFFECTIVE_OPENCODE_MODEL=$(grep -E '^OPENCODE_MODEL=' "$PROJECT_RUNTIME_DIR/compose.env" | tail -n1 | cut -d= -f2-)"
fi
