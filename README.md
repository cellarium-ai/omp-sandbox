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

```bash
./omp-update.sh
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

Use `omp-login.sh` instead of `omp-sandbox` when you need to authenticate a subscription provider. It bridges the OAuth callback port so the browser redirect reaches OMP directly — no second terminal, no paste needed.

```bash
# Default: Anthropic
omp-login

# Other providers
omp-login openai-codex
omp-login gemini-cli
```

Inside OMP, run `/login <provider>`. Approve in your browser — the callback hits OMP and login completes automatically. Credentials are saved to `/home/bun/.omp` and persist across sessions.

**How it works:** OMP's callback server binds to `127.0.0.1:<port>` (loopback). Docker's `-p` can only reach `0.0.0.0`. `omp-login.sh` runs `socat` inside the container to bridge `0.0.0.0:<port+1> → 127.0.0.1:<port>`, then publishes `<port>:<port+1>` so the host browser's redirect flows through cleanly.

Supported providers and their ports:

| Provider | Port |
|---|---|
| `anthropic` | 54545 |
| `openai-codex` | 1455 |
| `gemini-cli` | 8085 |
| `antigravity` | 51121 |
| `gitlab` | 8080 |
| `devin` | 59653 |

After logging in, exit and start your normal session with `omp-sandbox`.
