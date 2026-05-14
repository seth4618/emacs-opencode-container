# Common shell initialization for emacs-opencode-container.
# This file is intended to be symlinked into a user-managed common home.

# Keep interactive shell prompt concise in this environment.
if [[ $- == *i* ]]; then
  PS1="${PS1:-\\u@\\h:\\w\\$ }"
fi

# Local per-user overrides (not tracked in repo).
if [[ -f "$HOME/.bashrc.local" ]]; then
  # shellcheck disable=SC1090
  source "$HOME/.bashrc.local"
fi
