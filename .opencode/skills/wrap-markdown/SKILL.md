---
name: wrap-markdown
description: Wrap or reflow Markdown files with this repository's scripts/wrap-md.py formatter. Use when asked to word-wrap, reflow, or enforce a maximum line length in one or more Markdown files, including requests that specify a custom wrap width.
---

# Wrap Markdown

Use the repository formatter rather than manually reflowing Markdown. Resolve it from the
repository root so the skill works from any subdirectory:

```bash
repo_root="$(git rev-parse --show-toplevel)"
wrapper="$repo_root/scripts/wrap-md.py"
test -x "$wrapper"
```

## Choose the operation

- Use the default width of 120 unless the user specifies a width.
- To preview the wrapped content on standard output, pass one file:

  ```bash
  "$wrapper" input.md
  "$wrapper" -w 80 input.md
  ```

- To write to a distinct output file, pass the input followed by the output:

  ```bash
  "$wrapper" input.md output.md
  "$wrapper" -w 80 input.md output.md
  ```

- To replace an input file, never assume that the formatter safely accepts the same input and
  output path. Write beside the input first, then replace its contents only after the formatter
  succeeds:

  ```bash
  input="path/to/file.md"
  width=120
  tmp="$(mktemp "${input}.wrap.XXXXXX")"
  trap 'rm -f -- "$tmp"' EXIT
  "$wrapper" -w "$width" "$input" "$tmp"
  cat -- "$tmp" > "$input"
  rm -f -- "$tmp"
  trap - EXIT
  ```

Use a positive integer for a requested width. Quote every path. For multiple files, process each
file independently so a failure does not overwrite files that have not yet been formatted.

## Verify the result

Inspect `git diff -- <file>...` for tracked files. Confirm that only wrapping changed and report
the width used and the files written. If `scripts/wrap-md.py` is absent or not executable, stop
and report that prerequisite instead of substituting another formatter.
