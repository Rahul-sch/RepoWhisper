import unittest
from unittest.mock import patch

from fastapi.testclient import TestClient

import main


class FakeStore:
    def count(self):
        return 7


class APIContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        main.app.state.auth_token = "test-token"
        cls.client = TestClient(main.app)

    def test_health_is_available_without_authentication(self):
        with (
            patch("main.get_vector_store", return_value=FakeStore()),
            patch("main.is_whisper_available", return_value=True),
        ):
            response = self.client.get("/health")

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["status"], "healthy")
        self.assertEqual(response.json()["index_count"], 7)

    def test_protected_route_rejects_missing_token(self):
        response = self.client.get("/repos")
        self.assertEqual(response.status_code, 401)

    def test_protected_route_rejects_wrong_token(self):
        response = self.client.get("/repos", headers={"X-Auth-Token": "wrong"})
        self.assertEqual(response.status_code, 401)

    def test_request_validation_is_bounded_and_sanitized(self):
        response = self.client.post(
            "/search",
            headers={"X-Auth-Token": "test-token"},
            json={"query": "x" * 501, "top_k": 5},
        )
        self.assertEqual(response.status_code, 422)
        self.assertNotIn("Traceback", response.text)

    def test_index_patterns_reject_parent_traversal(self):
        response = self.client.post(
            "/index",
            headers={"X-Auth-Token": "test-token"},
            json={"mode": "smart", "repo_path": "/tmp/repo", "patterns": ["../*.py"]},
        )
        self.assertEqual(response.status_code, 422)


if __name__ == "__main__":
    unittest.main()
