# Centralized Dev Container Command Spec

This document defines a command-level spec for running the dev container tooling from a **single central install** (the `emacs-opencode-container` repo/scripts on `PATH`) while storing per-project configuration under each target repo's `.devcontainer/` directory.

## Goals

- Avoid duplicating scripts across every project repo.
- Keep project-specific configuration/state close to the project.
- Allow commands to run from anywhere inside a git worktree.
- Preserve three-tier storage model:
  - Common (shared home)
  - Project-specific (`/workspace/<repo>`)
  - Instance-specific runtime state

## Terms

- **TOOL_HOME**: path to the central `emacs-opencode-container` checkout where canonical scripts/assets live.
- **REPO_ROOT**: `git rev-parse --show-toplevel` for current working directory (or explicit `--repo-root`).
- **PROJECT_DOTDIR**: `${REPO_ROOT}/.devcontainer`.
- **PROJECT_ENV_FILE**: `${PROJECT_DOTDIR}/.env`.
- **PROJECT_RUNTIME_DIR**: `${PROJECT_DOTDIR}/.runtime`.
- **PROJECT_COMPOSE_ENV_FILE**: `${PROJECT_RUNTIME_DIR}/compose.env`.
- **PROJECT_DOCKERFILE**: `${PROJECT_DOTDIR}/Dockerfile`.
- **BASE_IMAGE**: shared toolkit image tag, default `eoc-base-container:latest`.

## Required command behavior

### Common discovery rules (all commands)

1. Resolve `TOOL_HOME` from script location.
2. Resolve `REPO_ROOT`:
   - default: `git rev-parse --show-toplevel`
   - override: `--repo-root <path>`
3. Resolve `PROJECT_DOTDIR` = `${REPO_ROOT}/.devcontainer`.
4. Load env files in precedence order:
   1) CLI flags
   2) process env
   3) `${PROJECT_ENV_FILE}`
   4) defaults

If `REPO_ROOT` cannot be resolved, command exits with clear guidance.

## Commands

### `dev-init`

Bootstrap per-repo `.devcontainer` config.

#### Inputs
- Required image argument: `base` or a template name matching `docker-templates/<name>.docker`.

#### Behavior
1. Ensure the selected layer image exists and is newer than its source Dockerfile; build `eoc-base-container:latest` for `base`, otherwise build `eoc-<name>-container:latest` from `docker-templates/<name>.docker`.
2. Create `${PROJECT_DOTDIR}` and `${PROJECT_RUNTIME_DIR}` if absent.
3. If `${PROJECT_ENV_FILE}` missing, create from template with required keys, comments, and `EOC_BASE_IMAGE` set to the selected image.
4. If `${PROJECT_DOTDIR}/.gitignore` is missing, create one that ignores local env/runtime files but allows the project Dockerfile and templates to be committed.
5. If `${PROJECT_DOCKERFILE}` missing, create an editable project Dockerfile that starts from `${BASE_IMAGE}` and keeps the required final user layer for host UID/GID matching.
6. If present, do not overwrite user-editable files.
7. Print next steps: edit `.env` and `.devcontainer/Dockerfile`, run `dev-up`.

#### Exit conditions
- `0` on success.
- nonzero with actionable message on write/permission failure.

### `dev-up`

Create/update and start project container.

#### Inputs
- Optional `--repo-root <path>`
- Optional passthrough args forwarded to `docker compose up`

#### Behavior
1. Run discovery rules.
2. Verify that `dev-init.sh <base|template-name>` has already created `${PROJECT_ENV_FILE}`, `${PROJECT_DOTDIR}/Dockerfile`, `${PROJECT_DOTDIR}/.gitignore`, and `${PROJECT_DOTDIR}/opencode.env.template`; if not, print the missing paths and exit.
3. Require `HOST_REPO_PATH` in `${PROJECT_ENV_FILE}` or derive from `REPO_ROOT` when absent.
4. Set `WORKSPACE_DIRNAME` default = `basename(HOST_REPO_PATH)`.
5. Set `HOST_COMMON_HOME` default = `${HOME}/.opencode-common-home`.
6. Run common-home bootstrap:
   - `setup-common-home.sh <HOST_COMMON_HOME> /workspace/<WORKSPACE_DIRNAME>`
