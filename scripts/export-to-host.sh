#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/_common.sh"

echo "No-op: project workspace is a direct bind mount to host."
echo "Any edits/commits in container are already in your host checkout."
