#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/_common.sh"

usage() {
  cat <<'USAGE'
Usage: cdev update [--check]

Check the versions of artifacts installed in the base image. By default,
outdated artifacts are updated by rebuilding the base image, followed by any
locally installed template images that depend on it.

Options:
  --check  Report available updates without building images. Exits 1 when an
           artifact or locally installed template image needs an update.
USAGE
}

check_only=0
case "${1:-}" in
  "") ;;
  --check) check_only=1 ;;
  -h|--help) usage; exit 0 ;;
  *) usage >&2; exit 2 ;;
esac
[[ $# -le 1 ]] || { usage >&2; exit 2; }

base_image="eoc-base-container:latest"
opencode_package="opencode-ai"
build_image_script="${EOC_BUILD_IMAGE_SCRIPT:-$TOOL_HOME/scripts/dev-build-image.sh}"
base_needs_update=0
declare -a templates_to_rebuild=()

image_exists() {
  docker image inspect "$1" >/dev/null 2>&1
}

normalize_version() {
  awk 'match($0, /[0-9]+\.[0-9]+\.[0-9]+([+-][0-9A-Za-z.-]+)?/) {
    version = substr($0, RSTART, RLENGTH)
  } END { print version }'
}

# Keep each artifact check isolated so more artifact-specific checks can be
# added here without changing the image rebuild workflow below.
check_opencode() {
  local installed latest
  if ! image_exists "$base_image"; then
    echo "OpenCode: base image is missing (update required)"
    base_needs_update=1
    return
  fi

  installed="$(docker run --rm --entrypoint opencode "$base_image" --version | normalize_version)"
  latest="$(docker run --rm --entrypoint npm "$base_image" view "$opencode_package" version | normalize_version)"
  if [[ -z "$installed" || -z "$latest" ]]; then
    echo "Error: could not determine installed and latest OpenCode versions." >&2
    exit 2
  fi

  if [[ "$installed" == "$latest" ]]; then
    echo "OpenCode: $installed (up to date)"
  else
    echo "OpenCode: $installed -> $latest (update available)"
    base_needs_update=1
    OPENCODE_LATEST_VERSION="$latest"
  fi
}

find_stale_templates() {
  local base_epoch image image_kind template template_epoch
  if image_exists "$base_image"; then
    base_epoch="$(image_created_epoch "$base_image")"
  else
    base_epoch=0
  fi

  while IFS= read -r template; do
    image_kind="$(basename "$template" .docker)"
    image="eoc-${image_kind}-container:latest"
    image_exists "$image" || continue
    template_epoch="$(image_created_epoch "$image")"
    if (( base_needs_update || template_epoch < base_epoch )); then
      templates_to_rebuild+=("$image_kind")
      echo "Template $image_kind: rebuild required"
    fi
  done < <(find "$TOOL_HOME/docker-templates" -maxdepth 1 -type f -name '*.docker' -print | sort)
}

check_opencode
find_stale_templates

if (( check_only )); then
  if (( base_needs_update || ${#templates_to_rebuild[@]} )); then
    exit 1
  fi
  exit 0
fi

if (( base_needs_update )); then
  build_args=(base --no-cache)
  if [[ -n "${OPENCODE_LATEST_VERSION:-}" ]]; then
    build_args+=(--build-arg "OPENCODE_NPM_PACKAGE=${opencode_package}@${OPENCODE_LATEST_VERSION}")
  fi
  "$build_image_script" "${build_args[@]}"
fi

for image_kind in "${templates_to_rebuild[@]}"; do
  "$build_image_script" "$image_kind"
done

if (( base_needs_update == 0 && ${#templates_to_rebuild[@]} == 0 )); then
  echo "All checked artifacts and images are up to date."
fi
