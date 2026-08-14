#!/usr/bin/env bash
TOOL_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPOSE_CMD=(docker compose)
SERVICE_NAME="dev"

resolve_repo_root() {
  if [[ -n "${DEV_REPO_ROOT:-}" ]]; then
    echo "$DEV_REPO_ROOT"
    return
  fi
  git rev-parse --show-toplevel 2>/dev/null || {
    echo "Error: not inside a git repository. Run from a git worktree or set DEV_REPO_ROOT." >&2
    exit 1
  }
}

resolve_git_common_dir() {
  local repo_root="$1"
  local git_common_dir
  if git_common_dir="$(git -C "$repo_root" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)"; then
    echo "$git_common_dir"
    return
  fi
  echo "$repo_root/.git"
}

load_context() {
  REPO_ROOT="$(resolve_repo_root)"
  PROJECT_DOTDIR="$REPO_ROOT/.devcontainer"
  PROJECT_ENV_FILE="$PROJECT_DOTDIR/.env"
  PROJECT_RUNTIME_DIR="$PROJECT_DOTDIR/.runtime"
  PROJECT_COMPOSE_ENV_FILE="$PROJECT_RUNTIME_DIR/compose.env"
  PROJECT_COMPOSE_OVERRIDE_FILE="$PROJECT_DOTDIR/compose.override.yml"
  DEV_CONTAINER_STATE_FILE="$PROJECT_RUNTIME_DIR/dev-container-state"

  runtime_env_args=()
  if [[ -f "$PROJECT_ENV_FILE" ]]; then
    runtime_env_args+=(--env-file "$PROJECT_ENV_FILE")
  fi
  if [[ -f "$PROJECT_COMPOSE_ENV_FILE" ]]; then
    runtime_env_args+=(--env-file "$PROJECT_COMPOSE_ENV_FILE")
  fi
  if [[ -z "${HOST_GIT_COMMON_DIR:-}" ]] \
    && ! { [[ -f "$PROJECT_ENV_FILE" ]] && grep -Eq '^[[:space:]]*HOST_GIT_COMMON_DIR=' "$PROJECT_ENV_FILE"; } \
    && ! { [[ -f "$PROJECT_COMPOSE_ENV_FILE" ]] && grep -Eq '^[[:space:]]*HOST_GIT_COMMON_DIR=' "$PROJECT_COMPOSE_ENV_FILE"; }; then
    HOST_GIT_COMMON_DIR="$(resolve_git_common_dir "$REPO_ROOT")"
    export HOST_GIT_COMMON_DIR
  fi
}

