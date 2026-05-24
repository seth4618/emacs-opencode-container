---
name: repo-cleanup
description: Use when cleaning a repository without deleting needed local files, especially for untracked files not already ignored. Investigate each untracked non-ignored path, then write safe delete candidates to /tmp/cleanup.sh and keep-or-review candidates to /tmp/maybecleanup.sh.
---

# Repo Cleanup

Use this skill when the user wants to clean a repository but avoid deleting local state, secrets, or other intentionally untracked files.

## Goals
- Focus on untracked files and directories that are not already ignored.
- Investigate whether each remaining path is important, generated, stale, or accidental.
- Write delete candidates to `/tmp/cleanup.sh`.
- Write ambiguous or intentionally local-but-untracked paths to `/tmp/maybecleanup.sh` with shell comments explaining why they may need to stay.
- Never execute either script unless the user explicitly asks.

## Required Process
1. Start with `git status --short --ignored` or `git status --short --ignored --untracked-files=all`.
2. Ignore paths already covered by `.gitignore` or equivalent ignore rules unless the user explicitly wants ignored files reviewed too.
3. From the remaining untracked paths, investigate before judging:
   - read relevant files
   - inspect suspicious directories
   - check whether a path is referenced by scripts, config, docs, or workflows
   - distinguish runtime output from intentional local configuration
4. Classify each path:
   - delete: clearly generated, stale, scratch, debug, backup, lock, cache, build output, or accidental copies
   - maybe keep: useful local-only state, secrets, per-user config, local environment files, helper checkouts, or anything the repo actively uses even if it should stay untracked
5. Create or update both scripts:
   - `/tmp/cleanup.sh`
   - `/tmp/maybecleanup.sh`
6. Do not run the scripts.

## Investigation Heuristics

### Usually safe delete candidates
- editor backups and autosaves
- transient logs
- debug dumps
- test/build artifacts
- dependency install directories created from package managers
- generated caches
- scratch notes with no repo integration

### Usually maybe-keep candidates
- `.env` files
- secrets path lists
- local auth/config mounts
- `.devcontainer/` runtime or repo-local environment used by scripts
- helper repos cloned by documented setup scripts
- local files that are intentionally untracked but part of normal operation

## Repo-specific Guidance For This Repo
- Root `AGENTS.md` says files beginning with `.,`, `#scg`, and `.#` are editor backup/autosave/lock files and should be ignored by tooling. In cleanup work, these are strong delete candidates unless the user says otherwise.
- `scripts/dev-*.sh` are the canonical entrypoints; check whether untracked files are consumed by those scripts before proposing deletion.
- `scripts/dev-up.sh` rebuilds repo-local runtime state under `.devcontainer/.runtime/`; treat that tree as local state, not automatic trash.
- `secrets-paths.txt` is intentionally gitignored in this repo and is used by `scripts/dev-up.sh` to rebuild the secrets bundle.
- `elisp-helpers/opencode.el/` is intentionally untracked and maintained by `scripts/sync-elisp-helpers.sh`.
- Root `.env` is gitignored here, but the current active per-repo configuration lives in `.devcontainer/.env`; determine whether root `.env` is legacy or still needed before recommending deletion.

## Script Format
- Use `#!/usr/bin/env bash` and `set -euo pipefail`.
- Define `repo_root` and use quoted absolute paths.
- Put only delete commands in `/tmp/cleanup.sh`.
- In `/tmp/maybecleanup.sh`, keep each candidate commented or preceded by comments explaining why it may be needed.
- Add a header comment stating the script is for manual review and must not be auto-executed.

Example structure for `/tmp/maybecleanup.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

# Review manually before running anything here.
repo_root="/path/to/repo"

# Keep if this repo still uses repo-local secrets configuration.
# rm -rf -- "$repo_root/secrets-paths.txt"
```

## Output Expectations
- Summarize what was placed in each script.
- Call out any risky deletions or secrets discovered during investigation.
- Remind the user that the scripts were created but not executed.
