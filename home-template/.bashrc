# Common shell initialization for emacs-opencode-container.
# This file is intended to be symlinked into a user-managed common home.

# Keep interactive shell prompt concise in this environment.
if [[ $- == *i* ]]; then
  PS1="${PS1:-\\u@\\h:\\w\\$ }"
fi

# Set terminal title when supported.
if [[ $- == *i* ]] && [[ "${TERM:-}" != "dumb" ]]; then
  __container_title_project="${COMPOSE_PROJECT_NAME:-unknown}"
  printf '\033]0;Container: %s\007' "$__container_title_project"
  unset __container_title_project
fi

# Local per-user overrides (not tracked in repo).
if [[ -f "$HOME/.bashrc.local" ]]; then
  # shellcheck disable=SC1090
  source "$HOME/.bashrc.local"
fi
