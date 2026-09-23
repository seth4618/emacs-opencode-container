#!/usr/bin/env python3
"""Regression tests for transparent session dump compression."""

import json
import importlib.util
import os
import stat
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest import mock

import session_files


CHECK_SCRIPT = Path(__file__).with_name("check-session-file.py")
CHECK_SPEC = importlib.util.spec_from_file_location("check_session_file", CHECK_SCRIPT)
check_session_file = importlib.util.module_from_spec(CHECK_SPEC)
CHECK_SPEC.loader.exec_module(check_session_file)


FAKE_BROTLI = """#!/usr/bin/env python3
import argparse
import lzma
import pathlib
import sys

if '--quality' in sys.argv or '--output' in sys.argv:
    sys.exit('value options must use --option=value syntax')
parser = argparse.ArgumentParser()
parser.add_argument('--decompress', action='store_true')
parser.add_argument('--stdout', action='store_true')
parser.add_argument('--quality')
parser.add_argument('--output')
parser.add_argument('source')
args = parser.parse_args()
data = pathlib.Path(args.source).read_bytes()
if args.decompress:
    sys.stdout.buffer.write(lzma.decompress(data))
else:
    pathlib.Path(args.output).write_bytes(lzma.compress(data))
"""


class SessionFilesTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)
        executable = self.root / "brotli"
        executable.write_text(FAKE_BROTLI)
        executable.chmod(executable.stat().st_mode | stat.S_IXUSR)
        self.path_patch = mock.patch.dict(
            os.environ, {"PATH": f"{self.root}{os.pathsep}{os.environ['PATH']}"}
        )
        self.path_patch.start()

    def tearDown(self):
        self.path_patch.stop()
        self.temporary.cleanup()

    def test_quality_11_compression_uses_standard_br_suffix(self):
        plain = self.root / "full-test.json"
        payload = {"info": {"id": "test"}, "messages": []}
        plain.write_text(json.dumps(payload))

        compressed = session_files.compress_if_large(plain, threshold=1)

        self.assertEqual(compressed, self.root / "full-test.json.br")
        self.assertFalse(plain.exists())
        with session_files.open_session_text(plain) as stream:
            self.assertEqual(json.load(stream), payload)

    def test_discovery_accepts_br_and_legacy_bt_without_duplicates(self):
        br_path = self.root / "full-br.json.br"
        bt_path = self.root / "full-bt.json.bt"
        plain_path = self.root / "full-plain.json"
        for path in (br_path, bt_path, plain_path):
            path.touch()
        # A plain file takes precedence if a compressed sibling also exists.
        (self.root / "full-plain.json.br").touch()

        self.assertEqual(
            session_files.session_dump_paths(self.root),
            [br_path, bt_path, plain_path],
        )

    def test_requested_legacy_name_can_resolve_standard_br_file(self):
        br_path = self.root / "full-test.json.br"
        br_path.touch()

        self.assertEqual(
            session_files.resolve_session_path(self.root / "full-test.json.bt"),
            br_path,
        )

    def test_check_removes_plain_file_when_compressed_copy_matches(self):
        plain = self.root / "session.json"
        plain.write_text('{"message": "same"}\n')
        session_files.compress_if_large(plain, threshold=1)
        plain.write_text('{"message": "same"}\n')

        self.assertEqual(check_session_file.check_session_file(plain), 0)

        self.assertFalse(plain.exists())
        self.assertTrue((self.root / "session.json.br").exists())
        self.assertFalse((self.root / "compressed-temp.json").exists())

    def test_check_keeps_different_files_and_runs_diff(self):
        plain = self.root / "session.json"
        plain.write_text('{"message": "compressed"}\n')
        session_files.compress_if_large(plain, threshold=1)
        plain.write_text('{"message": "plain"}\n')

        with mock.patch.object(
            check_session_file.subprocess, "run", wraps=subprocess.run
        ) as run:
            self.assertEqual(check_session_file.check_session_file(plain), 1)

        self.assertTrue(plain.exists())
        self.assertEqual(
            (self.root / "compressed-temp.json").read_text(),
            '{"message": "compressed"}\n',
        )
        self.assertEqual(run.call_args_list[-1].args[0][0], "diff")

    def test_check_compresses_large_file_without_compressed_sibling(self):
        plain = self.root / "session.json"
        plain.write_text('{"message": "large"}\n')

        self.assertEqual(check_session_file.check_session_file(plain, threshold=1), 0)

        self.assertFalse(plain.exists())
        self.assertTrue((self.root / "session.json.br").exists())

    def test_check_leaves_small_file_without_compressed_sibling(self):
        plain = self.root / "session.json"
        plain.write_text("{}")

        self.assertEqual(check_session_file.check_session_file(plain, threshold=2), 0)

        self.assertTrue(plain.exists())
        self.assertFalse((self.root / "session.json.br").exists())


if __name__ == "__main__":
    unittest.main()
