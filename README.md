# Disposable Emacs + OpenCode Docker dev environment (Ubuntu 24.04)

This repository provides a **simple, inspectable, local-only** setup for safely using OpenCode inside Emacs with Docker.

## Design summary

- Host checkout mounted read-only at `/src-host`.
- Writable git workspace lives in Docker volume at `/workspace`.
- Emacs, language servers, and OpenCode run inside the same container.
- Container runs as a non-root UID/GID-matched user.
- Wayland GUI Emacs is preferred; terminal Emacs (`-nw`) is always available.
- Host handles `git push`; container focuses on editing/commits.

## Filesystem and safety model

- `/src-host` (bind mount, read-only): your host checkout.
- `/workspace` (named volume, writable): disposable working repo clone.
- `/opencode-state` (bind mount, read-write): host-shared OpenCode state directory (e.g. `~/.local/share/opencode`).
- `/run/secrets` (bind mount, read-only): optional global secrets directory for env files.
- No Docker socket mount.
- No privileged mode.
- No host PID namespace.
- No host home directory mount.
- Compose runs a one-shot `emacs-state-init` helper that fixes ownership on the `emacs_state` volume to `${HOST_UID}:${HOST_GID}` before `dev` starts.  (Did this because ~/.emacs.d was owned by root. Manual fix was to run `docker compose exec -u root dev chown -R "$(grep HOST_UID .env | cut -d= -f2):$(grep HOST_GID .env | cut -d= -f2)" /home/dev/.emacs.d`)

## Quick start

1. Copy env template:

   ```bash
   cp .env.example .env
   ```

2. Edit `.env` with absolute paths:
   - `HOST_REPO_PATH`
   - `HOST_OPENCODE_DIR` (recommended: `~/.local/share/opencode`)
   - `HOST_SECRETS_DIR` (optional)
   - `WAYLAND_SOCKET_PATH`
   - `HOST_UID` / `HOST_GID` (usually `id -u`, `id -g`)

3. Build and start:

   ```bash
   docker compose up -d --build
   ```

4. Initialize writable `/workspace` from read-only `/src-host`:

   ```bash
   scripts/init-workspace.sh
   ```

5. Start Emacs:

   GUI (Wayland preferred):
   ```bash
   scripts/start-gui-emacs.sh
   ```

   Terminal fallback:
   ```bash
   scripts/start-terminal-emacs.sh
   ```

6. Run OpenCode:

   ```bash
   scripts/run-opencode.sh
   ```

## Script reference

- `scripts/init-workspace.sh [init|refresh]`
  - `init`: first-time copy from `/src-host` (includes `.git`).
  - `refresh`: sync host files into `/workspace` while preserving `/workspace/.git`.
- `scripts/import-from-host.sh`
  - Convenience wrapper for `init-workspace.sh refresh`.
- `scripts/export-to-host.sh`
  - Explicitly copies `/workspace` content back to host checkout.
  - Refuses to run if host tree is dirty unless `FORCE=1`.
- `scripts/sync-status.sh`
  - Shows container and host git status.
- `scripts/enter-shell.sh`
  - Opens shell in running container at `/workspace`.
- `scripts/new-disposable-branch.sh [name]`
  - Creates branch in `/workspace`; refuses on dirty tree unless `ALLOW_DIRTY=1`.
- `scripts/new-worktree.sh <branch> <target-dir>`
  - Adds a git worktree under `/workspace`; same dirty-tree guard.
- `scripts/start-gui-emacs.sh`
  - Validates Wayland socket then launches GUI Emacs.
- `scripts/start-terminal-emacs.sh`
  - Runs `emacs -nw` in `/workspace`.
- `scripts/sync-emacs-base.sh`
  - Refreshes `~/.emacs.d/{early-init.el,init.el,local-init.d}` from `/opt/emacs-base` without touching package caches.
- `scripts/run-opencode.sh [args...]`
  - Sources all `*.env` files under `/run/secrets` if present and runs `opencode`.

## Emacs configuration

Base config lives in `emacs.d/`:

- Minimal startup (`early-init.el`).
- Small `init.el` that installs and configures:
  - `lsp-mode`
  - `magit`
  - `gptel`
  - `typescript-mode`, `json-mode`, `solidity-mode`
  - built-in `python-mode`
- Local override hook: `emacs.d/local-init.d/*.el` loaded automatically.

On each Emacs launch, `scripts/sync-emacs-base.sh` refreshes `early-init.el`, `init.el`, and `local-init.d/` from `/opt/emacs-base` into the persistent `~/.emacs.d` volume so repo config updates are applied without wiping package state.

## Language support notes

Image includes day-one tools:

- Python: `python3`, `python3-venv`, `pyright`
- TypeScript: `typescript`, `typescript-language-server`
- Solidity: `hardhat`, `solhint`, `@nomicfoundation/solidity-language-server`

Sample files are included in `sample/` for quick LSP checks.

## OpenCode notes

- OpenCode is installed from npm package `${OPENCODE_NPM_PACKAGE}` at build time.
- OpenCode auth/state lives in `HOST_OPENCODE_DIR` mounted at `/opencode-state`.
- This supports reusing one `/connect` login across multiple containerized projects.
- `scripts/run-opencode.sh` supports running from Emacs terminal or external host terminal.

