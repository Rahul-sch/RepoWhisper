import tempfile
import unittest
from pathlib import Path

from config import IndexMode
from indexer import chunk_file, discover_files


class IndexerDiscoveryTests(unittest.TestCase):
    def test_binary_file_with_supported_extension_is_not_discovered(self):
        with tempfile.TemporaryDirectory() as temporary:
            repo = Path(temporary)
            binary = repo / "payload.py"
            binary.write_bytes(b"print('prefix')\x00binary")

            self.assertNotIn(str(binary.resolve()), discover_files(str(repo), IndexMode.FULL))

    def test_oversized_file_is_not_discovered(self):
        with tempfile.TemporaryDirectory() as temporary:
            repo = Path(temporary)
            oversized = repo / "generated.py"
            oversized.write_bytes(b"x" * (2 * 1024 * 1024 + 1))

            self.assertNotIn(str(oversized.resolve()), discover_files(str(repo), IndexMode.FULL))

    def test_symlinked_file_outside_repo_is_not_discovered(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            repo = root / "repo"
            outside = root / "outside"
            repo.mkdir()
            outside.mkdir()
            (repo / "inside.py").write_text("inside = True", encoding="utf-8")
            secret = outside / "secret.py"
            secret.write_text("secret = True", encoding="utf-8")
            (repo / "linked.py").symlink_to(secret)

            discovered = discover_files(str(repo), IndexMode.FULL)

            self.assertIn(str((repo / "inside.py").resolve()), discovered)
            self.assertNotIn(str(secret.resolve()), discovered)

    def test_manual_mode_applies_binary_and_size_safety_checks(self):
        with tempfile.TemporaryDirectory() as temporary:
            repo = Path(temporary)
            valid = repo / "valid.py"
            binary = repo / "binary.py"
            oversized = repo / "oversized.py"
            valid.write_text("value = 1", encoding="utf-8")
            binary.write_bytes(b"value = 1\x00secret")
            oversized.write_bytes(b"x" * (2 * 1024 * 1024 + 1))

            discovered = discover_files(
                str(repo),
                IndexMode.MANUAL,
                [str(valid), str(binary), str(oversized)],
            )

            self.assertEqual(discovered, [str(valid.resolve())])

    def test_guided_discovery_is_unique_and_deterministic(self):
        with tempfile.TemporaryDirectory() as temporary:
            repo = Path(temporary)
            first = repo / "a.py"
            second = repo / "b.py"
            first.write_text("a = 1", encoding="utf-8")
            second.write_text("b = 1", encoding="utf-8")

            discovered = discover_files(str(repo), IndexMode.GUIDED, ["*.py", "a.*"])

            self.assertEqual(discovered, [str(first.resolve()), str(second.resolve())])

    def test_forced_chunk_split_preserves_line_ranges(self):
        with tempfile.TemporaryDirectory() as temporary:
            source = Path(temporary) / "long.py"
            source.write_text("\n".join(["abcdefghij"] * 8), encoding="utf-8")

            chunks = chunk_file(str(source), max_chunk_size=20)

            self.assertGreater(len(chunks), 1)
            for previous, current in zip(chunks, chunks[1:]):
                self.assertEqual(current.line_start, previous.line_end + 1)
            self.assertEqual(chunks[0].line_start, 1)
            self.assertEqual(chunks[-1].line_end, 8)


if __name__ == "__main__":
    unittest.main()
