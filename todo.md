# TODO / Review Status

This file tracks the current state of the toolkit after review. The original first-pass goal has mostly been implemented, but the implementation has intentionally moved away from the older `/src-host` + named-volume workspace model.

## Current implementation status

### Done

- Central `dev-*` host commands exist under `scripts/`.
- Docker image is based on Ubuntu 24.04 and installs Emacs, Git, Node/npm/pnpm, Python, OpenSSH client, common CLI tools, language servers, Hardhat/Solidity tooling, and OpenCode.
- Containers run as the configured non-root host UID/GID.
- The target repo is mounted at `/workspace/<repo-name>`.
- Common Bash/Emacs home fragments are managed by `scripts/setup-common-home.sh` and mounted from `HOST_COMMON_HOME`.
- GUI Emacs via Wayland and terminal Emacs wrappers exist.
- OpenCode runs inside the container with repo-local runtime state and optional shared host auth/config mounts.
- Runtime env loading order is documented and implemented as `/secrets/*.env`, then common OpenCode env, then repo OpenCode env.
- Git push is blocked in-container by `docker/git-safe`; pushes are expected from the host.
- Disposable branch/worktree helpers exist and refuse dirty worktrees unless `ALLOW_DIRTY=1` is set.
- Sample Python, TypeScript, and Solidity projects exist.
- Lightweight common-home regression coverage exists in `scripts/test-common-home.sh`.

### Not the current design

These items were part of the original exploratory prompt but are not how this repository currently works:

- No `src/` directory exists.
- No `/src-host` read-only mount is configured.
- No Docker named volume is used as the primary writable workspace.
- No `import-from-host.sh`, `export-to-host.sh`, or `init-workspace.sh` scripts are present.
- Host project files are writable from the container because the repo is bind-mounted read/write at `/workspace/<repo-name>`.

## Script inventory review

All current scripts in `scripts/` have a purpose and should stay unless the overall workflow is redesigned.

### User-facing wrappers

- `dev-init.sh` - creates per-repo `.devcontainer` scaffolding.
- `dev-up.sh` - initializes, syncs elisp helpers, writes runtime env/secrets, and starts Compose.
- `dev-shell.sh` - user-friendly wrapper for an interactive container shell.
- `dev-emacs.sh` - user-friendly wrapper for terminal or GUI Emacs.
- `dev-opencode.sh` - user-friendly wrapper for OpenCode.
- `dev-status.sh` - prints resolved paths and Compose status.
- `dev-down.sh` - stops the current repo container.
- `dev-bootstrap-opencode.sh` - seeds common OpenCode/common-home defaults.

### Supporting commands

- `_common.sh` - shared context, Compose, and auto-start helpers.
- `setup-common-home.sh` - common-home installer used by `dev-up.sh` and tests.
- `test-common-home.sh` - lightweight regression test.
- `sync-elisp-helpers.sh` - fetches the upstream-managed `.devcontainer/elisp-helpers/opencode.el` helper checkout.
- `check-wayland.sh` - Wayland diagnostics for GUI Emacs.
- `sync-status.sh` - host/container git status summary.
- `new-disposable-branch.sh` - container-side branch helper.
- `new-worktree.sh` - container-side worktree helper.

### Container command implementations

- `enter-shell.sh` - implementation behind `dev-shell.sh`.
- `run-opencode.sh` - implementation behind `dev-opencode.sh`.
- `start-terminal-emacs.sh` - implementation behind `dev-emacs.sh --terminal`.
- `start-gui-emacs.sh` - implementation behind `dev-emacs.sh --gui`.

## Open follow-ups

- Decide whether read/write bind mounts are acceptable long-term. If stronger host-checkout isolation is required, redesign around `/src-host`, a writable volume workspace, and explicit import/export scripts.
- Consider making `HOST_SSH_DIR` opt-in instead of creating/mounting `$HOME/.ssh` by default.
- Consider adding shellcheck to CI or local verification once available in the environment.
- Consider adding tests for generated `.devcontainer/.runtime/compose.env` and secrets bundle behavior.
- Consider documenting or automating the temporary OpenCode OAuth callback port workflow.
- Consider whether `sync-elisp-helpers.sh` should be optional during `dev-up.sh` to avoid network work on every update.

