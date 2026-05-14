#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TEMPLATE_ROOT="$REPO_ROOT/home-template"
TARGET_HOME="${1:-${OPENCODE_COMMON_HOME:-$HOME/.opencode-common-home}}"

usage() {
  cat <<USAGE
Usage: scripts/setup-common-home.sh [TARGET_HOME]

Creates a common home directory and symlinks repo-managed template files.

Arguments:
  TARGET_HOME   Optional destination path.
                Default: \$OPENCODE_COMMON_HOME or \$HOME/.opencode-common-home
USAGE
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ ! -d "$TEMPLATE_ROOT" ]]; then
  echo "Template root not found: $TEMPLATE_ROOT" >&2
  exit 1
fi

mkdir -p "$TARGET_HOME/.emacs.d"

link_item() {
  local src="$1"
  local dst="$2"

  if [[ -L "$dst" ]]; then
    local existing_target
    existing_target="$(readlink "$dst")"
    if [[ "$existing_target" == "$src" ]]; then
      echo "ok: $dst -> $src"
      return
    fi
    rm -f "$dst"
  elif [[ -e "$dst" ]]; then
    local backup="${dst}.pre-opencode.$(date +%Y%m%d%H%M%S)"
    mv "$dst" "$backup"
    echo "backup: $dst -> $backup"
  fi

  ln -s "$src" "$dst"
  echo "link: $dst -> $src"
}

link_item "$TEMPLATE_ROOT/.bashrc" "$TARGET_HOME/.bashrc"
link_item "$TEMPLATE_ROOT/.emacs.d/init.el" "$TARGET_HOME/.emacs.d/init.el"
link_item "$TEMPLATE_ROOT/.emacs.d/early-init.el" "$TARGET_HOME/.emacs.d/early-init.el"
link_item "$REPO_ROOT/emacs.d" "$TARGET_HOME/.emacs.d/repo-emacs.d"

echo ""
echo "Common home ready at: $TARGET_HOME"
echo "You can add personal overrides in:"
echo "  $TARGET_HOME/.bashrc.local"
echo "  $TARGET_HOME/.emacs.d/init.local.el"
echo "  $TARGET_HOME/.emacs.d/early-init.local.el"