fingerprint_path() {
  local path="$1"
  if [[ ! -e "$path" && ! -L "$path" ]]; then
    printf 'missing\0%s\0' "$path"
    return
  fi

  if [[ -d "$path" ]]; then
    printf 'directory\0%s\0' "$path"
    while IFS= read -r -d '' entry; do
      local basename relative
      basename="$(basename "$entry")"
      [[ "$basename" == .,* || "$basename" == \#scg* || "$basename" == .\#* ]] && continue
      relative="${entry#"$path"/}"
      if [[ -L "$entry" ]]; then
        printf 'link\0%s\0%s\0' "$relative" "$(readlink "$entry")"
      elif [[ -f "$entry" ]]; then
        printf 'file\0%s\0' "$relative"
        sha256sum "$entry"
      fi
    done < <(find "$path" -mindepth 1 \( -type f -o -type l \) -print0 | sort -z)
    return
  fi

  if [[ -L "$path" ]]; then
    printf 'link\0%s\0%s\0' "$path" "$(readlink "$path")"
  else
    printf 'file\0%s\0' "$path"
    sha256sum "$path"
  fi
}

container_input_fingerprint() {
  load_context
  {
    fingerprint_path "$TOOL_HOME/docker-compose.yml"
    fingerprint_path "$TOOL_HOME/Dockerfile"
    fingerprint_path "$TOOL_HOME/docker-templates"
    fingerprint_path "$PROJECT_DOTDIR/Dockerfile"
    fingerprint_path "$PROJECT_COMPOSE_OVERRIDE_FILE"
    fingerprint_path "$PROJECT_ENV_FILE"
    fingerprint_path "$PROJECT_COMPOSE_ENV_FILE"

    local secrets_list_file path
    secrets_list_file="${SECRETS_PATHS_FILE:-$REPO_ROOT/secrets-paths.txt}"
    fingerprint_path "$secrets_list_file"
    if [[ -f "$secrets_list_file" ]]; then
      while IFS= read -r path; do
        [[ -z "$path" || "$path" =~ ^# ]] && continue
        fingerprint_path "$path"
      done < "$secrets_list_file"
    fi
  } | sha256sum | cut -d' ' -f1
}

record_container_baseline() {
  load_context
  local cid image_id fingerprint tmp_file
  cid="$(run_compose ps --quiet "$SERVICE_NAME")"
  [[ -n "$cid" ]] || return 0
  image_id="$(docker inspect --format '{{.Image}}' "$cid" 2>/dev/null || true)"
  fingerprint="$(container_input_fingerprint)"
  mkdir -p "$PROJECT_RUNTIME_DIR"
  tmp_file="$(mktemp "$PROJECT_RUNTIME_DIR/dev-container-state.XXXXXX")"
  {
    printf 'baseline_fingerprint=%s\n' "$fingerprint"
    printf 'container_id=%s\n' "$cid"
    printf 'image_id=%s\n' "$image_id"
    printf 'recorded_at=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  } > "$tmp_file"
  mv "$tmp_file" "$DEV_CONTAINER_STATE_FILE"
}

run_compose() {
  load_context
  local compose_file_args=(-f "$TOOL_HOME/docker-compose.yml")
  if [[ -f "$PROJECT_COMPOSE_OVERRIDE_FILE" ]]; then
    compose_file_args+=(-f "$PROJECT_COMPOSE_OVERRIDE_FILE")
  fi
  (cd "$REPO_ROOT" && "${COMPOSE_CMD[@]}" "${compose_file_args[@]}" "${runtime_env_args[@]}" "$@")
}

image_created_epoch() {
  local image="$1" created
  created="$(docker image inspect "$image" --format '{{.Created}}' 2>/dev/null || true)"
  [[ -n "$created" ]] || return 1
  date -d "$created" +%s
}

warn_if_selected_image_stale() {
  local selected_image="$1" base_image="eoc-base-container:latest"
  local base_epoch selected_epoch source_epoch template_name template_file stale=0

  # Only toolkit-managed images have a source chain we can determine here.
  if [[ "$selected_image" != "$base_image" \
        && ! "$selected_image" =~ ^eoc-(.+)-container:latest$ ]]; then
    return
  fi

  if ! base_epoch="$(image_created_epoch "$base_image")"; then
    echo "Warning: $selected_image depends on missing image $base_image." >&2
    echo "Run: cdev build-base" >&2
    return
  fi

  source_epoch="$(stat -c %Y "$TOOL_HOME/Dockerfile")"
  if (( base_epoch < source_epoch )); then
    echo "Warning: $base_image is older than $TOOL_HOME/Dockerfile." >&2
    echo "Run: cdev build-base" >&2
    stale=1
  fi

  if [[ "$selected_image" == "$base_image" ]]; then
    return
  fi

  template_name="${selected_image#eoc-}"
  template_name="${template_name%-container:latest}"
  template_file="$TOOL_HOME/docker-templates/${template_name}.docker"
  [[ -f "$template_file" ]] || return
  if ! selected_epoch="$(image_created_epoch "$selected_image")"; then
    echo "Warning: selected image $selected_image is missing." >&2
    echo "Run: cdev build-image $template_name" >&2
    return
  fi

  source_epoch="$(stat -c %Y "$template_file")"
  if (( selected_epoch < source_epoch )); then
    echo "Warning: $selected_image is older than $template_file." >&2
    stale=1
  fi
  if (( selected_epoch < base_epoch )); then
    echo "Warning: $selected_image is older than its parent $base_image." >&2
    stale=1
  fi
  if (( stale )); then
    echo "Run: cdev build-image $template_name" >&2
  fi
}

ensure_running() {
  local cid
  cid="$(run_compose ps -q "$SERVICE_NAME")"
  if [[ -z "$cid" ]]; then
    echo "Container not running; resuming with dev-resume ..."
    "$TOOL_HOME/scripts/dev-resume.sh"
  fi
}

exec_dev() {
  ensure_running
  run_compose exec "$SERVICE_NAME" "$@"
}
