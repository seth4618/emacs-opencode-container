# Emacs + OpenCode Dev Container (Central `dev-*` Commands)

This repository provides a **centralized dev-container toolkit**. You install/use these scripts once, add them to your `PATH`, and run them from any supported git repository.

The runtime model is:
- **Common**: shared host home fragments (`HOST_COMMON_HOME`) used across projects.
- **Project-specific**: your git repo bind-mounted to `/workspace/<repo>`.
- **Instance-specific**: per-repo runtime artifacts in `<repo>/.devcontainer/.runtime`.

## One-time setup (host machine)

1. Clone this repository (tooling home):

```bash
git clone <this-repo-url> ~/src/emacs-opencode-container
```

2. Add scripts to your shell `PATH` (example for bash):

```bash
echo 'export PATH="$HOME/src/emacs-opencode-container/scripts:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

3. Verify commands are discoverable:

```bash
which dev-up.sh
aaaa=$(which dev-init.sh); echo "$aaaa"
```

4. Ensure prerequisites exist on host:
- Docker + Docker Compose plugin
- Git
- Wayland socket path (for GUI Emacs mode)

## Per-repository setup and usage

Run these commands **from inside a git repository** you want to develop in.

1. Initialize repo-local container config:

```bash
dev-init.sh
```

This creates:
- `<repo>/.devcontainer/.env`
- `<repo>/.devcontainer/.runtime/`
- `<repo>/.devcontainer/opencode.env.template`

2. Edit `<repo>/.devcontainer/.env` and set required values:
- `HOST_REPO_PATH` (absolute path to this repo)
- `WAYLAND_SOCKET_PATH`

Optional values:
- `COMPOSE_PROJECT_NAME`
- `HOST_COMMON_HOME`
- `HOST_OPENCODE_SHARE_DIR` (recommended shared path, usually `~/.local/share/opencode`)
- `HOST_OPENCODE_CONFIG_DIR` (recommended shared config path, usually `~/.config/opencode`)
- `HOST_SSH_DIR` (host SSH directory mounted read-only to `~/.ssh` in container)
- `OPENCODE_MODEL` (repo default model; falls back to `$HOST_COMMON_HOME/.opencode-common.env`)
- cache/state overrides

3. Start or update the container:

```bash
dev-up.sh
```

4. Open a shell in the container:

```bash
dev-shell.sh
```

5. Start Emacs:

```bash
dev-emacs.sh --terminal
# or
dev-emacs.sh --gui
```

6. Run OpenCode:

```bash
dev-opencode.sh
```

Copy the template when configuring OpenCode provider settings:

```bash
cp .devcontainer/opencode.env.template .devcontainer/opencode.env
```


If you want stronger isolation between concurrent repo containers, run:

```bash
dev-bootstrap-opencode.sh
```

This seeds defaults for:
- shared OpenCode data/auth: `HOST_OPENCODE_SHARE_DIR=$HOME/.local/share/opencode`
- shared OpenCode config: `HOST_OPENCODE_CONFIG_DIR=$HOME/.config/opencode`
- common home: `HOST_COMMON_HOME=$HOME/.opencode-common-home`

Values are only written when missing in `.devcontainer/.env`.

Note: `HOST_OPENCODE_DIR` is deprecated. Use `HOST_OPENCODE_SHARE_DIR` and `HOST_OPENCODE_CONFIG_DIR`.
7. Inspect status / stop container:

```bash
dev-status.sh
dev-down.sh
```

## What `dev-up.sh` does

When you run `dev-up.sh`, it:
1. Resolves git repo root (`git rev-parse --show-toplevel`).
2. Ensures `.devcontainer` exists (`dev-init.sh` behavior).
3. Loads `.devcontainer/.env`.
4. Bootstraps common home via `setup-common-home.sh`.
5. Regenerates `.devcontainer/.runtime/compose.env`.
6. Rebuilds `.devcontainer/.runtime/secrets` secrets bundle.
7. Runs `docker compose up -d --build` using central `docker-compose.yml`.

Secrets are materialized into `<repo>/.devcontainer/.runtime/secrets` as real files/directories during `dev-up.sh` (not host-path symlinks), then mounted at `/secrets` in the container. Re-run `dev-up.sh` after changing `secrets-paths.txt` entries or secret file contents.

## Common home behavior (`HOST_COMMON_HOME`)

`setup-common-home.sh` creates/refreshes:
- copied files:
  - `.bashrc`
  - `.emacs.d/init.el`
  - `.emacs.d/early-init.el`
- symlink:
  - `.emacs.d/repo-emacs.d` -> `/workspace/<repo>/emacs.d`
- local override stubs (if missing):
  - `.bashrc.local`
  - `.emacs.d/init.local.el`
  - `.emacs.d/early-init.local.el`

Emacs Customize writes to `~/.emacs.d/init.local.el` (`custom-file`), keeping repo-managed defaults unchanged.

## Script reference (brief)

- `dev-init.sh`: create `<repo>/.devcontainer` scaffolding and `.env` template.
- `dev-bootstrap-opencode.sh`: seed OpenCode share defaults and `HOST_COMMON_HOME` (without overriding existing values).
- `dev-up.sh`: bootstrap common home, generate runtime env/secrets, build/start container.
- `dev-shell.sh`: interactive shell in running container (auto-start if needed).
- `dev-emacs.sh`: launch Emacs in terminal or GUI mode.
- `dev-opencode.sh`: run OpenCode in container context.
- `dev-status.sh`: print resolved repo/context paths and compose status.
- `dev-down.sh`: stop container for current repo context.
- `setup-common-home.sh`: manage shared `HOST_COMMON_HOME` template files.
- `test-common-home.sh`: validate common-home bootstrap behavior.
- `check-wayland.sh`: inspect Wayland-related container readiness.
- `sync-status.sh`: show container and host git status summary.
- `new-worktree.sh` / `new-disposable-branch.sh`: helper workflows for git branches/worktrees.

## Verification checklist

From a repo using this system:

```bash
dev-status.sh
dev-shell.sh
```

Inside container:

```bash
pwd
ls -la ~/.emacs.d ~/.bashrc ~/.bashrc.local
emacs -Q --batch -l ~/.emacs.d/early-init.el -l ~/.emacs.d/init.el --eval '(message "emacs-init-ok")'
```

## Notes

- Git repositories are required (non-git directories are not supported in this phase).
- Linux-focused workflow.
- `git push origin` is blocked in-container by `/usr/local/bin/git` wrapper.


### OpenCode model defaults

Model default precedence is:
1. `OPENCODE_MODEL` in `<repo>/.devcontainer/.env`
2. `OPENCODE_MODEL` in `$HOST_COMMON_HOME/.opencode-common.env`
3. OpenCode built-in default

You can also place additional OpenCode env defaults in `<repo>/.devcontainer/opencode.env` (repo-specific) or `~/.opencode-common.env` (common-home) for container runtime wrappers.

### Recommended OpenCode persistence layout

- Shared across all repos/containers:
  - `HOST_OPENCODE_SHARE_DIR=~/.local/share/opencode`
  - Contains shared auth/data (including `auth.json`).
  - `HOST_OPENCODE_CONFIG_DIR=~/.config/opencode`
  - Contains shared config (including `opencode.jsonc`).
- Per-repo (persistent but isolated):
  - `<repo>/.devcontainer/.runtime/opencode-state` (automatic default; no extra env needed)
  - Contains runtime OpenCode home/state (DB, logs, history) to avoid cross-project collisions.

Implementation note: container env points `OPENCODE_HOME`, `OPENCODE_STATE_DIR`, `XDG_STATE_HOME`, and `XDG_DATA_HOME` to this repo-local runtime path so OpenCode runtime DB/state does not drift back into the shared directory.


## Troubleshooting

- If `dev-opencode.sh` prints `opencode command not found`, rebuild the container image after setting `OPENCODE_NPM_PACKAGE` in `<repo>/.devcontainer/.env` and run `dev-up.sh` again.

## Using OpenAI models with OpenCode (Step-by-step)

This section assumes you want:
- shared OpenAI auth/config across repos, and
- per-repo runtime state in `<repo>/.devcontainer/.runtime/opencode-state`.

### 1) Confirm OpenCode is installed where you will run setup

If `opencode --version` fails on your host, install it first (host-side):

```bash
npm install -g opencode-ai
```

Then verify:

```bash
opencode --version
```

You can still run OpenCode inside this dev container via `dev-opencode.sh`, but for OAuth plugin setup it is often easiest to run the initial login on the host first.

### 2) Ensure repo/container env defaults are in place

From your project repo:

```bash
dev-init.sh
dev-bootstrap-opencode.sh
```

Then check `<repo>/.devcontainer/.env` includes:
- `HOST_OPENCODE_SHARE_DIR` (shared auth/config; typically `~/.local/share/opencode`)
- no per-repo state env is required (repo-local state is automatic via compose env)

### 3) Sign in with native OpenCode OAuth (host recommended)

Run OpenCode and sign in to OpenAI via the built-in auth flow:

```bash
opencode
```

This should open a browser for official OAuth login and write/update:
- `~/.local/share/opencode/auth.json`
- `~/.config/opencode/opencode.jsonc`

### 4) Add/verify model defaults in OpenCode config

Edit your OpenCode config (usually under `~/.config/opencode/`) and set desired defaults, for example:

```json
{
  "model": "openai/gpt-5.4",
  "provider": {
    "openai": {
      "models": {
        "gpt-5.4": {
          "options": {
            "reasoningEffort": "medium",
            "textVerbosity": "low"
          }
        }
      }
    }
  }
}
```

Use GPT-5.4 first to validate setup. After it works, you can test GPT-5.5 by changing model IDs in the same structure if available in your plugin/account path.

### 5) Restart container and verify end-to-end

```bash
dev-down.sh
dev-up.sh
dev-opencode.sh
```

Inside container, confirm paths:

```bash
echo "$OPENCODE_HOME"
echo "$OPENCODE_AUTH_DIR"
```

Expected:
- `OPENCODE_HOME` points to repo-local runtime state under `/workspace/.../.devcontainer/.runtime/opencode-state`
- `OPENCODE_AUTH_DIR` points to `/opencode-share`

Container entrypoint links shared auth/config into `OPENCODE_HOME` (`auth.json` and `opencode.jsonc`) so running `opencode` directly from an interactive shell resolves credentials consistently.

### 6) If browser OAuth cannot run from container

Do OAuth once on the host (Step 3), then restart the container. Because auth (`~/.local/share/opencode`) and config (`~/.config/opencode`) are both shared host mounts, containers in other repos should pick it up automatically.
