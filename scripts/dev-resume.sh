#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/_common.sh"

load_context
if [[ -n "$(run_compose ps --quiet "$SERVICE_NAME")" ]]; then
  echo "Dev container is already running."
  exit 0
fi

cid="$(run_compose ps --all --quiet "$SERVICE_NAME")"
if [[ -z "$cid" ]]; then
  echo "No existing dev container; starting with dev-up ..."
  "$TOOL_HOME/scripts/dev-up.sh" "$@"
  exit 0
fi

baseline_fingerprint=""
if [[ -f "$DEV_CONTAINER_STATE_FILE" ]]; then
  baseline_fingerprint="$(grep -E '^baseline_fingerprint=' "$DEV_CONTAINER_STATE_FILE" | tail -n1 | cut -d= -f2- || true)"
fi
current_fingerprint="$(container_input_fingerprint)"
if [[ -z "$baseline_fingerprint" ]]; then
  cat >&2 <<'WARNING'
WARNING: No dev-up configuration baseline was found for this container.
The existing container will be resumed, but run dev-up.sh to rebuild it if its
Dockerfile, Compose settings, environment, templates, or secrets may be stale.
WARNING
elif [[ "$baseline_fingerprint" != "$current_fingerprint" ]]; then
  cat >&2 <<'WARNING'
WARNING: Container inputs have changed since the last successful dev-up.sh.
The existing container will still be resumed. To apply Dockerfile, Compose,
environment, template, or secret changes, run dev-stop.sh and then dev-up.sh.
WARNING
fi

run_compose start "$SERVICE_NAME"
echo "Resumed the existing dev container without rebuilding it."
