import tempfile
import unittest
from unittest.mock import patch

from indexer import CodeChunk
from search import VectorStore


def vector(first):
    return [first] + [0.0] * 383


class VectorStoreTests(unittest.TestCase):
    def setUp(self):
        self.temporary_directory = tempfile.TemporaryDirectory()
        self.store = VectorStore(self.temporary_directory.name)

    def tearDown(self):
        self.temporary_directory.cleanup()

    def test_replace_repo_preserves_other_repository(self):
        repo_a = [CodeChunk("/a/one.py", "alpha", 1, 1, "file")]
        repo_b = [CodeChunk("/b/one.py", "beta", 1, 1, "file")]
        replacement = [CodeChunk("/a/two.py", "new alpha", 1, 1, "file")]
        with patch("search.embed_batch", side_effect=lambda texts: [vector(1.0) for _ in texts]):
            self.store.replace_repo(repo_a, "local", "repo-a")
            self.store.replace_repo(repo_b, "local", "repo-b")
            self.store.replace_repo(replacement, "local", "repo-a")

        self.assertEqual(self.store.count_repo("local", "repo-a"), 1)
        self.assertEqual(self.store.count_repo("local", "repo-b"), 1)
        self.assertEqual(self.store.count(), 2)
        self.assertEqual(self.store.list_chunks("local", "repo-a")[0]["file_path"], "/a/two.py")

    def test_search_filters_repository_before_returning_results(self):
        chunks = [
            CodeChunk("/a/one.py", "alpha", 1, 1, "file"),
            CodeChunk("/b/one.py", "beta", 1, 1, "file"),
        ]
        with patch("search.embed_batch", return_value=[vector(1.0), vector(-1.0)]):
            self.store.replace_repo([chunks[0]], "local", "repo-a")
            self.store.replace_repo([chunks[1]], "local", "repo-b")
        with patch("search.embed_text", return_value=vector(1.0)):
            results, _ = self.store.search("alpha", "local", repo_id="repo-a")

        self.assertEqual([result.repo_id for result in results], ["repo-a"])
        self.assertEqual(results[0].file_path, "/a/one.py")

    def test_failed_embedding_does_not_delete_existing_repo(self):
        original = [CodeChunk("/a/one.py", "alpha", 1, 1, "file")]
        with patch("search.embed_batch", return_value=[vector(1.0)]):
            self.store.replace_repo(original, "local", "repo-a")
        with patch("search.embed_batch", side_effect=RuntimeError("model failed")):
            with self.assertRaises(RuntimeError):
                self.store.replace_repo(original, "local", "repo-a")

        self.assertEqual(self.store.count_repo("local", "repo-a"), 1)


if __name__ == "__main__":
    unittest.main()
