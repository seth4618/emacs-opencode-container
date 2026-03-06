
Create a disposable test repository that sets up a **local Docker-based development environment** for safe use of OpenCode inside Emacs on Ubuntu 24.04.

### Primary goal

Build a test setup where:

* Emacs runs **inside a Docker container**
* graphical Emacs over **Wayland** is the first choice
* terminal Emacs is a **fallback**
* language servers run **inside the same container**
* OpenCode runs **inside the container**
* host project files are **not directly writable by the agent**
* all writable work happens in **Docker volumes / container filesystem**
* state persists across container restarts
* OpenCode auth can persist across projects if desired
* the host handles `git push`
* the system is simple and transparent to inspect

### Constraints and preferences

#### Host / runtime

* Host OS: Ubuntu 24.04
* Container runtime: Docker
* Local machine only
* One repo at a time
* Most projects are monorepos

#### Safety / isolation

* Container must run as a **non-root user**
* No privileged container
* No Docker socket mount
* No host PID namespace
* Protect host OS, home directory, and host checkout from accidental modification
* Writes should not escape the container writable area
* Moderate, easy-to-change resource controls are acceptable

#### Filesystem model

Use this model:

* mount the host repo **read-only** at `/src-host`
* maintain a writable working repo at `/workspace` in a **named Docker volume**
* project state should survive container restart/crash
* design scripts to support:

  * import/sync from host checkout into `/workspace`
  * export/sync from `/workspace` back to host only when explicitly requested

#### Emacs

* Prefer Emacs 29+
* Start with a **minimal blank config**
* Add a clear hook mechanism so later user-specific config can be layered in easily
* Prefer **graphical Emacs via Wayland**
* Provide terminal fallback with `emacs -nw`

#### Languages / tools

Day-one support:

* Python
* TypeScript
* Solidity

Tooling to include:

* git
* node
* npm
* pnpm
* python3
* python3-venv
* Emacs
* ripgrep
* fd
* jq
* curl
* less
* procps
* openssh-client

Language tooling:

* Python with `venv`
* TypeScript via `typescript` and `typescript-language-server`
* Solidity with:

  * Hardhat
  * Foundry
  * Solidity language support
  * formatter/linter support if practical on day one

#### Emacs packages

Install and minimally configure:

* `lsp-mode`
* `magit`
* `gptel`
* suitable major modes for Python, TypeScript, TSX, JSON, Solidity
* keep config intentionally small and understandable

#### OpenCode

* Install OpenCode in the container
* configure persistent state so one `/connect` can be reused across projects if desired
* support running OpenCode:

  * from terminal inside Emacs
  * from an external host terminal attached to the container
* do not require `opencode.el` for the first pass
* optionally leave a placeholder for later experimentation with `opencode.el`

#### Secrets

* Use one **global host-mounted read-only secret file**
* assume OpenAI provider initially
* do not mount the whole home directory
* do not mount `~/.ssh` by default

#### Git workflow

* Host handles push
* Container may commit locally
* Include helpers for:

  * creating a disposable branch
  * optionally creating a git worktree
  * refusing destructive actions on a dirty tree unless explicitly overridden

---

## Deliverables

Create these files and any others needed:

### Top-level docs

* `README.md`
* `.env.example`

### Docker / orchestration

* `Dockerfile`
* `docker-compose.yml`

### Shell scripts

Under `scripts/`:

* `start-gui-emacs.sh`
* `start-terminal-emacs.sh`
* `enter-shell.sh`
* `import-from-host.sh`
* `export-to-host.sh`
* `sync-status.sh`
* `init-workspace.sh`
* `new-disposable-branch.sh`
* `new-worktree.sh`
* `run-opencode.sh`

### Emacs config

Under `emacs.d/`:

* `init.el`
* `early-init.el` if useful
* `local-init.d/README.md` explaining how to extend config

### Test project content

Create a small disposable sample repo content:

