#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

fakebin="$tmpdir/bin"
mkdir -p "$fakebin"
cat > "$fakebin/docker" <<'DOCKER'
#!/usr/bin/env bash
set -euo pipefail
if [[ "$1 $2 $3" == "image inspect eoc-coding-container:latest" ]]; then
  printf '2099-01-01T00:00:00Z\n'
  exit 0
fi
if [[ "$1" == "build" ]]; then
  exit 0
fi
echo "unexpected docker invocation: $*" >&2
exit 1
DOCKER
chmod +x "$fakebin/docker"

TARGET_REPO="$tmpdir/Example Repo"
mkdir -p "$TARGET_REPO"
PATH="$fakebin:$PATH" DEV_REPO_ROOT="$TARGET_REPO" "$REPO_ROOT/scripts/dev-init.sh" coding >/dev/null

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
assert_file_contains "$TARGET_REPO/.devcontainer/.env" "EOC_BASE_IMAGE=eoc-coding-container:latest"
assert_file_contains "$TARGET_REPO/.devcontainer/.gitignore" ".runtime/"
assert_file_contains "$PROJECT_DOCKERFILE" "ARG BASE_IMAGE=eoc-coding-container:latest"
assert_file_contains "$PROJECT_DOCKERFILE" "FROM \${BASE_IMAGE}"
assert_file_contains "$PROJECT_DOCKERFILE" "Required project user layer"
assert_file_contains "$TARGET_REPO/.devcontainer/opencode.env.template" "OpenCode runtime environment template"

printf '# user edit\n' >> "$PROJECT_DOCKERFILE"
PATH="$fakebin:$PATH" DEV_REPO_ROOT="$TARGET_REPO" "$REPO_ROOT/scripts/dev-init.sh" coding >/dev/null
assert_file_contains "$PROJECT_DOCKERFILE" "# user edit"

if PATH="$fakebin:$PATH" DEV_REPO_ROOT="$tmpdir/no-arg" "$REPO_ROOT/scripts/dev-init.sh" >/dev/null 2>&1; then
  echo "FAIL: dev-init without an image argument should fail" >&2
  exit 1
fi

printf 'PASS: dev-init scaffolds layered project Dockerfile without overwriting it\n'
