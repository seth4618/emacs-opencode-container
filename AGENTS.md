# AGENTS.md

## What This Repo Is
- This repo is a central dev-container toolkit, not a single app. The main product is the `scripts/dev-*.sh` wrappers plus root `docker-compose.yml` and `Dockerfile`.
- Emacs startup is split on purpose: `home-template/.emacs.d/init.el` is the common-home entrypoint, and it loads the repo-specific config from `emacs.d/init.el` through the `repo-emacs.d` symlink.

## High-Value Paths
- `scripts/`: canonical behavior for `dev-init.sh`, `dev-up.sh`, `dev-shell.sh`, `dev-emacs.sh`, `dev-opencode.sh`, `dev-status.sh`, `dev-down.sh`.
- `docker-compose.yml`: mounts, OpenCode state/config locations, container working directory, and cache paths.
- `docker/load-runtime-env.sh`: actual env-loading order inside the container.
- `home-template/`: files copied into `HOST_COMMON_HOME` by `setup-common-home.sh`.
- `emacs.d/`: repo-managed Emacs config loaded inside the common home.
- `.devcontainer/elisp-helpers/opencode.el/`: external helper checkout updated by `scripts/sync-elisp-helpers.sh`; treat it as upstream-managed unless the task explicitly targets it.

## Command Reality
- Run repo commands through the shell scripts, not raw `docker compose`; the scripts resolve repo context, load both env files, and auto-start the container when needed.
- `scripts/dev-up.sh` always runs `scripts/dev-init.sh` first, then `scripts/sync-elisp-helpers.sh`, then rebuilds `.devcontainer/.runtime/compose.env` and `.devcontainer/.runtime/secrets/`, then runs `docker compose up -d --build`.
- `scripts/dev-shell.sh`, `scripts/dev-emacs.sh`, and `scripts/dev-opencode.sh` all auto-start the container via `ensure_running` if it is down.
- Commands resolve the target repo with `git rev-parse --show-toplevel`; use `DEV_REPO_ROOT` only if you intentionally need to override that.

## Verification
- Primary lightweight regression check for this repo: `scripts/test-common-home.sh`.
- For container-context changes, verify with `scripts/dev-status.sh` before and after `scripts/dev-up.sh`.
- If you change Emacs bootstrap behavior, use the repo's documented batch check:
  `emacs -Q --batch -l ~/.emacs.d/early-init.el -l ~/.emacs.d/init.el --eval '(message "emacs-init-ok")'`

## Environment And State Gotchas
- Container OpenCode runtime state is repo-local: `/workspace/<repo>/.devcontainer/.runtime/opencode-state`.
- Shared OpenCode auth/config are separate mounts: `/opencode-share` and `/opencode-config`.
- In-container env loading order is: `/secrets/*.env` first, then `~/.opencode-common.env`, then `<repo>/.devcontainer/opencode.env`. Later files win.
- Only files ending in `.env` under `/secrets` are sourced; other files there are ignored with a warning.
- Re-run `scripts/dev-up.sh` after changing `secrets-paths.txt` or secret file contents; it recopies the secrets bundle each run.

## Workflow Constraints
- `scripts/sync-elisp-helpers.sh` does a real `git clone`/`git pull` of `https://codeberg.org/sczi/opencode.el.git`; avoid surprising yourself with network access or unrelated helper updates during `dev-up.sh`.
- `git push` is intentionally blocked inside the container by `docker/git-safe`; push from the host if needed.
- `scripts/new-worktree.sh` and `scripts/new-disposable-branch.sh` refuse dirty worktrees unless `ALLOW_DIRTY=1` is set.
- Sample projects under `sample/` are demos for language/tooling setup, not the main verification target for changes to the toolkit itself.

## Coding conventions

all file names starting with `.,` are editor backup files and should be ignored by all tooling.  Likewise, files starting with `#scg` are editor created autosave files and should be ignored.  Finally, files starting with `.#` are editor created lock files and should be ignored.
