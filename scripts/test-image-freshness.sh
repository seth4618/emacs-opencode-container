#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

cat > "$TMP_DIR/docker" <<'DOCKER'
#!/usr/bin/env bash
if [[ "$1 $2 $4" != "image inspect --format" ]]; then
  exit 1
fi
case "$3" in
  eoc-base-container:latest) echo "${BASE_CREATED:-2099-01-01T00:00:00Z}" ;;
  eoc-coding-container:latest) echo "${TEMPLATE_CREATED:-2000-01-01T00:00:00Z}" ;;
  *) exit 1 ;;
esac
DOCKER
chmod +x "$TMP_DIR/docker"

output="$( {
  PATH="$TMP_DIR:$PATH"
  # shellcheck source=scripts/_common.sh
  source "$REPO_ROOT/scripts/_common.sh"
  warn_if_selected_image_stale "eoc-coding-container:latest"
  } 2>&1 )"

[[ "$output" == *"eoc-coding-container:latest is older than"* ]]
[[ "$output" == *"its parent eoc-base-container:latest"* ]]
[[ "$output" == *"Run: cdev build-image coding"* ]]

output="$( {
  PATH="$TMP_DIR:$PATH"
  export BASE_CREATED="2000-01-01T00:00:00Z"
  # shellcheck source=scripts/_common.sh
  source "$REPO_ROOT/scripts/_common.sh"
  warn_if_selected_image_stale "eoc-base-container:latest"
  } 2>&1 )"
[[ "$output" == *"eoc-base-container:latest is older than"* ]]
[[ "$output" == *"Run: cdev build-base"* ]]

output="$( {
  PATH="$TMP_DIR:$PATH"
  # shellcheck source=scripts/_common.sh
  source "$REPO_ROOT/scripts/_common.sh"
  warn_if_selected_image_stale "example/custom:latest"
  } 2>&1 )"
[[ -z "$output" ]]

warning_call_count="$(grep -c 'warn_if_selected_image_stale' "$REPO_ROOT/scripts/dev-up.sh")"
[[ "$warning_call_count" -eq 2 ]]

echo "PASS: stale toolkit image warnings are actionable"
