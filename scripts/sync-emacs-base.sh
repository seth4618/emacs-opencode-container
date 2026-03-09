#!/usr/bin/env bash
set -euo pipefail

if [[ ! -d /opt/emacs-base ]]; then
  exit 0
fi

mkdir -p "${HOME}/.emacs.d/local-init.d"

# Keep tracked base config files in sync with repo updates while preserving
# package/state directories in the persistent emacs volume.
install -m 0644 /opt/emacs-base/early-init.el "${HOME}/.emacs.d/early-init.el"
install -m 0644 /opt/emacs-base/init.el "${HOME}/.emacs.d/init.el"

if [[ -d /opt/emacs-base/local-init.d ]]; then
  rsync -a --delete /opt/emacs-base/local-init.d/ "${HOME}/.emacs.d/local-init.d/"
fi
