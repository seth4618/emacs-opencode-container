#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/_common.sh"

BRANCH_NAME="${1:-}"
WORKTREE_NAME="${2:-}"
ALLOW_DIRTY="${ALLOW_DIRTY:-0}"
EOC_ALLOW_CONTAINER_WORKTREE="${EOC_ALLOW_CONTAINER_WORKTREE:-0}"
WORKTREE_BASE_BRANCH="${WORKTREE_BASE_BRANCH:-main}"
ALLOW_NON_BASE_BRANCH="${ALLOW_NON_BASE_BRANCH:-0}"

usage() {
  cat <<USAGE
Usage: $0 <branch-name> [worktree-name]

Create a host-side sibling git worktree for this repo and initialize its
.devcontainer local files.

Arguments:
  branch-name    Branch to check out. Existing branches are reused; missing
                 branches are created from the current HEAD.
  worktree-name  Optional suffix for the sibling directory. Defaults to a
                 filesystem-safe version of branch-name.

Environment:
  ALLOW_DIRTY=1                  allow creating a worktree from a dirty repo
  DEV_INIT_IMAGE_KIND=<kind>     override dev-init image kind for the new tree
  EOC_ALLOW_CONTAINER_WORKTREE=1 bypass the managed-container safety check
  WORKTREE_BASE_BRANCH=<branch>  branch the host repo must be on; default: main
  ALLOW_NON_BASE_BRANCH=1        bypass the host base-branch safety check
USAGE
}

if [[ "${BRANCH_NAME:-}" == "--help" || "${BRANCH_NAME:-}" == "-h" ]]; then
  usage
  exit 0
fi

if [[ -z "$BRANCH_NAME" ]]; then
  usage >&2
  exit 1
fi

if [[ -f /.dockerenv && "$EOC_ALLOW_CONTAINER_WORKTREE" != "1" ]]; then
  cat >&2 <<'ERROR'
Error: new-worktree.sh is intended to run on the host, not inside the container.
Create sibling worktrees from the host so they are persisted outside Docker.
Set EOC_ALLOW_CONTAINER_WORKTREE=1 only for tests or intentionally mounted hosts.
ERROR
  exit 1
fi

REPO_ROOT="$(resolve_repo_root)"
REPO_NAME="$(basename "$REPO_ROOT")"
PARENT_DIR="$(dirname "$REPO_ROOT")"

sanitize_path_component() {
  local raw="$1"
  local sanitized
  sanitized="$(printf '%s' "$raw" \
    | tr '[:upper:]' '[:lower:]' \
    | sed -E 's#[^a-z0-9._-]+#-#g; s#^[.-]+##; s#[.-]+$##')"
  if [[ -z "$sanitized" ]]; then
    sanitized="worktree"
  fi
  printf '%s' "$sanitized"
}

infer_dev_init_image_kind() {
  if [[ -n "${DEV_INIT_IMAGE_KIND:-}" ]]; then
    printf '%s' "$DEV_INIT_IMAGE_KIND"
    return
  fi

  local base_image=""
  if [[ -f "$REPO_ROOT/.devcontainer/.env" ]]; then
    base_image="$(awk -F= '/^[[:space:]]*EOC_BASE_IMAGE=/ { value=$2 } END { print value }' "$REPO_ROOT/.devcontainer/.env")"
  fi
  if [[ -z "$base_image" && -f "$REPO_ROOT/.devcontainer/Dockerfile" ]]; then
    base_image="$(awk -F= '/^[[:space:]]*ARG[[:space:]]+BASE_IMAGE=/ { value=$2 } END { print value }' "$REPO_ROOT/.devcontainer/Dockerfile")"
  fi

  case "$base_image" in
    ""|"eoc-base-container:latest")
      printf 'base'
      ;;
    eoc-*-container:latest)
      base_image="${base_image#eoc-}"
      base_image="${base_image%-container:latest}"
      printf '%s' "$base_image"
      ;;
    *)
      echo "Error: cannot infer dev-init image kind from base image: $base_image" >&2
      echo "Set DEV_INIT_IMAGE_KIND=<base|template-name> and retry." >&2
      exit 1
      ;;
  esac
}

current_branch="$(git -C "$REPO_ROOT" symbolic-ref --quiet --short HEAD || true)"
if [[ "$ALLOW_NON_BASE_BRANCH" != "1" && "$current_branch" != "$WORKTREE_BASE_BRANCH" ]]; then
  cat >&2 <<ERROR
Error: new-worktree.sh should be run from the host repo on '$WORKTREE_BASE_BRANCH'.
Current branch: ${current_branch:-detached HEAD}

Switch first:
  git -C "$REPO_ROOT" switch "$WORKTREE_BASE_BRANCH"

Or set WORKTREE_BASE_BRANCH=<branch> for repos that do not use main, or
ALLOW_NON_BASE_BRANCH=1 if you intentionally want to create from this checkout.
ERROR
  exit 1
fi

if [[ "$ALLOW_DIRTY" != "1" && -n "$(git -C "$REPO_ROOT" status --porcelain)" ]]; then
  echo "Workspace is dirty. Commit/stash or re-run with ALLOW_DIRTY=1." >&2
  exit 1
fi

suffix="$(sanitize_path_component "${WORKTREE_NAME:-$BRANCH_NAME}")"
target_base="$PARENT_DIR/$REPO_NAME-$suffix"
target_dir="$target_base"
counter=2
while [[ -e "$target_dir" ]]; do
  target_dir="${target_base}-${counter}"
  counter=$((counter + 1))
done

image_kind="$(infer_dev_init_image_kind)"

if git -C "$REPO_ROOT" show-ref --verify --quiet "refs/heads/$BRANCH_NAME"; then
  git -C "$REPO_ROOT" worktree add "$target_dir" "$BRANCH_NAME"
else
  if [[ "$ALLOW_NON_BASE_BRANCH" == "1" ]]; then
    git -C "$REPO_ROOT" worktree add -b "$BRANCH_NAME" "$target_dir"
  else
    git -C "$REPO_ROOT" worktree add -b "$BRANCH_NAME" "$target_dir" "$WORKTREE_BASE_BRANCH"
  fi
fi

DEV_REPO_ROOT="$target_dir" "$TOOL_HOME/scripts/dev-init.sh" "$image_kind"

cat <<DONE
Created worktree:
  Branch: $BRANCH_NAME
  Path:   $target_dir
  Image:  $image_kind

Next steps:
  cd "$target_dir"
  scripts/dev-up.sh
DONE
