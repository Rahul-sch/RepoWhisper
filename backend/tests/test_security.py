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
