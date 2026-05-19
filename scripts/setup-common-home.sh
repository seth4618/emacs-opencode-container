#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TEMPLATE_ROOT="$REPO_ROOT/home-template"
TARGET_HOME="${1:-${OPENCODE_COMMON_HOME:-$HOME/.opencode-common-home}}"
CONTAINER_REPO_ROOT="${CONTAINER_REPO_ROOT:-${2:-${HOST_REPO_PATH:-}}}"

usage() {
  cat <<USAGE
Usage: scripts/setup-common-home.sh [TARGET_HOME] [CONTAINER_REPO_ROOT]

Creates a common home directory from repo-managed templates.

Arguments:
  TARGET_HOME          Optional destination path.
                       Default: \$OPENCODE_COMMON_HOME or \$HOME/.opencode-common-home
  CONTAINER_REPO_ROOT  Optional in-container repo path for .emacs.d/repo-emacs.d.
                       Default: \$CONTAINER_REPO_ROOT or \$HOST_REPO_PATH
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

install_file() {
  local src="$1"
  local dst="$2"
  install -m 0644 "$src" "$dst"
  echo "install: $dst"
}


ensure_local_file() {
  local path="$1"
  if [[ ! -e "$path" ]]; then
    : > "$path"
    chmod 0644 "$path"
    echo "create: $path"
  fi
}

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

install_file "$TEMPLATE_ROOT/.bashrc" "$TARGET_HOME/.bashrc"
install_file "$TEMPLATE_ROOT/.emacs.d/init.el" "$TARGET_HOME/.emacs.d/init.el"
install_file "$TEMPLATE_ROOT/.emacs.d/early-init.el" "$TARGET_HOME/.emacs.d/early-init.el"

ensure_local_file "$TARGET_HOME/.bashrc.local"
ensure_local_file "$TARGET_HOME/.emacs.d/init.local.el"
ensure_local_file "$TARGET_HOME/.emacs.d/early-init.local.el"

repo_emacs_target="${CONTAINER_REPO_ROOT:-$REPO_ROOT}/emacs.d"
link_item "$repo_emacs_target" "$TARGET_HOME/.emacs.d/repo-emacs.d"

echo ""
echo "Common home ready at: $TARGET_HOME"
echo "repo-emacs.d points to: $repo_emacs_target"
echo "You can add personal overrides in:"
echo "  $TARGET_HOME/.bashrc.local"
echo "  $TARGET_HOME/.emacs.d/init.local.el"
echo "  $TARGET_HOME/.emacs.d/early-init.local.el"
