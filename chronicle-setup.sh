#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------------------------------------
# chronicle-setup — generate a Discourse user API key for use inside OMP
#
# Usage:
#   chronicle-setup <discourse-site-url>
#
# Runs generate-user-api-key inside a temporary container (interactive TTY).
# Saves the key to $OMP_HOME_MOUNT_PATH/mcp-keys/discourse-mcp-key.json,
# which is mounted into every sandbox session as /home/bun/.omp/mcp-keys/.
#
# Required env var:
#   OMP_HOME_MOUNT_PATH   Set by install.sh — the persistent OMP home dir
# ---------------------------------------------------------------------------

SITE_URL="${1:-}"

if [ -z "$SITE_URL" ]; then
  echo "Usage: chronicle-setup <discourse-site-url>"
  echo ""
  echo "  ./chronicle-setup.sh https://community.example.com"
  exit 1
fi

# Strip trailing slash
SITE_URL="${SITE_URL%/}"

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
  echo "Start Docker Desktop and try again."
  exit 1
fi

mkdir -p "$OMP_HOME_MOUNT_PATH/mcp-keys"
OMP_HOME_ABS="$(cd "$OMP_HOME_MOUNT_PATH" && pwd)"

echo "=== Chronicle (Discourse) Setup ==="
echo ""
echo "Site: $SITE_URL"
echo ""
echo "A URL will be printed below. Open it in your browser, approve the app,"
echo "then paste the encrypted payload back here."
echo ""

docker run --rm -it \
  --mount "type=volume,src=omp-sandbox-bun,dst=/home/bun/.bun" \
  --mount "type=bind,src=${OMP_HOME_ABS},dst=/home/bun/.omp" \
  omp-sandbox \
  npx --yes @discourse/mcp@latest generate-user-api-key \
    --site "$SITE_URL" \
    --save-to /home/bun/.omp/mcp-keys/discourse-mcp-key.json

echo ""
echo "=== Key saved. Now connect OMP to Discourse ==="
echo ""
echo "Start a sandbox session and run this inside OMP:"
echo ""
echo "  /mcp add discourse --scope user -- npx -y @discourse/mcp@latest --allow_writes --read_only=false --site \"$SITE_URL\" --profile /home/bun/.omp/mcp-keys/discourse-mcp-key.json"
echo ""
echo "Then verify:"
echo "  /mcp list"
echo "  /mcp test discourse"
