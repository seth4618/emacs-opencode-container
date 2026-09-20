#!/usr/bin/env python3
"""Reconcile a JSON session file with its Brotli-compressed sibling."""

import argparse
import filecmp
import subprocess
from pathlib import Path

from session_files import COMPRESSION_THRESHOLD, compress_if_large


def parse_args():
    parser = argparse.ArgumentParser(
        description="Remove duplicate session JSON or compress a large uncompressed session."
    )
    parser.add_argument("session_file", type=Path, help="session file ending in .json")
    return parser.parse_args()


def check_session_file(session_file, threshold=COMPRESSION_THRESHOLD):
    """Reconcile *session_file* and return the status a CLI should use."""
    if session_file.suffix != ".json":
        raise ValueError(f"session file must end in .json: {session_file}")
    if not session_file.is_file():
        raise FileNotFoundError(f"session file does not exist: {session_file}")

    compressed = Path(f"{session_file}.br")
    if not compressed.exists():
        compress_if_large(session_file, threshold=threshold)
        return 0

    decompressed = session_file.with_name("compressed-temp.json")
    with decompressed.open("wb") as output:
        subprocess.run(
            ["brotli", "--decompress", "--stdout", str(compressed)],
            stdout=output,
            check=True,
        )

    if filecmp.cmp(session_file, decompressed, shallow=False):
        session_file.unlink()
        decompressed.unlink()
        return 0

    return subprocess.run(
        ["diff", "--", str(session_file), str(decompressed)], check=False
    ).returncode


def main():
    args = parse_args()
    try:
        return check_session_file(args.session_file)
    except (FileNotFoundError, ValueError) as exc:
        raise SystemExit(str(exc)) from exc


if __name__ == "__main__":
    raise SystemExit(main())
