#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

TARGET_HOME="$tmpdir/common-home"
"$REPO_ROOT/scripts/setup-common-home.sh" "$TARGET_HOME" "/workspace/test-repo" >/dev/null

assert_link() {
  local path="$1"
  local expected="$2"
  if [[ ! -L "$path" ]]; then
    echo "FAIL: expected symlink at $path" >&2
    exit 1
  fi
  local got
  got="$(readlink "$path")"
  if [[ "$got" != "$expected" ]]; then
    echo "FAIL: $path -> $got (expected $expected)" >&2
    exit 1
  fi
}


assert_file_equals() {
  local path="$1"
  local expected="$2"
  if [[ ! -f "$path" ]]; then
    echo "FAIL: expected regular file at $path" >&2
    exit 1
  fi
  if ! cmp -s "$path" "$expected"; then
    echo "FAIL: $path does not match $expected" >&2
    exit 1
  fi
}

assert_file_equals "$TARGET_HOME/.bashrc" "$REPO_ROOT/home-template/.bashrc"
assert_file_equals "$TARGET_HOME/.emacs.d/init.el" "$REPO_ROOT/home-template/.emacs.d/init.el"
assert_file_equals "$TARGET_HOME/.emacs.d/early-init.el" "$REPO_ROOT/home-template/.emacs.d/early-init.el"
assert_link "$TARGET_HOME/.emacs.d/repo-emacs.d" "/workspace/test-repo/emacs.d"

printf 'PASS: common home bootstrap links are correct\n'
