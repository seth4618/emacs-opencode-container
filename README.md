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

4. Start/update container:

```bash
scripts/dev-up.sh
```

5. Open shell:

```bash
scripts/enter-shell.sh
```

6. Start Emacs:

```bash
scripts/start-terminal-emacs.sh
# or
scripts/start-gui-emacs.sh
```

If you changed `emacs.d/*` and want to re-sync immediately without restarting the container:

```bash
scripts/enter-shell.sh
$ scripts/sync-emacs-base.sh
```

7. Run OpenCode:

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
- LSP servers and OpenCode are preinstalled in the image.
- `git push origin` is blocked by a git wrapper at `/usr/local/bin/git`.
