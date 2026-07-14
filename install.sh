#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_PATH="$REPO_DIR/omp-sandbox.sh"

echo "=== OMP Sandbox Installer ==="
echo ""

# Check Docker is installed
if ! command -v docker &>/dev/null; then
  echo "Error: Docker not found in PATH."
  echo "Install Docker Desktop: https://www.docker.com/products/docker-desktop/"
  exit 1
fi

# Check Docker daemon is running
if ! docker info &>/dev/null; then
  echo "Error: Docker daemon is not running."
  echo "Start Docker Desktop and run this script again."
  exit 1
fi
echo "Docker: OK"
echo ""

# Prompt for OMP home directory
DEFAULT_OMP_HOME="$HOME/.omp-sandbox-home"
echo "OMP stores persistent data (memory, sessions, MCP config, login state)"
echo "in a directory on your host, mounted as /home/bun/.omp in every container."
echo "Do NOT use your real ~/.omp — keep it separate."
echo ""
printf "OMP home directory [%s]: " "$DEFAULT_OMP_HOME"
read -r OMP_HOME_INPUT || OMP_HOME_INPUT=""
OMP_HOME_INPUT="${OMP_HOME_INPUT:-$DEFAULT_OMP_HOME}"
# Expand leading ~ to $HOME (read does not perform tilde expansion)
OMP_HOME_INPUT="${OMP_HOME_INPUT/#\~/$HOME}"
mkdir -p "$OMP_HOME_INPUT"
chmod 700 "$OMP_HOME_INPUT"
echo "Using: $OMP_HOME_INPUT"
echo ""

echo "[1/3] Building Docker image (omp-sandbox)..."
docker build -t omp-sandbox "$REPO_DIR"
echo "Done."
echo ""

echo "[2/3] Making launcher executable..."
chmod +x "$SCRIPT_PATH"
echo "Done."
echo ""

SHELL_BLOCK="
# >>> OMP Sandbox >>>
export OMP_HOME_MOUNT_PATH=\"${OMP_HOME_INPUT}\"
alias omp-sandbox=\"${SCRIPT_PATH}\"
# <<< OMP Sandbox <<<"

echo "[3/3] Writing shell integration..."
ADDED_TO=()
for RC in "$HOME/.zshrc" "$HOME/.bashrc"; do
  if [ -f "$RC" ]; then
    if grep -qF "# >>> OMP Sandbox >>>" "$RC"; then
      # Remove existing block, then rewrite with fresh values
      sed -i.bak '/# >>> OMP Sandbox >>>/,/# <<< OMP Sandbox <<</d' "$RC"
      rm -f "$RC.bak"
      printf '%s\n' "$SHELL_BLOCK" >> "$RC"
      echo "  $RC — updated."
    else
      printf '%s\n' "$SHELL_BLOCK" >> "$RC"
      echo "  $RC — added."
    fi
    ADDED_TO+=("$RC")
  fi
done
echo ""

echo "=== Installation complete ==="
echo ""

if [ ${#ADDED_TO[@]} -gt 0 ]; then
  echo "Next steps:"
  echo ""
  echo "  1. Reload your shell:"
  echo "       source ${ADDED_TO[0]}"
  echo ""
  echo "  2. Run:"
  echo '       omp-sandbox /path/to/myproject'
  echo '       omp-sandbox /path/to/projects myproject'
else
  echo "Neither ~/.zshrc nor ~/.bashrc found."
  echo "Add the following to your shell config manually:"
  echo ""
  printf '%s\n' "$SHELL_BLOCK"
fi
