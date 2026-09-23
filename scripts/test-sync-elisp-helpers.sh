#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

TOOL_COPY="$TMP_DIR/tool"
mkdir -p "$TOOL_COPY/scripts" "$TOOL_COPY/.devcontainer/elisp-helpers"
cp "$REPO_ROOT/scripts/_common.sh" "$REPO_ROOT/scripts/sync-elisp-helpers.sh" \
  "$TOOL_COPY/scripts/"

for helper in opencode.el claude-code-ide.el; do
  mkdir -p "$TOOL_COPY/.devcontainer/elisp-helpers/$helper/.git"
done

mkdir -p "$TMP_DIR/bin"
cat > "$TMP_DIR/bin/timeout" <<'TIMEOUT'
#!/usr/bin/env bash
exit 124
TIMEOUT
chmod +x "$TMP_DIR/bin/timeout"

output="$(PATH="$TMP_DIR/bin:$PATH" ELISP_SYNC_UPDATE=0 \
  "$TOOL_COPY/scripts/sync-elisp-helpers.sh" 2>&1)"
[[ "$output" == *"updates disabled"* ]]

output="$(PATH="$TMP_DIR/bin:$PATH" "$TOOL_COPY/scripts/sync-elisp-helpers.sh" 2>&1)"
[[ "$output" == *"using the existing checkout"* ]]

if PATH="$TMP_DIR/bin:$PATH" ELISP_SYNC_STRICT=1 \
  "$TOOL_COPY/scripts/sync-elisp-helpers.sh" >/dev/null 2>&1; then
  echo "strict helper sync unexpectedly accepted an update timeout" >&2
  exit 1
fi

rm -rf "$TOOL_COPY/.devcontainer/elisp-helpers/claude-code-ide.el"
if PATH="$TMP_DIR/bin:$PATH" "$TOOL_COPY/scripts/sync-elisp-helpers.sh" \
  >/dev/null 2>&1; then
  echo "initial helper clone unexpectedly accepted a timeout" >&2
  exit 1
fi
[[ ! -e "$TOOL_COPY/.devcontainer/elisp-helpers/claude-code-ide.el" ]]

grep -q 'ELISP_SYNC_UPDATE=0.*sync-elisp-helpers.sh' "$REPO_ROOT/scripts/dev-up.sh"

echo "PASS: elisp helper sync timeouts use existing checkouts safely"
