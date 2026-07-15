# OMP Sandbox

A shareable Docker sandbox for [Oh My Pi](https://ohmypi.ai). Clone and run one command to get an isolated OMP environment with persistent state and a named volume for the OMP binary.

## Installation

```bash
git clone <repo-url> ~/omp-sandbox-repo
cd ~/omp-sandbox-repo
./install.sh
```

The installer checks Docker is installed and running, prompts for your OMP home directory (the persistent data store; defaults to `~/.omp-sandbox-home`), builds the image, and writes both `OMP_HOME_MOUNT_PATH` and the `omp-sandbox` alias directly into your shell config.

Reload: `source ~/.zshrc`.

---

## What `OMP_HOME_MOUNT_PATH` is

This directory is mounted as `/home/bun/.omp` inside every container. OMP stores memory, session history, API login state, and MCP config here. It persists across container restarts. Do **not** point it at your real `~/.omp` — keep it separate so the sandbox agent does not share state with your host OMP.

Full example `.zshrc` block written by `install.sh` (paths are expanded at install time; re-running updates the block in place):

```bash
# >>> OMP Sandbox >>>
export OMP_HOME_MOUNT_PATH="/Users/you/.omp-sandbox-home"
alias omp-sandbox="/Users/you/omp-sandbox-repo/omp-sandbox.sh"
# <<< OMP Sandbox <<<
```

---

## Copying existing MCP keys

If you already have MCP keys in `~/.omp/mcp-keys/` on the host:

```bash
mkdir -p "$OMP_HOME_MOUNT_PATH/mcp-keys"
rsync -av --delete ~/.omp/mcp-keys/ "$OMP_HOME_MOUNT_PATH/mcp-keys/"
chmod -R go-rwx "$OMP_HOME_MOUNT_PATH"
```

If `mcp.json` references absolute host paths (e.g. `~/.omp/mcp-keys/...`), change them to `/home/bun/.omp/mcp-keys/...` in the sandbox copy.

---

## API keys (Anthropic, OpenAI, Google)

No browser login needed. The launcher forwards API keys directly from your host environment:

```bash
# Add to ~/.zshrc, then: source ~/.zshrc
export ANTHROPIC_API_KEY="sk-ant-..."
export OPENAI_API_KEY="sk-..."
export GOOGLE_API_KEY="..."
```

OMP picks them up on startup. Any key that isn't set is passed as an empty string and ignored.

---

## Usage

```bash
# Single project — mounts myproject at /workspace/project
omp-sandbox /path/to/myproject

# Projects root + subdir — mounts projects at /workspace/projects, opens in myproject
omp-sandbox ~/dev/projects myproject
```

OMP opens immediately. For a bash shell instead (e.g. to debug):

```bash
docker run --rm -it \
  --mount type=volume,src=omp-sandbox-bun,dst=/home/bun/.bun \
  --mount type=bind,src="$OMP_HOME_MOUNT_PATH",dst=/home/bun/.omp \
  omp-sandbox bash
```

---

## Updating OMP

The OMP binary lives in the Docker named volume `omp-sandbox-bun`. Updates made inside a container persist across restarts.

To update inside a running session:
```bash
bun install -g @oh-my-pi/pi-coding-agent
```

To update without starting a full session:
```bash
docker run --rm \
  --mount type=volume,src=omp-sandbox-bun,dst=/home/bun/.bun \
  omp-sandbox bash -c "bun install -g @oh-my-pi/pi-coding-agent"
```

To reset to the version baked into the image (e.g. after a rebuild):
```bash
docker volume rm omp-sandbox-bun
# Next omp-sandbox run re-initializes the volume from the image
```

---

## Security model

Mounted into the container:
- Project dir(s) — read/write
- `OMP_HOME_MOUNT_PATH` → `/home/bun/.omp` — read/write, persistent
- Docker volume `omp-sandbox-bun` → `/home/bun/.bun` — OMP binary, updateable

Not mounted: real `~/.omp`, `~/.ssh`, `~/.config/gcloud`, `~/.aws`, Docker socket, full home directory.

Caps dropped (`--cap-drop=ALL`), `--security-opt=no-new-privileges`, pids/memory/CPU limited.

---

## Browser OAuth login (Claude Pro/Max, ChatGPT, etc.)

OMP's OAuth callback server binds to `localhost` inside the container, so the browser redirect to `localhost:<port>/callback?...` will show **connection refused**. No port forwarding or second terminal needed — OMP supports a paste flow for all subscription providers (Anthropic, OpenAI Codex, GitLab, Google Gemini CLI, and others):

1. Run `/login <provider>` inside OMP. A URL is printed — open it in your browser.
2. Approve the login on the provider's site.
3. The browser tries to redirect to `localhost:<port>/callback?code=...&state=...` and shows "connection refused" or "site can't be reached".
4. **Copy the full URL from the browser's address bar** (it contains `?code=...&state=...`).
5. Paste it into OMP's terminal prompt. OMP extracts the code and completes login.

The credentials are written to `/home/bun/.omp` and persist across container restarts.
