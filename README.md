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

2. Edit `<repo>/.devcontainer/.env` and set required values:
- `HOST_REPO_PATH` (absolute path to this repo)
- `WAYLAND_SOCKET_PATH`

Optional values:
- `COMPOSE_PROJECT_NAME`
- `HOST_COMMON_HOME`
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
6. Rebuilds `.devcontainer/.runtime/secrets` symlink bundle.
7. Runs `docker compose up -d --build` using central `docker-compose.yml`.

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
