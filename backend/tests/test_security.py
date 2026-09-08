import base64
import os
import tempfile
import json
import unittest
from io import BytesIO
from pathlib import Path
from unittest.mock import patch, Mock

from fastapi.testclient import TestClient
from PIL import Image
import main
from advise import BossModeAdvisor, process_screenshot
from path_validator import PathValidator
from indexer import chunk_file


class SecurityTests(unittest.TestCase):
    def test_chunker_rejects_binary_content(self):
        with tempfile.TemporaryDirectory() as root:
            source = Path(root) / "sample.py"
            source.write_bytes(b"print('hello')\x00secret")
            self.assertEqual(chunk_file(str(source)), [])

    def test_invalid_paths_fail_closed(self):
        with tempfile.TemporaryDirectory() as root:
            allowlist = Path(root) / "allowlist.json"
            allowlist.write_text(json.dumps([root]))
            validator = PathValidator(str(allowlist))
            for value in [None, 7, "", "relative", root + "/nul\x00"]:
                self.assertFalse(validator.is_path_allowed(value))

    def test_relative_allowlist_root_is_rejected(self):
        with tempfile.TemporaryDirectory() as root:
            allowlist = Path(root) / "allowlist.json"
            allowlist.write_text(json.dumps(["relative/project"]))
            with self.assertRaises(ValueError):
                PathValidator(str(allowlist))

    def test_pixel_bomb_is_rejected_before_decode(self):
        fake = Mock(width=5000, height=5000, format="PNG")
        with patch("advise.Image.open", return_value=fake):
            with self.assertRaises(ValueError):
                process_screenshot(b"fake")
        fake.thumbnail.assert_not_called()

    def test_tall_screenshot_is_bounded(self):
        encoded = BytesIO()
        Image.new("RGB", (10, 3000)).save(encoded, format="PNG")
        result = Image.open(BytesIO(base64.b64decode(process_screenshot(encoded.getvalue()))))
        self.assertLessEqual(max(result.size), 1024)

    def test_gif_screenshot_is_rejected(self):
        encoded = BytesIO()
        Image.new("RGB", (2, 2)).save(encoded, format="GIF")
        with self.assertRaises(ValueError):
            process_screenshot(encoded.getvalue())

    def test_advisor_network_work_is_bounded(self):
        with patch.dict(os.environ, {"GROQ_API_KEY": "test", "REPOWHISPER_ADVISOR_PROVIDER": "groq"}):
            with patch("advise.openai.OpenAI") as client:
                BossModeAdvisor()
        self.assertEqual(client.call_args.kwargs["timeout"], 20.0)
        self.assertEqual(client.call_args.kwargs["max_retries"], 0)

    def test_api_key_alone_cannot_enable_external_advice(self):
        with patch.dict(os.environ, {"GROQ_API_KEY": "test", "REPOWHISPER_ADVISOR_PROVIDER": ""}):
            with patch("advise.openai.OpenAI") as client:
                advisor = BossModeAdvisor()
        client.assert_not_called()
        self.assertIsNone(advisor.client)

    def test_clear_index_requires_a_string_path(self):
        response = self.client.post("/clear_index", headers=self.headers, json={"repo_path": ["unexpected"]})
        self.assertEqual(response.status_code, 422)

    def test_negative_request_length_is_rejected(self):
        response = self.client.post("/search", headers={**self.headers, "Content-Length": "-1"}, content=b"{}")
        self.assertEqual(response.status_code, 400)

    def test_actual_oversize_is_rejected(self):
        response = self.client.post("/search", headers=self.headers, content=b"x" * (2 * 1024 * 1024 + 1))
        self.assertEqual(response.status_code, 413)

    def test_declared_oversize_is_rejected(self):
        response = self.client.post("/search", headers={**self.headers, "Content-Length": "9999999"}, content=b"{}")
        self.assertEqual(response.status_code, 413)

    def test_errors_are_not_cacheable(self):
        response = self.client.get("/repos")
        self.assertEqual(response.headers["cache-control"], "no-store")
        self.assertEqual(response.headers["x-content-type-options"], "nosniff")

    def test_browser_origin_is_denied(self):
        response = self.client.get("/health", headers={"Origin": "https://example.com"})
        self.assertEqual(response.status_code, 403)

    def test_oversized_authentication_is_rejected(self):
        response = self.client.get("/repos", headers={"X-Auth-Token": "x" * 513})
        self.assertEqual(response.status_code, 401)

    def test_duplicate_authentication_is_rejected(self):
        response = self.client.get("/repos", headers=[("X-Auth-Token", "security-test-token"), ("X-Auth-Token", "security-test-token")])
        self.assertEqual(response.status_code, 401)

    def setUp(self):
        main.app.state.auth_token = "security-test-token"
        self.client = TestClient(main.app)
        self.headers = {"X-Auth-Token": "security-test-token"}

    def tearDown(self):
        self.client.close()

    def test_validation_does_not_echo_sensitive_input(self):
        secret = "PRIVATE-SOURCE-" * 60
        response = self.client.post("/search", headers=self.headers, json={"query": secret})
        self.assertEqual(response.status_code, 422)
        self.assertNotIn("PRIVATE-SOURCE", response.text)
