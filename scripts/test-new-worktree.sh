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
if [[ "$1 $2" == "image inspect" ]]; then
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

SOURCE_REPO="$tmpdir/my-repo"
mkdir -p "$SOURCE_REPO"
git -C "$SOURCE_REPO" init -q --initial-branch=main
git -C "$SOURCE_REPO" config user.email test@example.invalid
git -C "$SOURCE_REPO" config user.name "Test User"

cat > "$SOURCE_REPO/README.md" <<'README'
# Test repo
README
mkdir -p "$SOURCE_REPO/.devcontainer"
cat > "$SOURCE_REPO/.devcontainer/Dockerfile" <<'DOCKERFILE'
ARG BASE_IMAGE=eoc-coding-container:latest
FROM ${BASE_IMAGE}
DOCKERFILE
git -C "$SOURCE_REPO" add README.md .devcontainer/Dockerfile
git -C "$SOURCE_REPO" commit -q -m "initial"

PATH="$fakebin:$PATH" \
  DEV_REPO_ROOT="$SOURCE_REPO" \
  EOC_ALLOW_CONTAINER_WORKTREE=1 \
  "$REPO_ROOT/scripts/new-worktree.sh" feature/example >"$tmpdir/new-worktree.out"

WORKTREE="$tmpdir/my-repo-feature-example"
if [[ ! -d "$WORKTREE/.git" && ! -f "$WORKTREE/.git" ]]; then
  echo "FAIL: expected worktree at $WORKTREE" >&2
  cat "$tmpdir/new-worktree.out" >&2
  exit 1
fi

current_branch="$(git -C "$WORKTREE" branch --show-current)"
if [[ "$current_branch" != "feature/example" ]]; then
  echo "FAIL: expected feature/example branch, got $current_branch" >&2
  exit 1
fi

assert_file_contains "$WORKTREE/.devcontainer/.env" "HOST_REPO_PATH=$WORKTREE"
assert_file_contains "$WORKTREE/.devcontainer/.env" "HOST_GIT_COMMON_DIR=$SOURCE_REPO/.git"
assert_file_contains "$WORKTREE/.devcontainer/.env" "COMPOSE_PROJECT_NAME=my-repo-feature-example-dev"
assert_file_contains "$WORKTREE/.devcontainer/.env" "EOC_BASE_IMAGE=eoc-coding-container:latest"
assert_file_contains "$WORKTREE/.devcontainer/Dockerfile" "ARG BASE_IMAGE=eoc-coding-container:latest"

git -C "$SOURCE_REPO" branch existing/example

PATH="$fakebin:$PATH" \
  DEV_REPO_ROOT="$SOURCE_REPO" \
  EOC_ALLOW_CONTAINER_WORKTREE=1 \
  "$REPO_ROOT/scripts/new-worktree.sh" existing/example custom >"$tmpdir/new-worktree-existing.out"

SECOND_WORKTREE="$tmpdir/my-repo-custom"
if [[ "$(git -C "$SECOND_WORKTREE" branch --show-current)" != "existing/example" ]]; then
  echo "FAIL: expected existing existing/example branch in second worktree" >&2
  exit 1
fi

git -C "$SOURCE_REPO" switch -q -c side/not-main
if PATH="$fakebin:$PATH" \
  DEV_REPO_ROOT="$SOURCE_REPO" \
  EOC_ALLOW_CONTAINER_WORKTREE=1 \
  "$REPO_ROOT/scripts/new-worktree.sh" feature/should-fail >"$tmpdir/new-worktree-non-main.out" 2>&1; then
  echo "FAIL: expected new-worktree to reject non-main source branch" >&2
  exit 1
fi
assert_file_contains "$tmpdir/new-worktree-non-main.out" "should be run from the host repo on 'main'"

printf 'PASS: new-worktree creates host-side sibling worktrees and initializes devcontainer files\n'