7. Regenerate `${PROJECT_COMPOSE_ENV_FILE}`.
8. Run compose using:
   - `--env-file ${PROJECT_ENV_FILE}`
   - `--env-file ${PROJECT_COMPOSE_ENV_FILE}`
   - compose definition from `TOOL_HOME/docker-compose.yml`
   - build context `${HOST_REPO_PATH}`
   - dockerfile `${PROJECT_DOCKERFILE}`
9. Start service `dev` with build.

#### Exit conditions
- `0` on success.
- nonzero with diagnostics for missing docker, invalid env, mount path errors.

### `dev-build-base`

Build the shared toolkit base image.

#### Inputs
- Optional Docker build flags.
- `dev-build-base.sh` is a compatibility wrapper for `dev-build-image.sh base`.

#### Behavior
1. Sync external elisp helpers used by the base image.
2. Build `TOOL_HOME/Dockerfile` as `eoc-base-container:latest`.
3. Add an OCI revision label with the toolkit git revision when available.

#### Exit conditions
- `0` on success.
- nonzero with diagnostics for missing docker, network, or build errors.

### `dev-shell`

Open interactive shell in running project container.

#### Inputs
- Optional `--repo-root <path>`

#### Behavior
1. Run discovery rules.
2. Check compose project status for `dev` service in this repo context.
3. If not running: print notice and run `dev-up`.
4. Exec shell and `cd ${PROJECT_WORKSPACE:-/workspace}`.

### `dev-emacs`

Start Emacs in running container.

#### Inputs
- Optional `--repo-root <path>`
- Optional `--gui` / `--terminal` (`--terminal` default)

#### Behavior
- Terminal mode: `emacs -nw` from project workspace.
- GUI mode: validate Wayland socket and then start `emacs`.
- Reuse same compose context and auto-start behavior as `dev-shell`.

### `dev-opencode`

Run OpenCode in container.

#### Behavior
- Reuse same compose context and auto-start behavior.
- Source `/secrets/*.env` if present (current behavior parity).

### `dev-down`

Stop project container.

#### Inputs
- Optional `--repo-root <path>`
- Optional `--volumes`

#### Behavior
- Run `docker compose down [--volumes]` for this repo context.

### `dev-status`

Show project/container and mount status.

#### Behavior
Display:
- resolved `REPO_ROOT`
- resolved `.devcontainer` paths
- compose project name
- container running state
- key env (`HOST_REPO_PATH`, `WORKSPACE_DIRNAME`, `HOST_COMMON_HOME`)

## File layout (per project)

```text
<REPO_ROOT>/
  .devcontainer/
    .env
    .gitignore
    Dockerfile
    opencode.env.template
    .runtime/
      compose.env
      secrets/
```

## `.env` minimum keys

Required:
- `HOST_REPO_PATH`
- `WAYLAND_SOCKET_PATH`

Optional:
- `COMPOSE_PROJECT_NAME`
- `HOST_COMMON_HOME`
- cache path overrides
- secrets file override

## Safety and idempotency requirements

- `dev-init` and `dev-up` must be idempotent.
- Existing user files, including `.devcontainer/Dockerfile`, must never be overwritten silently.
- Generated files under `.runtime/` may be replaced each run.
- Commands must never depend on current working directory once `REPO_ROOT` is resolved.

## Migration status

Centralized `dev-*` commands and per-repo `.devcontainer` runtime layout are now the active model.

## Current decisions (implemented)

- Command names are standardized on `dev-*`.
- Non-git directories are not supported in this phase.
- Workflow uses central commands on `PATH` with per-repo `.devcontainer` state and an editable per-repo project Dockerfile.
