#!/usr/bin/env python3
"""Shared helpers for transparently reading and compressing session dumps."""

import contextlib
import os
import subprocess
import tempfile
from pathlib import Path


COMPRESSED_SUFFIX = ".bt"
COMPRESSION_THRESHOLD = 45 * 1024 * 1024


def logical_path(path):
    """Return the uncompressed name represented by *path*."""
    path = Path(path)
    return path.with_suffix("") if path.suffix == COMPRESSED_SUFFIX else path


def resolve_session_path(path):
    """Resolve either spelling of a dump, preferring an existing plain file."""
    path = Path(path)
    if path.exists():
        return path
    alternate = (
        logical_path(path)
        if path.suffix == COMPRESSED_SUFFIX
        else Path(f"{path}{COMPRESSED_SUFFIX}")
    )
    return alternate if alternate.exists() else path


@contextlib.contextmanager
def open_session_text(path):
    """Open a plain or Brotli-compressed session as a text stream."""
    resolved = resolve_session_path(path)
    if resolved.suffix != COMPRESSED_SUFFIX:
        with resolved.open("r", encoding="utf-8") as handle:
            yield handle
        return

    process = subprocess.Popen(
        ["brotli", "--decompress", "--stdout", str(resolved)],
        stdout=subprocess.PIPE,
        text=True,
        encoding="utf-8",
    )
    try:
        yield process.stdout
    finally:
        if process.stdout:
            process.stdout.close()
        return_code = process.wait()
        if return_code:
            raise OSError(f"brotli could not decompress {resolved} (exit {return_code})")


@contextlib.contextmanager
def materialized_session(path):
    """Yield a real JSON path, temporarily decompressing when necessary."""
    resolved = resolve_session_path(path)
    if resolved.suffix != COMPRESSED_SUFFIX:
        yield resolved
        return

    logical = logical_path(resolved)
    with tempfile.NamedTemporaryFile(
        prefix=f"{logical.stem}-", suffix=logical.suffix, delete=False
    ) as temporary:
        temporary_path = Path(temporary.name)
        result = subprocess.run(
            ["brotli", "--decompress", "--stdout", str(resolved)],
            stdout=temporary,
            check=False,
        )
    try:
        if result.returncode:
            raise OSError(f"brotli could not decompress {resolved} (exit {result.returncode})")
        yield temporary_path
    finally:
        temporary_path.unlink(missing_ok=True)


def compress_if_large(path, threshold=COMPRESSION_THRESHOLD):
    """Replace a dump larger than *threshold* with a quality-11 .bt file."""
    path = Path(path)
    if path.stat().st_size <= threshold:
        Path(f"{path}{COMPRESSED_SUFFIX}").unlink(missing_ok=True)
        return path

    compressed = Path(f"{path}{COMPRESSED_SUFFIX}")
    temporary = Path(f"{compressed}.tmp")
    try:
        subprocess.run(
            ["brotli", "--quality", "11", "--output", str(temporary), str(path)],
            check=True,
        )
        os.replace(temporary, compressed)
        path.unlink()
    finally:
        temporary.unlink(missing_ok=True)
    return compressed


def session_dump_paths(directory):
    """List logical full-*.json dumps once, including compressed dumps."""
    paths = {}
    for path in Path(directory).glob("full-*.json"):
        paths[logical_path(path)] = path
    for path in Path(directory).glob(f"full-*.json{COMPRESSED_SUFFIX}"):
        paths.setdefault(logical_path(path), path)
    return [paths[key] for key in sorted(paths)]
