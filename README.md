# Per-repo Emacs + OpenCode Docker environment (bind-mount mode)

This setup runs Emacs/OpenCode inside Docker while using your host git checkout as the writable workspace.

## What this mode guarantees

- One container per repo (`/workspace/<repo-name>` bind-mounted read/write).
- Container can edit, commit, branch, and run tools in that repo.
- `git push origin` is blocked inside the container.
- Prompt in interactive container shells is `C-<dirname>$`.
- Uses host UID/GID for file ownership compatibility.
- Persistent host caches for npm/pnpm/pip and `~/.cache`.
- Container-specific Emacs profile (`~/.emacs.d-container` on host by default).
- On container start, base Emacs config from this repo is synced into that profile automatically.
- Secrets are configured from a text file of host paths, mounted read-only under `/secrets`.

## Multiple repos at once

Yes — this supports multiple concurrent containers, one per repo. Set a distinct `COMPOSE_PROJECT_NAME` per repo in each repo-local `.env`.

## Quick start

1. Create env file:

```bash
cp .env.example .env
```

2. Edit `.env` with at least:
- `HOST_REPO_PATH` (absolute path)
- `WAYLAND_SOCKET_PATH`
- optionally `COMPOSE_PROJECT_NAME`

3. (Optional) configure secrets list:

```bash
cp secrets-paths.txt.example secrets-paths.txt
# then add absolute paths, one per line
```

4. Initialize/refresh common home (phase 2):

```bash
scripts/setup-common-home.sh
```

5. Start/update container:

```bash
scripts/dev-up.sh
```

6. Open shell:

```bash
scripts/enter-shell.sh
```

7. Start Emacs:

```bash
scripts/start-terminal-emacs.sh
# or
scripts/start-gui-emacs.sh
```

If running `emacs` directly opens terminal mode, GUI setup likely failed. Use `scripts/start-gui-emacs.sh` and confirm `WAYLAND_DISPLAY`, `XDG_RUNTIME_DIR`, and `GDK_BACKEND=wayland` are present in the container environment. `XDG_RUNTIME_DIR` must be a user-owned `0700` directory (this setup uses `/home/dev/.xdg-runtime`) and the Wayland socket is linked there from `/tmp/$WAYLAND_DISPLAY`.

To inspect everything quickly:

```bash
scripts/check-wayland.sh
```

If you changed `emacs.d/*` and want to re-sync immediately without restarting the container:

```bash
scripts/enter-shell.sh
$ scripts/sync-emacs-base.sh
```

8. Run OpenCode:

```bash
scripts/run-opencode.sh
```

## Secrets model

- Put paths in `secrets-paths.txt` (file/dir per line, comments allowed).
- `scripts/dev-up.sh` builds `.runtime/secrets/` symlinks.
- Compose mounts that directory read-only at `/secrets`.
- `scripts/run-opencode.sh` sources `/secrets/*.env` automatically.

## Important behavior changes from copy-workspace mode

- `scripts/init-workspace.sh` is now a no-op.
- `scripts/export-to-host.sh` is now a no-op (workspace is already host bind mount).
- `scripts/sync-status.sh` still shows container and host git status.

## Notes

- Linux-focused workflow.
- Image installs `emacs-pgtk` (Wayland-capable Emacs build).
- LSP servers and OpenCode are preinstalled in the image.
- `git push origin` is blocked by a git wrapper at `/usr/local/bin/git`.


## Three-tier storage model

This repo now supports a three-tier storage layout:

1. **Common** (shared across projects): user-managed common home with repo-linked defaults.
2. **Project-specific**: the bind-mounted `/workspace/<repo-name>` checkout.
3. **Instance-specific**: ephemeral per-container runtime state.

### Common home template

Repo-managed defaults live under `home-template/`.
Use the bootstrap script to create a common home and symlink template files:

```bash
scripts/setup-common-home.sh
# or
scripts/setup-common-home.sh /absolute/path/to/common-home
```

By default it creates `~/.opencode-common-home`.

If you previously used an earlier version of this setup and Emacs init files are broken in-container, re-run:

```bash
scripts/setup-common-home.sh
```

That refreshes copied entrypoint files and repairs the `repo-emacs.d` symlink target.


`scripts/dev-up.sh` now automatically bootstraps `${HOST_COMMON_HOME:-$HOME/.opencode-common-home}` before running `docker compose`, and the container mounts `.bashrc` and `.emacs.d` from that common home.

The script currently links:

- `.bashrc` is copied from `home-template/.bashrc`
- `.emacs.d/init.el` is copied from `home-template/.emacs.d/init.el`
- `.emacs.d/early-init.el` is copied from `home-template/.emacs.d/early-init.el`
- `.emacs.d/repo-emacs.d` is symlinked to `/workspace/<repo>/emacs.d` for in-container loading

### Local overrides

Common shell and Emacs entrypoints support local user overrides:

- `~/.bashrc.local`
- `~/.emacs.d/init.local.el`
- `~/.emacs.d/early-init.local.el`

`init.local.el` is also used as Emacs `custom-file`, so Customize UI changes are written there instead of the repo-managed template files.

These files are optional and are not tracked in this repo.


### How to test this

Run the common-home test script:

```bash
scripts/test-common-home.sh
```

What it validates:

- `scripts/setup-common-home.sh` runs successfully in a temporary directory
- required symlinks are created
- each symlink points to the expected repository-managed target

Manual smoke test (optional):

```bash
TARGET="$HOME/.opencode-common-home-test"
scripts/setup-common-home.sh "$TARGET"
bash --rcfile "$TARGET/.bashrc" -ic 'echo shell-ok'
emacs --batch -q -l "$TARGET/.emacs.d/early-init.el" -l "$TARGET/.emacs.d/init.el" --eval '(message "emacs-ok")'
```

### Migration notes

Migration from previous copy/mount behavior should be done incrementally:

1. Create and validate common home via `scripts/setup-common-home.sh`.
2. Point container HOME usage to that common home.
3. Move one path at a time from legacy copy/mount logic into common/project/instance tiers.
4. Validate behavior after each step with `scripts/sync-status.sh` and regular Emacs startup checks.
