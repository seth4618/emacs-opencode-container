# Emacs + OpenCode Dev Container (Central `dev-*` Commands)

This repository is a **centralized dev-container toolkit**, not a single application. Install or put the `scripts/` directory on your `PATH`, then run the `dev-*` commands from any git repository you want to develop in.

The current runtime model is:

- **Common home**: shared host home fragments (`HOST_COMMON_HOME`) mounted into the container for Bash and Emacs startup.
- **Project checkout**: the target git repo bind-mounted read/write at `/workspace/<repo-name>`.
- **Git common directory**: the checkout's common `.git` directory is also
  mounted at its original host path so linked worktrees can resolve their
  `.git` metadata inside the container.
- **Repo-local runtime**: generated env, copied secrets, and OpenCode state under `<repo>/.devcontainer/.runtime`.
- **Project image layer**: an editable, committed `<repo>/.devcontainer/Dockerfile` built on the shared `eoc-base-container:latest` image.
- **Shared OpenCode auth/config**: optional host mounts for `/opencode-share` and `/opencode-config`, separate from repo-local runtime state.

> Note: an earlier design used `/src-host` plus a named Docker volume workspace and import/export scripts. That design is no longer the active implementation.

## One-time setup (host machine)

1. Clone this repository (tooling home):

```bash
git clone <this-repo-url> ~/src/emacs-opencode-container
```

2. Add scripts to your shell `PATH` (example for Bash):