If `opencode` is missing, set `OPENCODE_NPM_PACKAGE` in `.env` and rebuild.

## Step-by-step: test OpenCode with the sample files

Use this flow to sanity-check OpenCode in your containerized setup.

### 1) Start/refresh the environment (**host terminal**)

```bash
docker compose up -d --build
scripts/init-workspace.sh refresh
```

- `up -d --build` ensures image/tooling (including OpenCode package) is current.
- `init-workspace.sh refresh` pulls latest host repo files into `/workspace` while preserving container git metadata.

### 2) Start terminal Emacs (**host terminal**, launches Emacs in container)

```bash
scripts/start-terminal-emacs.sh
```

- This runs `emacs -nw` inside the container at `/workspace`.
- Open sample files from Emacs (for example under `sample/`) and make a tiny test edit.

### 3) Launch OpenCode (**recommended: second host terminal**)

```bash
scripts/run-opencode.sh
```

- Yes: launch from a host terminal window. The script enters the running container and executes `opencode` in `/workspace`.
- If you prefer, you can launch from inside an existing container shell (`scripts/enter-shell.sh`) and run `opencode` there; behavior is equivalent.

### 4) Try a sample OpenCode workflow

From OpenCode, prompt against files in `/workspace/sample` (or your own files) and ask for a small deterministic change, then verify in Emacs.

Suggested quick checks:

- Ask for a minimal refactor in one sample file.
- Ask OpenCode to explain the diff before applying.
- Run `git status -sb` in `/workspace` to confirm only expected files changed.

### 5) Review sync state (**host terminal**)

```bash
scripts/sync-status.sh
```

- Shows container `/workspace` git status and host checkout git status side by side.

## Best practice: host repo updated, how to update container copy

When you pull/rebase/update the host repo, use this repeatable sequence:

1. **Host**: update your checkout normally (`git pull --rebase`, switch branch, etc.).
2. **Host**: run `scripts/init-workspace.sh refresh` to sync host file changes into container `/workspace` while preserving `/workspace/.git`.
3. **Host**: run `scripts/sync-status.sh` and confirm both sides look as expected.
4. If tool versions changed (Dockerfile, package installs, OpenCode package), run `docker compose up -d --build` again.

Tip: use `scripts/init-workspace.sh init` only for first-time workspace creation; use `refresh` for normal day-to-day host updates.


## Handling synced host changes cleanly

When you run `scripts/init-workspace.sh refresh`, `/workspace` is intentionally updated to match host files, so git may show unstaged changes in the container copy. This does **not** rewrite host commit history by itself.

Recommended flow:

1. Inspect what changed: `git status -sb` and `git diff`.
2. If the changes are desired in-container, commit them in `/workspace` as normal.
3. If they are only local/transient, discard them in `/workspace` with `git restore --worktree -- .` (or `git reset --hard HEAD` if you also want to drop staged edits).
4. Keep untracked dependency trees out of status by ignoring common local dirs (for example `sample/*/node_modules/`, included in `.gitignore`).

Use `scripts/export-to-host.sh` only when you explicitly want to copy container working tree changes back to the host checkout.



## Troubleshooting: should I delete the container and start over?

Usually **no**. In this setup, deleting/recreating the container is often enough; you only need to remove volumes for specific state problems.

Recommended escalation path:

1. Recreate just the container image/runtime:
   - `docker compose down`
   - `docker compose up -d --build`
2. Re-sync source into `/workspace`:
   - `scripts/init-workspace.sh refresh`
3. If Emacs still shows runtime/permission oddities, reset only Emacs state volume (this removes installed packages/customizations in container state):
   - `docker compose down`
   - `docker volume rm ${EMACS_STATE_VOLUME_NAME:-emacs_opencode_emacs_state}`
   - `docker compose up -d --build`
4. If Python LSP still does not start, verify inside container:
   - `scripts/enter-shell.sh`
   - `which pyright-langserver`

Notes:
- Removing the container does **not** change host git history.
- Removing the workspace volume will discard unexported container-side edits.



### Verify the container was actually rebuilt

Run these from the **host**:

```bash
docker compose up -d --build --force-recreate
docker compose ps
docker compose exec dev bash -lc 'id; echo XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR; which pyright-langserver; pyright --version'
```

What to confirm:

- `docker compose ps` shows `dev` is `Up`.
- `XDG_RUNTIME_DIR` prints the value from `docker-compose.yml` (currently `/tmp`).
- `which pyright-langserver` resolves to a real path.
- `pyright --version` prints a version (CLI package is installed).
- Running `pyright-langserver` directly without transport flags will print a connection/stdio error; that is expected when launched manually.
- If `*lsp-log*` still mentions optional Python servers (`pylsp`, `ruff`, etc.), fully restart Emacs after rebuild so updated `init.el` is reloaded.

If Emacs still shows old behavior after rebuild, the persisted Emacs state volume may still have stale package state. Reset just Emacs state and relaunch:

```bash
docker compose down
docker volume rm ${EMACS_STATE_VOLUME_NAME:-emacs_opencode_emacs_state}
docker compose up -d --build
```

## Tradeoffs / limitations (intentional)

- Sync strategy is intentionally simple and one-way by default.
- `export-to-host` is explicit to reduce accidental host writes.
- Not production hardened; optimized for local transparency and safe experimentation.
- `opencode.el` integration is intentionally left for later.
