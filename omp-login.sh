#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------------------------------------
# omp-login — start an OMP session with OAuth callback port bridged to host
#
# Usage:
#   omp-login [provider]
#
# OMP's OAuth callback server binds to 127.0.0.1:<port> inside the container.
# Docker port publishing can only reach 0.0.0.0, not loopback. This script
# runs socat inside the container to bridge 0.0.0.0:<port+1> → 127.0.0.1:<port>,
# then publishes <port>:<port+1> so the host browser's redirect hits OMP.
#
# After the container starts, run /login <provider> inside OMP.
#
# Provider → OMP preferred OAuth callback port (from OMP source):
#   anthropic       54545
#   openai-codex    1455
#   gemini-cli      8085
#   antigravity     51121
#   gitlab          8080
#   devin           59653
#
# Required env var:
#   OMP_HOME_MOUNT_PATH   Set by install.sh — the persistent OMP home dir
# ---------------------------------------------------------------------------

PROVIDER="${1:-anthropic}"

case "$PROVIDER" in
  anthropic)                PORT=54545 ;;
  openai-codex|codex)       PORT=1455 ;;
  gemini-cli|gemini)        PORT=8085 ;;
  antigravity)              PORT=51121 ;;
  gitlab)                   PORT=8080 ;;
  devin)                    PORT=59653 ;;
  *)
    echo "Unknown provider: $PROVIDER"
    echo ""
    echo "Known providers: anthropic, openai-codex, gemini-cli, antigravity, gitlab, devin"
    exit 1 ;;
esac

# socat listens on a distinct port to avoid conflicting with OMP's bind
SOCAT_PORT=$((PORT + 1))

if [ -z "${OMP_HOME_MOUNT_PATH:-}" ]; then
  echo "Error: OMP_HOME_MOUNT_PATH is not set."
  echo "Run ./install.sh first, then reload your shell."
  exit 1
fi

if ! command -v docker &>/dev/null; then
  echo "Error: Docker not found in PATH."
  exit 1
fi

if ! docker info &>/dev/null; then
  echo "Error: Docker daemon is not running."
  exit 1
fi

mkdir -p "$OMP_HOME_MOUNT_PATH"
OMP_HOME_ABS="$(cd "$OMP_HOME_MOUNT_PATH" && pwd)"

echo "Provider: $PROVIDER"
echo "OMP callback port: $PORT (host browser → localhost:${PORT} → container socat:${SOCAT_PORT} → OMP:${PORT})"
echo ""
echo "Inside OMP, run: /login $PROVIDER"
echo "Approve in your browser — the callback will reach OMP directly, no paste needed."
echo ""

docker run --rm -it \
  --name "omp-login-${PROVIDER}-$$" \
  --mount "type=volume,src=omp-sandbox-bun,dst=/home/bun/.bun" \
  --mount "type=bind,src=${OMP_HOME_ABS},dst=/home/bun/.omp" \
  --security-opt=no-new-privileges \
  --cap-drop=ALL \
  -p "${PORT}:${SOCAT_PORT}" \
  -e "TERM=${TERM:-xterm-256color}" \
  -e "COLORTERM=${COLORTERM:-truecolor}" \
  -e FORCE_COLOR=1 \
  -e "ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY:-}" \
  -e "OPENAI_API_KEY=${OPENAI_API_KEY:-}" \
  -e "GOOGLE_API_KEY=${GOOGLE_API_KEY:-}" \
  omp-sandbox \
  bash -c "socat TCP-LISTEN:${SOCAT_PORT},fork,reuseaddr TCP:127.0.0.1:${PORT} & exec omp"