* `sample/python/hello.py`
* `sample/typescript/hello.ts`
* `sample/solidity/Hello.sol`

Also include minimal project files where helpful:

* `sample/typescript/package.json`
* `sample/solidity/package.json` or a minimal Hardhat scaffold
* optional minimal Foundry scaffold if easy to include

---

## Implementation requirements

### Docker image

Base image:

* Ubuntu 24.04

Install:

* Emacs GUI-capable package suitable for Wayland if available
* terminal Emacs fallback
* node/npm/pnpm
* python3/python3-venv/pip
* git
* openssh-client
* common CLI tools
* language servers and dev tools

Create a non-root user whose UID/GID can be matched to the host user through environment variables.

### Compose file

Use named volumes for:

* workspace
* emacs state
* opencode state/auth
* npm cache
* pnpm store
* pip cache
* other useful caches

Bind mounts:

* host repo to `/src-host` as read-only
* global secrets file as read-only
* Wayland socket and required runtime pieces for GUI mode

Provide easy-to-edit environment variables for:

* UID/GID
* host repo path
* secret file path
* CPU/memory/pids limits
* display variables
* workspace naming

### Workspace initialization

`init-workspace.sh` should:

* initialize `/workspace` from `/src-host` if needed
* preserve `.git` metadata appropriately
* be idempotent
* avoid destructive overwrite without warning
* support either:

  * initial copy from host checkout, or
  * refresh from host checkout while preserving container-local branch state, if practical

A simple first version is acceptable if clearly documented.

### Emacs behavior

`start-gui-emacs.sh` should:

* launch graphical Emacs in container
* prefer Wayland
* fail cleanly with a helpful message if GUI setup is unavailable

`start-terminal-emacs.sh` should:

* always work
* launch `emacs -nw` in `/workspace`

### LSP behavior

The sample files should be enough to verify that:

* Python LSP attaches
* TypeScript LSP attaches
* Solidity language support works

Do not overengineer; basic working diagnostics/completion is enough.

### OpenCode behavior

`run-opencode.sh` should:

* source the mounted secret file if present
* use persistent OpenCode state/auth directory
* run from `/workspace`

### Safety / defaults

* default to local-only, transparent behavior
* do not mount host home
* do not mount Docker socket
* no privileged settings
* keep comments in config files explaining why each mount/volume exists

---

## Acceptance criteria

The setup is successful if the following works on Ubuntu 24.04:

1. `docker compose up -d` starts the environment
2. `scripts/init-workspace.sh` creates the writable `/workspace`
3. `scripts/start-gui-emacs.sh` launches graphical Emacs from the container on the host display
4. if GUI fails, `scripts/start-terminal-emacs.sh` works
5. opening the sample Python/TypeScript/Solidity files in Emacs allows `lsp-mode` to function
6. `scripts/run-opencode.sh` launches OpenCode in `/workspace`
7. OpenCode auth/state persists across container restarts
8. modifying files in `/workspace` does not modify the read-only host checkout unless an explicit export script is run
9. helper scripts for disposable branches/worktrees function or are clearly documented if partial

---

## Non-goals for the first pass

Do not spend time on:

* perfect bidirectional sync
* production-hardening
* Kubernetes / remote deployment
* deep `opencode.el` integration
* elaborate Emacs personalization
* full project generator for real repos

Keep the first pass small, understandable, and working.

---

## Suggested instructions to Codex on style

* prefer simple shell scripts over complex frameworks
* document tradeoffs in `README.md`
* keep all paths and environment variables explicit
* choose the least clever solution that works
* add comments where future customization is expected
* if a choice is uncertain, implement the simpler version and note the limitation

---

You can paste that directly to Codex.

One small addition I would make when you do: tell it to produce a short section in the README called **“Known rough edges”** so it documents likely trouble spots such as Wayland socket permissions and syncing semantics. That makes the first trial much easier to debug.
