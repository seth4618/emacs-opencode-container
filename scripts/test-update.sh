#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

cat > "$TMP_DIR/docker" <<'DOCKER'
#!/usr/bin/env bash
set -euo pipefail
if [[ "$1 $2" == "image inspect" ]]; then
  case "$3" in
    eoc-base-container:latest)
      [[ "${4:-}" == "--format" ]] && echo "${BASE_CREATED:-2026-01-02T00:00:00Z}"
      exit 0
      ;;
    eoc-coding-container:latest)
      [[ "${4:-}" == "--format" ]] && echo "${CODING_CREATED:-2026-01-01T00:00:00Z}"
      exit 0
      ;;
    *) exit 1 ;;
  esac
fi
if [[ "$1 $2 $3 $4" == "run --rm --entrypoint opencode" ]]; then
  echo "opencode version ${INSTALLED_VERSION:-1.0.0}"
  exit 0
fi
if [[ "$1 $2 $3 $4" == "run --rm --entrypoint npm" ]]; then
  echo "${LATEST_VERSION:-1.1.0}"
  exit 0
fi
exit 2
DOCKER
chmod +x "$TMP_DIR/docker"

cat > "$TMP_DIR/build-image" <<'BUILD'
#!/usr/bin/env bash
printf '<%s>\n' "$@" >> "$BUILD_LOG"
BUILD
chmod +x "$TMP_DIR/build-image"

export PATH="$TMP_DIR:$PATH"
export BUILD_LOG="$TMP_DIR/build.log"
export EOC_BUILD_IMAGE_SCRIPT="$TMP_DIR/build-image"

if "$SCRIPT_DIR/dev-update.sh" --check >"$TMP_DIR/check.out"; then
  echo "outdated check unexpectedly succeeded" >&2
  exit 1
else
  status=$?
fi
[[ "$status" -eq 1 ]]
grep -q 'OpenCode: 1.0.0 -> 1.1.0 (update available)' "$TMP_DIR/check.out"
grep -q 'Template coding: rebuild required' "$TMP_DIR/check.out"
[[ ! -e "$BUILD_LOG" ]]

"$SCRIPT_DIR/dev-update.sh" >"$TMP_DIR/update.out"
expected=$'<base>\n<--no-cache>\n<--build-arg>\n<OPENCODE_NPM_PACKAGE=opencode-ai@1.1.0>\n<coding>'
[[ "$(cat "$BUILD_LOG")" == "$expected" ]]

: > "$BUILD_LOG"
INSTALLED_VERSION=1.1.0 CODING_CREATED=2026-01-03T00:00:00Z \
  "$SCRIPT_DIR/dev-update.sh" --check >"$TMP_DIR/current.out"
grep -q 'OpenCode: 1.1.0 (up to date)' "$TMP_DIR/current.out"
[[ ! -s "$BUILD_LOG" ]]

echo "PASS: artifact updates check versions and rebuild dependent local images"
