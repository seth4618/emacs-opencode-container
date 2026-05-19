# Per-repo Emacs + OpenCode Docker environment

This setup runs Emacs and OpenCode inside Docker while your repository stays bind-mounted from host under `/workspace/<repo-name>`.

## Architecture (three-tier storage)

1. **Common (shared across projects)**
   - Host path: `${HOST_COMMON_HOME:-$HOME/.opencode-common-home}`
   - Contains shared shell/Emacs entrypoints and user overrides.
   - Bootstrapped from `home-template/` by `scripts/setup-common-home.sh`.

2. **Project-specific**
   - Host repo bind-mounted to `/workspace/${WORKSPACE_DIRNAME}`.
   - All project code, git operations, and project tools run here.

3. **Instance-specific (ephemeral runtime)**
   - Container runtime-only state that is not part of common or project mounts.

## What is mounted into the container

From project host checkout:
- `${HOST_REPO_PATH}` -> `/workspace/${WORKSPACE_DIRNAME}`

From common home:
- `${HOST_COMMON_HOME}/.emacs.d` -> `/home/${CONTAINER_USER:-dev}/.emacs.d`
- `${HOST_COMMON_HOME}/.bashrc` -> `/home/${CONTAINER_USER:-dev}/.bashrc`
- `${HOST_COMMON_HOME}/.bashrc.local` -> `/home/${CONTAINER_USER:-dev}/.bashrc.local`

From host caches/state:
- npm/pnpm/pip caches
- host `.cache`
- OpenCode state dir

## Common home behavior

`scripts/setup-common-home.sh` creates/refreshes:
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

Emacs Customize writes to `~/.emacs.d/init.local.el` (`custom-file`) so repo-managed defaults are not edited.

## Quick start

1. Create env file:

```bash
cp .env.example .env
```

2. Edit `.env` with at least:
- `HOST_REPO_PATH` (absolute path)
- `WAYLAND_SOCKET_PATH`
- optionally `COMPOSE_PROJECT_NAME`, `HOST_COMMON_HOME`

3. (Optional) configure secrets list:

```bash
cp secrets-paths.txt.example secrets-paths.txt
```

4. Start/update container:

```bash
scripts/dev-up.sh
```

`dev-up.sh` auto-runs `scripts/setup-common-home.sh` before `docker compose up`.

5. Enter shell:

```bash
scripts/enter-shell.sh
```

6. Start Emacs:

```bash
scripts/start-terminal-emacs.sh
# or
scripts/start-gui-emacs.sh
```

7. Run OpenCode:

```bash
scripts/run-opencode.sh
```

## Testing and verification

Automated bootstrap check:

```bash
scripts/test-common-home.sh
```

Container smoke checks:

```bash
scripts/enter-shell.sh
ls -la ~/.emacs.d ~/.bashrc ~/.bashrc.local
emacs -Q --batch -l ~/.emacs.d/early-init.el -l ~/.emacs.d/init.el --eval '(message "emacs-init-ok")'
```

## Notes

- Linux-focused workflow.
- Image installs `emacs-pgtk` (Wayland-capable Emacs build).
- LSP servers and OpenCode are preinstalled in the image.
- `git push origin` is blocked in-container by `/usr/local/bin/git` wrapper.


## Central command usage (run from any git repo)

With `scripts/` on your `PATH`, the recommended commands are:

- `dev-init.sh` - create `<repo>/.devcontainer/.env` if missing
- `dev-up.sh` - bootstrap common home and start/update container
- `dev-shell.sh` - open interactive shell
- `dev-emacs.sh --terminal|--gui` - start Emacs in container
- `dev-opencode.sh` - run OpenCode in container
- `dev-status.sh` - show resolved repo/context and compose status
- `dev-down.sh` - stop project container

These commands require a git worktree (repo root is discovered via `git rev-parse --show-toplevel`).
