import json
import os
import tempfile
import unittest
from pathlib import Path

from path_validator import PathValidator


class PathValidatorTests(unittest.TestCase):
    def setUp(self):
        self.temporary_directory = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary_directory.name)
        self.repo_a = self.root / "repo-a"
        self.repo_b = self.root / "repo-b"
        self.repo_a.mkdir()
        self.repo_b.mkdir()
        self.allowlist = self.root / "allowlist.json"
        self.write_allowlist([self.repo_a])

    def tearDown(self):
        self.temporary_directory.cleanup()

    def write_allowlist(self, paths):
        temporary = self.allowlist.with_suffix(".tmp")
        temporary.write_text(json.dumps([str(path) for path in paths]), encoding="utf-8")
        os.replace(temporary, self.allowlist)

    def test_reloads_added_repository(self):
        validator = PathValidator(str(self.allowlist))
        self.assertFalse(validator.is_path_allowed(str(self.repo_b)))

        self.write_allowlist([self.repo_a, self.repo_b])

        self.assertTrue(validator.is_path_allowed(str(self.repo_b)))

    def test_reloads_removed_repository(self):
        validator = PathValidator(str(self.allowlist))
        self.assertTrue(validator.is_path_allowed(str(self.repo_a)))

        self.write_allowlist([])

        self.assertFalse(validator.is_path_allowed(str(self.repo_a)))

    def test_missing_allowlist_fails_closed_after_startup(self):
        validator = PathValidator(str(self.allowlist))
        self.allowlist.unlink()
        self.assertEqual(validator.allowed_paths, [])
        self.assertFalse(validator.is_path_allowed(str(self.repo_a)))

    def test_path_must_belong_to_selected_repository(self):
        self.write_allowlist([self.repo_a, self.repo_b])
        validator = PathValidator(str(self.allowlist))
        file_in_b = self.repo_b / "secret.py"
        file_in_b.write_text("secret = True", encoding="utf-8")

        with self.assertRaises(PermissionError):
            validator.validate_path_within(str(file_in_b), str(self.repo_a))


if __name__ == "__main__":
    unittest.main()
