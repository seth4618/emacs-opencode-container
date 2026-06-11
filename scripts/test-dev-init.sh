#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

TARGET_REPO="$tmpdir/Example Repo"
mkdir -p "$TARGET_REPO"
DEV_REPO_ROOT="$TARGET_REPO" "$REPO_ROOT/scripts/dev-init.sh" >/dev/null

assert_file_contains() {
  local path="$1"
  local pattern="$2"
  if [[ ! -f "$path" ]]; then
    echo "FAIL: expected regular file at $path" >&2
    exit 1
  fi
  if ! grep -Fq "$pattern" "$path"; then
    echo "FAIL: expected $path to contain: $pattern" >&2
    exit 1
  fi
}

PROJECT_DOCKERFILE="$TARGET_REPO/.devcontainer/Dockerfile"
assert_file_contains "$TARGET_REPO/.devcontainer/.env" "COMPOSE_PROJECT_NAME=example-repo-dev"
assert_file_contains "$TARGET_REPO/.devcontainer/.gitignore" ".runtime/"
assert_file_contains "$PROJECT_DOCKERFILE" "FROM \${BASE_IMAGE}"
assert_file_contains "$PROJECT_DOCKERFILE" "Baseline language tooling and OpenCode CLI"
assert_file_contains "$PROJECT_DOCKERFILE" "LaTeX / TeX Live support"
assert_file_contains "$PROJECT_DOCKERFILE" "Required project user layer"
assert_file_contains "$TARGET_REPO/.devcontainer/opencode.env.template" "OpenCode runtime environment template"

printf '# user edit\n' >> "$PROJECT_DOCKERFILE"
DEV_REPO_ROOT="$TARGET_REPO" "$REPO_ROOT/scripts/dev-init.sh" >/dev/null
assert_file_contains "$PROJECT_DOCKERFILE" "# user edit"

printf 'PASS: dev-init scaffolds editable project Dockerfile without overwriting it\n'