```bash
echo 'export PATH="$HOME/src/emacs-opencode-container/scripts:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

3. Verify commands are discoverable:

```bash
command -v dev-up.sh
command -v dev-stop.sh
command -v dev-resume.sh
command -v dev-init.sh
```

4. Ensure prerequisites exist on the host:

- Docker with the Docker Compose plugin
- Git
- A Wayland socket path for GUI Emacs mode (terminal Emacs does not need Wayland)

5. If you change the Dockerfile, remember to run
   ```
   scripts/dev-build-image.sh base
   for image in base coding everything latex middle; do
      scripts/dev-build-image.sh "$image"
   done
   ```

## Per-repository setup and usage

Run these commands **from inside the git repository** you want to develop in.

1. Initialize repo-local container config:

```bash
dev-init.sh coding
```

This creates:

- `<repo>/.devcontainer/.env`
- `<repo>/.devcontainer/.gitignore`
- `<repo>/.devcontainer/.runtime/`
- `<repo>/.devcontainer/Dockerfile`
- `<repo>/.devcontainer/opencode.env.template`

2. Review `<repo>/.devcontainer/.env` and `<repo>/.devcontainer/Dockerfile`.

`dev-init.sh` seeds the usual required values automatically:

- `HOST_REPO_PATH` defaults to the current repo root.
- `HOST_GIT_COMMON_DIR` defaults to the repo's absolute `git rev-parse --git-common-dir` result.
- `WAYLAND_SOCKET_PATH` defaults to `/run/user/<uid>/wayland-0`.
- `COMPOSE_PROJECT_NAME` defaults to a Docker Compose-safe version of `<repo-name>-dev` (lowercase, starts with a letter or digit, and contains only lowercase letters, digits, hyphens, and underscores). For example, a repo named `BRAINS26` becomes `brains26-dev`.

Common optional values include:

- `EOC_BASE_IMAGE` (set by `dev-init.sh`; for example `eoc-coding-container:latest`)
- `HOST_COMMON_HOME` (defaults to `$HOME/.opencode-common-home` during `dev-up.sh`)
- `HOST_OPENCODE_SHARE_DIR` (defaults to `$HOME/.local/share/opencode`)
- `HOST_OPENCODE_CONFIG_DIR` (defaults to `$HOME/.config/opencode`)
- `HOST_SSH_DIR` (defaults to `$HOME/.ssh` and is mounted read-only)
- `OPENCODE_MODEL` (repo default model; falls back to `$HOST_COMMON_HOME/.opencode-common.env`)
- cache/state/resource overrides such as `HOST_CACHE_DIR`, `CPU_LIMIT`, `MEM_LIMIT`, and `PIDS_LIMIT`

`dev-init.sh` requires an image choice. Use `base` for only the shared OpenCode/Emacs base image, or use a template name from `docker-templates/` such as `coding`, `latex`, `everything`, or `middle`. The selected template image is built as `eoc-<name>-container:latest` when missing or older than its template Dockerfile. The generated project Dockerfile is intentionally small: it starts from the selected image and keeps only the required project user layer so Docker Compose can run with your host UID/GID. The generated `.devcontainer/.gitignore` ignores `.env`, `.runtime/`, and `opencode.env` while allowing `.devcontainer/Dockerfile`, `.devcontainer/.gitignore`, and `.devcontainer/opencode.env.template` to be committed.

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

Copy the template when configuring repo-specific OpenCode provider settings:

```bash
cp .devcontainer/opencode.env.template .devcontainer/opencode.env
```

7. Optionally seed shared OpenCode/common-home defaults:

```bash
dev-bootstrap-opencode.sh
```

This writes missing values only:

- `HOST_OPENCODE_SHARE_DIR=$HOME/.local/share/opencode`
- `HOST_OPENCODE_CONFIG_DIR=$HOME/.config/opencode`
- `HOST_COMMON_HOME=$HOME/.opencode-common-home`

`HOST_OPENCODE_DIR` is deprecated. Use `HOST_OPENCODE_SHARE_DIR` and `HOST_OPENCODE_CONFIG_DIR` instead.

Docker Compose requires project names to match its lowercase project-name format because Compose uses the value to derive Docker resource names, labels, and network/container identifiers. If an older `.devcontainer/.env` contains an invalid value such as `COMPOSE_PROJECT_NAME=BRAINS26-dev`, rerun `dev-init.sh` or `dev-up.sh`; `dev-init.sh` will rewrite it to a valid lowercase form such as `brains26-dev`.

8. Inspect status, stop the container without removing it, or remove it:

```bash
dev-status.sh
dev-stop.sh       # reclaim container CPU/RAM while preserving the container
dev-resume.sh     # restart that container without rebuilding it
dev-down.sh       # remove the container and Compose network
```

Use `dev-stop.sh` when you are temporarily stepping away from a project. It
stops the container's processes, releasing their CPU and RAM, while retaining
the container for a quick `dev-resume.sh`. Resume checks whether Dockerfiles,
Compose/environment configuration, templates, or configured secrets changed
since the last successful `dev-up.sh`; it warns about drift but still starts
the existing container. Run `dev-up.sh` explicitly when you want those changes
applied through the normal refresh and rebuild workflow.

## What `dev-up.sh` does

When you run `dev-up.sh`, it:

1. Resolves the target git repo root (`git rev-parse --show-toplevel`).
2. Verifies that `dev-init.sh <base|template-name>` has already created the required `.devcontainer` files; if not, it prints the missing paths and exits.
3. Syncs the external `.devcontainer/elisp-helpers/opencode.el` helper checkout by running `sync-elisp-helpers.sh`.
4. Loads `<repo>/.devcontainer/.env`.
5. Bootstraps common home via `setup-common-home.sh`.
6. Creates host cache, OpenCode, SSH, and repo-local runtime directories as needed.
7. Rebuilds `<repo>/.devcontainer/.runtime/secrets` from `secrets-paths.txt`.
8. Regenerates `<repo>/.devcontainer/.runtime/compose.env`.
9. Runs Docker Compose using this repository's root `docker-compose.yml` and the repo's `<repo>/.devcontainer/Dockerfile`.
10. Records a runtime-only fingerprint of the container build/configuration inputs and configured secret sources so `dev-resume.sh` can warn about drift later.

Secrets are materialized into `<repo>/.devcontainer/.runtime/secrets` as real files/directories during `dev-up.sh` (not host-path symlinks), then mounted at `/secrets` in the container. Re-run `dev-up.sh` after changing `secrets-paths.txt` entries or secret file contents.

Runtime wrappers (`run-opencode.sh`, `start-terminal-emacs.sh`, `start-gui-emacs.sh`, and `enter-shell.sh`) source `/usr/local/bin/load-runtime-env` in-container. The load order is:

1. `/secrets/*.env`
2. `~/.opencode-common.env`
3. `<repo>/.devcontainer/opencode.env`

Later files win. Only files ending in `.env` under `/secrets` are sourced; non-`.env` files present directly under `/secrets` are ignored and logged as warnings.

## Common home behavior (`HOST_COMMON_HOME`)

`setup-common-home.sh` creates or refreshes:

- copied files:
  - `.bashrc`
  - `.emacs.d/init.el`
  - `.emacs.d/early-init.el`
  - `.local/bin/gen-bootstrap.py`
  - `.local/bin/dump-session.py`
  - `.local/bin/dump2md.py`
- symlink:
  - `.emacs.d/repo-emacs.d` -> `/workspace/<repo>/emacs.d`
- local override stubs (if missing):
  - `.bashrc.local`
  - `.emacs.d/init.local.el`
  - `.emacs.d/early-init.local.el`

Emacs Customize writes to `~/.emacs.d/init.local.el` (`custom-file`), keeping repo-managed defaults unchanged.

The commands under `.local/bin` are refreshed from this toolkit's `scripts/`
directory by `dev-up.sh`, mounted read-only in the container, and added to the
common shell `PATH`.

## Script inventory

There is no `src/` directory in the current repository. The shell scripts under `scripts/` are the active command surface and container entry wrappers.

### Primary host commands

- `dev-init.sh`: create `<repo>/.devcontainer` scaffolding, including the repo `.env` template and editable project Dockerfile.
- `dev-build-base.sh`: build the shared `eoc-base-container:latest` base image from this toolkit checkout.
- `dev-up.sh`: bootstrap common home, sync helper elisp, ensure the base image exists, generate runtime env/secrets, and build/start the project container.
- `dev-stop.sh`: stop the project container without removing it, reclaiming its active CPU and RAM while preserving it for a quick resume.
- `dev-resume.sh`: start an existing stopped container without rebuilding it, warning if tracked container inputs changed; fall back to `dev-up.sh` if no container exists.
- `dev-shell.sh`: open an interactive shell in the running container, automatically using `dev-resume.sh` if needed.
- `dev-emacs.sh`: launch Emacs in terminal or GUI mode.
- `dev-opencode.sh`: run OpenCode in container context.
- `dev-status.sh`: print resolved repo/context paths and Docker Compose status.
- `dev-down.sh`: stop and remove the container and Compose network for the current repo context.
- `dev-bootstrap-opencode.sh`: seed shared OpenCode/common-home defaults without overwriting existing values.

### Supporting host commands

- `check-wayland.sh`: inspect Wayland-related container readiness for GUI Emacs.
- `sync-status.sh`: show container and host git status summary.
- `new-worktree.sh`: host-side helper that creates a persistent sibling worktree
  named `<repo>-<branch-or-name>`, reuses an existing branch or creates a new one,
  and runs `dev-init.sh` in the new worktree so it gets its own local
  `.devcontainer/.env`, Compose project name, container, and project image layer
  while sharing the configured base/template image. By default it must be run
  from the host repo on `main`; set `WORKTREE_BASE_BRANCH=<branch>` for repos
  whose integration branch is not `main`, or `ALLOW_NON_BASE_BRANCH=1` when you
  intentionally want to bypass that safety check.
- `new-disposable-branch.sh`: helper workflow for quick disposable branches.
- `setup-common-home.sh`: manage shared `HOST_COMMON_HOME` template files.
- `test-common-home.sh`: validate common-home bootstrap behavior.
- `sync-elisp-helpers.sh`: clone/update the external `.devcontainer/elisp-helpers/opencode.el` helper checkout used by the base image build.

### In-container entry wrappers

These scripts are copied or invoked as the container-side behavior behind the host commands and should be kept with the toolkit:

- `enter-shell.sh`
- `run-opencode.sh`
- `start-gui-emacs.sh`
- `start-terminal-emacs.sh`

## Verification checklist

Primary lightweight regression check for this toolkit:

```bash
scripts/test-common-home.sh
scripts/test-dev-init.sh coding
scripts/test-new-worktree.sh
```

From a repo using this system:

```bash
dev-status.sh
dev-shell.sh
```

Inside the container:

```bash
pwd
ls -la ~/.emacs.d ~/.bashrc ~/.bashrc.local
emacs -Q --batch -l ~/.emacs.d/early-init.el -l ~/.emacs.d/init.el --eval '(message "emacs-init-ok")'
```

For container-context changes to this toolkit, compare status before and after by running these **from the host** and **from this repository root** (not from inside the container):

```bash
scripts/dev-status.sh
scripts/dev-up.sh
scripts/dev-status.sh
```

When validating another repo that uses this toolkit, run the equivalent `dev-status.sh`, `dev-up.sh`, and `dev-status.sh` commands from that target repo on the host.

## Notes

- Git repositories are required; non-git directories are not supported in this phase.
- This is a Linux-focused workflow.
- The target repo is currently mounted read/write at `/workspace/<repo-name>`.
- `git push origin` is blocked in-container by `/usr/local/bin/git`; push from the host if needed.
- `dev-up.sh` uses network access when `sync-elisp-helpers.sh` clones or pulls `https://codeberg.org/sczi/opencode.el.git`.
- The shared base image is tagged `eoc-base-container:latest` and includes the OpenCode npm package. Layered template images are tagged `eoc-<template>-container:latest`; use `dev-build-image.sh <base|template-name>` or rerun `dev-init.sh <base|template-name>` after toolkit Dockerfile/template changes to refresh them. The base image includes an OCI revision label so you can inspect which toolkit commit produced it.

## OpenCode model defaults

Model default precedence is:

1. `OPENCODE_MODEL` in `<repo>/.devcontainer/.env`
2. `OPENCODE_MODEL` in `$HOST_COMMON_HOME/.opencode-common.env`
3. OpenCode built-in default

You can also place additional OpenCode env defaults in `<repo>/.devcontainer/opencode.env` (repo-specific) or `~/.opencode-common.env` (common-home) for container runtime wrappers.

## Recommended OpenCode persistence layout

- Shared across all repos/containers:
  - `HOST_OPENCODE_SHARE_DIR=~/.local/share/opencode`
  - Contains shared auth/data, including `auth.json`.
  - `HOST_OPENCODE_CONFIG_DIR=~/.config/opencode`
  - Contains shared config, including `opencode.jsonc`.
- Per-repo (persistent but isolated):
  - `<repo>/.devcontainer/.runtime/opencode-state` (automatic default; no extra env needed)
  - Contains runtime OpenCode home/state (DB, logs, history) to avoid cross-project collisions.

Implementation note: container env points `OPENCODE_HOME`, `OPENCODE_STATE_DIR`, `XDG_STATE_HOME`, and `XDG_DATA_HOME` to this repo-local runtime path so OpenCode runtime DB/state does not drift back into the shared directory.

## Using OpenAI models with OpenCode (step-by-step)

This section assumes you want shared OpenAI auth/config across repos and per-repo runtime state in `<repo>/.devcontainer/.runtime/opencode-state`.

### 1. Confirm OpenCode is installed where you will run setup

If `opencode --version` fails on your host, install it first (host-side):

```bash
npm install -g opencode-ai
```

Then verify:

```bash
opencode --version
```

You can still run OpenCode inside this dev container via `dev-opencode.sh`, but for OAuth plugin setup it is often easiest to run the initial login on the host first.

### 2. Ensure repo/container env defaults are in place

From your project repo:

```bash
dev-init.sh
dev-bootstrap-opencode.sh
```

Then check `<repo>/.devcontainer/.env` includes `HOST_OPENCODE_SHARE_DIR` and `HOST_OPENCODE_CONFIG_DIR`. No per-repo state env is required because repo-local state is automatic via the generated Compose env.

### 3. Sign in with native OpenCode OAuth (host recommended)

Run OpenCode and sign in to OpenAI via the built-in auth flow:

```bash
opencode
```

This should open a browser for official OAuth login and write/update:

- `~/.local/share/opencode/auth.json`
- `~/.config/opencode/opencode.jsonc`

### 4. Add or verify model defaults in OpenCode config

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

Use the model available to your OpenCode provider/account path.

### 5. Restart container and verify end-to-end

```bash
dev-down.sh
dev-up.sh
dev-opencode.sh
```

Inside the container, confirm paths:

```bash
echo "$OPENCODE_HOME"
echo "$OPENCODE_AUTH_DIR"
```

Expected:

- `OPENCODE_HOME` points to repo-local runtime state under `/workspace/.../.devcontainer/.runtime/opencode-state`.
- `OPENCODE_AUTH_DIR` points to `/opencode-share`.

### 6. If browser OAuth cannot run from the container

Do OAuth once on the host (step 3), then restart the container. Because auth (`~/.local/share/opencode`) and config (`~/.config/opencode`) are both shared host mounts, containers in other repos should pick it up automatically.

If you intentionally need to complete browser OAuth from inside the container, temporarily expose the callback port in `docker-compose.yml` and then run `dev-up.sh` again:

```yaml
    init: true
    ports:
      - "1455:1455"
    security_opt:
      - no-new-privileges:true
```

Remove that port mapping when OAuth setup is complete if you do not want the callback port exposed during normal development.

## Troubleshooting

- If `dev-opencode.sh` prints `opencode command not found`, rebuild the selected base/template image with `dev-build-image.sh <base|template-name>` and then run `dev-up.sh` again. OpenCode is installed in `eoc-base-container:latest` via `OPENCODE_NPM_PACKAGE`.
- If GUI Emacs cannot connect to Wayland, run `check-wayland.sh` and use `dev-emacs.sh --terminal` while debugging the socket path/permissions.
- If a changed `secrets-paths.txt` entry is not visible in the container, rerun `dev-up.sh` so the secrets bundle is recopied.

## Known rough edges

- GUI Emacs depends on host Wayland socket permissions and may need per-host adjustments.
- OpenCode OAuth is usually easier to bootstrap on the host first, then share auth/config with the container.
- The repo checkout is currently bind-mounted read/write, so this toolkit does not provide the older read-only-host plus explicit import/export isolation model.
- `dev-up.sh` updates the external `opencode.el` helper checkout, so container rebuilds can pull unrelated upstream helper changes.
