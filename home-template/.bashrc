# Common shell initialization for emacs-opencode-container.
# This file is intended to be symlinked into a user-managed common home.

# Keep interactive shell prompt concise in this environment.
if [[ $- == *i* ]]; then
  PS1="${PS1:-\\u@\\h:\\w\\$ }"
fi

# Make common-home commands available without duplicating PATH entries.
case ":$PATH:" in
  *":$HOME/.local/bin:"*) ;;
  *) export PATH="$HOME/.local/bin:$PATH" ;;
esac

# Populate COMPOSE_PROJECT_NAME from devcontainer env files when missing.
if [[ -z "${COMPOSE_PROJECT_NAME:-}" ]]; then
  __container_bashrc_path="$(readlink -f "${BASH_SOURCE[0]}")"
  __container_repo_root="$(cd "$(dirname "$__container_bashrc_path")/.." && pwd)"
  for __container_env_file in     "$__container_repo_root/.devcontainer/.env"     "$PWD/.devcontainer/.env"     "$HOME/.devcontainer/.env"; do
    if [[ -f "$__container_env_file" ]]; then
      __container_compose_line="$(sed -n 's/^COMPOSE_PROJECT_NAME=//p' "$__container_env_file" | head -n 1)"
      if [[ -n "$__container_compose_line" ]]; then
        export COMPOSE_PROJECT_NAME="$__container_compose_line"
        break
      fi
    fi
  done
  unset __container_bashrc_path __container_repo_root __container_env_file __container_compose_line
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
