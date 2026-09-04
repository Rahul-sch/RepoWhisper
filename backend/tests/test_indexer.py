import tempfile
import unittest
from pathlib import Path

from config import IndexMode
from indexer import discover_files


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


if __name__ == "__main__":
    unittest.main()
