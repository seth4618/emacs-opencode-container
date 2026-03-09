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

On first GUI launch, the base config is copied into the persistent Emacs state volume (`~/.emacs.d`) if missing.

If the mounted Emacs state directory is not writable, the start scripts automatically fall back to `/workspace/.emacs.d` for that session.

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

## Tradeoffs / limitations (intentional)

- Sync strategy is intentionally simple and one-way by default.
- `export-to-host` is explicit to reduce accidental host writes.
- Not production hardened; optimized for local transparency and safe experimentation.
- `opencode.el` integration is intentionally left for later.
