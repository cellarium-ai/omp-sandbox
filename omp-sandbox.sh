#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------------------------------------
# omp-sandbox — launch an OMP session inside a Docker sandbox
#
# Usage:
#   omp-sandbox <dir>           Mount <dir>, open OMP there
#   omp-sandbox <dir> <subdir>  Mount <dir>, open OMP in <dir>/<subdir>
#
# Required env var:
#   OMP_HOME_MOUNT_PATH   Host path to the persistent OMP home directory
# ---------------------------------------------------------------------------

ARG1="${1:-}"
ARG2="${2:-}"

if [ -z "$ARG1" ]; then
  echo "Usage: omp-sandbox <dir> [subdir]"
  echo ""
  echo "  omp-sandbox /path/to/myproject"
  echo "      Mount myproject at /workspace/project and open OMP there."
  echo ""
  echo "  omp-sandbox /path/to/projects myproject"
  echo "      Mount projects dir at /workspace/projects and open OMP in"
  echo "      /workspace/projects/myproject."
  exit 1
fi

DOCKER_OMP_HOME="${OMP_HOME_MOUNT_PATH:-}"
if [ -z "$DOCKER_OMP_HOME" ]; then
  echo "Error: OMP_HOME_MOUNT_PATH is not set."
  echo ""
  echo "Add this to your ~/.zshrc or ~/.bashrc and reload:"
  echo '  export OMP_HOME_MOUNT_PATH="$HOME/.omp-sandbox-home"'
  exit 1
fi

if [ ! -d "$ARG1" ]; then
  echo "Error: Directory not found: $ARG1"
  exit 1
fi

mkdir -p "$DOCKER_OMP_HOME"
chmod 700 "$DOCKER_OMP_HOME"

if [ -n "$ARG2" ]; then
  if [ ! -d "$ARG1/$ARG2" ]; then
    echo "Error: Subdir '$ARG2' not found inside: $ARG1"
    echo ""
    echo "Available:"
    ls -1 "$ARG1"
    exit 1
  fi
  MOUNT_SRC="$(cd "$ARG1" && pwd)"
  MOUNT_DST="/workspace/projects"
  WORKDIR="/workspace/projects/$ARG2"
  CONTAINER_LABEL="$(basename "$ARG2")"
else
  MOUNT_SRC="$(cd "$ARG1" && pwd)"
  MOUNT_DST="/workspace/project"
  WORKDIR="/workspace/project"
  CONTAINER_LABEL="$(basename "$ARG1")"
fi

OMP_HOME_ABS="$(cd "$DOCKER_OMP_HOME" && pwd)"
CONTAINER_NAME="omp-${CONTAINER_LABEL}-$$"

docker run --rm -it \
  --name "$CONTAINER_NAME" \
  --workdir "$WORKDIR" \
  --mount "type=bind,src=${MOUNT_SRC},dst=${MOUNT_DST}" \
  --mount "type=bind,src=${OMP_HOME_ABS},dst=/home/bun/.omp" \
  --mount "type=volume,src=omp-sandbox-bun,dst=/home/bun/.bun" \
  --security-opt=no-new-privileges \
  --cap-drop=ALL \
  --pids-limit=2048 \
  --memory=16g \
  --cpus=6 \
  -e "TERM=${TERM:-xterm-256color}" \
  -e "COLORTERM=${COLORTERM:-truecolor}" \
  -e FORCE_COLOR=1 \
  -e "OPENAI_API_KEY=${OPENAI_API_KEY:-}" \
  -e "ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY:-}" \
  -e "GOOGLE_API_KEY=${GOOGLE_API_KEY:-}" \
  omp-sandbox \
  omp
