#!/usr/bin/env bash
set -euo pipefail
mode="${1:---terminal}"
case "$mode" in
  --gui) "$(dirname "$0")/start-gui-emacs.sh" ;;
  --terminal) "$(dirname "$0")/start-terminal-emacs.sh" ;;
  *) echo "Usage: dev-emacs.sh [--terminal|--gui]"; exit 1 ;;
esac
