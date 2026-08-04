#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLKIT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

fakebin="$tmpdir/bin"
docker_state="$tmpdir/docker-state"
docker_log="$tmpdir/docker.log"
mkdir -p "$fakebin"
printf 'running\n' > "$docker_state"
cat > "$fakebin/docker" <<'DOCKER'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "$FAKE_DOCKER_LOG"

if [[ "$1" == "inspect" ]]; then
  printf 'sha256:test-image\n'
  exit 0
fi

if [[ "$1" != "compose" ]]; then
  echo "unexpected docker invocation: $*" >&2
  exit 1
fi

command=""
for arg in "$@"; do
  case "$arg" in
    ps|start|stop) command="$arg"; break ;;
  esac
done

case "$command" in
  ps)
    if [[ " $* " == *" --all "* ]] || [[ "$(cat "$FAKE_DOCKER_STATE")" == "running" ]]; then
      printf 'test-container-id\n'
    fi
    ;;
  start) printf 'running\n' > "$FAKE_DOCKER_STATE" ;;
  stop) printf 'stopped\n' > "$FAKE_DOCKER_STATE" ;;
  *) echo "unexpected docker compose invocation: $*" >&2; exit 1 ;;
esac
DOCKER
chmod +x "$fakebin/docker"

target_repo="$tmpdir/project"
mkdir -p "$target_repo/.devcontainer/.runtime"
git -C "$target_repo" init -q
cat > "$target_repo/.devcontainer/.env" <<ENV
HOST_REPO_PATH=$target_repo
COMPOSE_PROJECT_NAME=test-stop-resume
ENV
cat > "$target_repo/.devcontainer/Dockerfile" <<'DOCKERFILE'
FROM eoc-base-container:latest
DOCKERFILE
cat > "$target_repo/.devcontainer/compose.override.yml" <<'COMPOSE'
services:
  dev:
    ports:
      - "127.0.0.1:3000:3000"
COMPOSE
cat > "$target_repo/.devcontainer/.runtime/compose.env" <<ENV
HOST_REPO_PATH=$target_repo
ENV

export PATH="$fakebin:$PATH"
export DEV_REPO_ROOT="$target_repo"
export FAKE_DOCKER_STATE="$docker_state"
export FAKE_DOCKER_LOG="$docker_log"

# shellcheck source=_common.sh
source "$TOOLKIT_ROOT/scripts/_common.sh"
record_container_baseline
grep -Fq -- "-f $target_repo/.devcontainer/compose.override.yml" "$docker_log"

"$TOOLKIT_ROOT/scripts/dev-stop.sh" > "$tmpdir/stop.out"
[[ "$(cat "$docker_state")" == "stopped" ]]
grep -Fq 'stopped without removing it' "$tmpdir/stop.out"

"$TOOLKIT_ROOT/scripts/dev-resume.sh" > "$tmpdir/resume.out" 2> "$tmpdir/resume.err"
[[ "$(cat "$docker_state")" == "running" ]]
grep -Fq 'without rebuilding it' "$tmpdir/resume.out"
[[ ! -s "$tmpdir/resume.err" ]]

"$TOOLKIT_ROOT/scripts/dev-stop.sh" >/dev/null
printf '# changed\n' >> "$target_repo/.devcontainer/compose.override.yml"
"$TOOLKIT_ROOT/scripts/dev-resume.sh" > "$tmpdir/drift.out" 2> "$tmpdir/drift.err"
grep -Fq 'inputs have changed' "$tmpdir/drift.err"
[[ "$(cat "$docker_state")" == "running" ]]

printf 'PASS: dev-stop preserves and dev-resume restarts containers with drift warnings\n'
