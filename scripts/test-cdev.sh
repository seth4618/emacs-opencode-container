#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

cp "$SCRIPT_DIR/cdev" "$TMP_DIR/cdev"
chmod +x "$TMP_DIR/cdev"

for command_name in init up stop resume down status shell emacs opencode bootstrap-opencode build-image build-base; do
  cat > "$TMP_DIR/dev-${command_name}.sh" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$(basename "$0")"
printf '<%s>\n' "$@"
STUB
  chmod +x "$TMP_DIR/dev-${command_name}.sh"
done

output="$($TMP_DIR/cdev emacs --gui 'argument with spaces')"
expected=$'dev-emacs.sh\n<--gui>\n<argument with spaces>'
[[ "$output" == "$expected" ]] || {
  printf 'unexpected dispatch output:\n%s\n' "$output" >&2
  exit 1
}

output="$($TMP_DIR/cdev build-image coding)"
[[ "$output" == $'dev-build-image.sh\n<coding>' ]]

$TMP_DIR/cdev help | grep -q 'Usage: cdev <command> \[arguments\]'
$TMP_DIR/cdev --help | grep -q 'Primary commands:'

if "$TMP_DIR/cdev" unknown >"$TMP_DIR/stdout" 2>"$TMP_DIR/stderr"; then
  echo 'unknown command unexpectedly succeeded' >&2
  exit 1
else
  status=$?
fi
[[ "$status" -eq 2 ]]
grep -q 'unknown command: unknown' "$TMP_DIR/stderr"

echo 'cdev dispatcher tests passed'
