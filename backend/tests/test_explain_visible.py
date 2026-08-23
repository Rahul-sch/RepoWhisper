import asyncio
import json
import unittest

from pydantic import ValidationError

from explain_visible import (
    ExplainVisibleRequest,
    ExplainVisibleService,
    Explanation,
    ExplanationProviderError,
    SourceAccessDenied,
    parse_provider_json,
)


def chunk(repo_id, path, content, line_start=1, line_end=20, score=0.8):
    return {
        "repo_id": repo_id,
        "file_path": path,
        "content": content,
        "line_start": line_start,
        "line_end": line_end,
        "chunk_type": "function",
        "score": score,
    }


class FakeStore:
    def __init__(self, chunks, semantic=None):
        self.chunks = chunks
        self.semantic = semantic or []

    def list_chunks(self, user_id, repo_id=None, limit=5000):
        del user_id, limit
        return [row for row in self.chunks if repo_id is None or row["repo_id"] == repo_id]

    def search(self, query, user_id, repo_id=None, top_k=5):
        del query, user_id, top_k
        rows = [row for row in self.semantic if repo_id is None or row["repo_id"] == repo_id]
        return rows, 1.0


class FakeValidator:
    def __init__(self, allowed_prefix="/approved/"):
        self.allowed_prefix = allowed_prefix

    def validate_path(self, path):
        if not path.startswith(self.allowed_prefix):
            raise PermissionError("Path not in allowlist")
        return path


class FakeProvider:
    def __init__(self, error=None, delay=0):
        self.error = error
        self.delay = delay
        self.contexts = []

    async def generate(self, context):
        self.contexts.append(context)
        if self.delay:
            await asyncio.sleep(self.delay)
        if self.error:
            raise self.error
        return Explanation(
            summary="Calculates the visible result.",
            purpose="It appears to centralize the calculation.",
            purpose_is_inference=True,
            how_it_works=["Reads the input", "Returns the computed value"],
            inputs=["value"],
            outputs=["computed value"],
            side_effects=[],
            dependencies=["helper"],
            callers=["caller"],
            risks_and_questions=["Confirm behavior for negative values"],
        )


class ExplainVisibleServiceTests(unittest.IsolatedAsyncioTestCase):
    def make_service(self, rows, semantic=None, provider=None, timeout=0.2):
        return ExplainVisibleService(
            store=FakeStore(rows, semantic),
            path_validator=FakeValidator(),
            provider=provider or FakeProvider(),
            provider_timeout_seconds=timeout,
        )

    async def test_exact_identifier_matching(self):
        service = self.make_service([
            chunk("repo-a", "/approved/a/orbit.py", "def calculate_orbital_latency(value):\n    return value * 2")
        ])
        response = await service.explain(
            ExplainVisibleRequest(ocr_text="calculate_orbital_latency(value)"),
            user_id="local",
        )
        self.assertEqual(response.matched_symbol.name, "calculate_orbital_latency")
        self.assertGreaterEqual(response.matched_symbol.confidence, 0.9)

    async def test_semantic_fallback(self):
        semantic = [
            chunk("repo-a", "/approved/a/cache.py", "def invalidate_cache_entry(key):\n    pass", score=0.77)
        ]
        service = self.make_service([], semantic=semantic)
        response = await service.explain(
            ExplainVisibleRequest(ocr_text="remove the stale cached value"),
            user_id="local",
        )
        self.assertEqual(response.matched_symbol.name, "invalidate_cache_entry")
        self.assertLess(response.matched_symbol.confidence, 0.9)

    async def test_repository_isolation(self):
        rows = [
            chunk("repo-a", "/approved/a/math.py", "def calculate_total():\n    return 'A'"),
            chunk("repo-b", "/approved/b/math.py", "def calculate_total():\n    return 'B'"),
        ]
        service = self.make_service(rows)
        response = await service.explain(
            ExplainVisibleRequest(ocr_text="calculate_total", repo_id="repo-b"),
            user_id="local",
        )
        self.assertEqual(response.matched_symbol.repo_id, "repo-b")
        self.assertEqual(len(response.candidate_symbols), 0)

    async def test_multiple_low_confidence_candidates_require_selection(self):
        rows = [
            chunk("repo-a", "/approved/a/math.py", "def calculate_total():\n    return 'A'"),
            chunk("repo-b", "/approved/b/math.py", "def calculate_total():\n    return 'B'"),
        ]
        response = await self.make_service(rows).explain(
            ExplainVisibleRequest(ocr_text="calculate_total"),
            user_id="local",
        )
        self.assertIsNone(response.matched_symbol)
        self.assertIsNone(response.explanation)
        self.assertEqual(len(response.candidate_symbols), 2)

    async def test_missing_ocr_uses_transcript(self):
        rows = [chunk("repo-a", "/approved/a/parser.py", "def parse_manifest():\n    pass")]
        response = await self.make_service(rows).explain(
            ExplainVisibleRequest(ocr_text="", recent_transcript="Let's inspect parse_manifest"),
            user_id="local",
        )
        self.assertEqual(response.matched_symbol.name, "parse_manifest")
        self.assertTrue(response.transcript_context_used)

    async def test_valid_ocr_does_not_require_transcript(self):
        rows = [chunk("repo-a", "/approved/a/parser.py", "def parse_manifest():\n    pass")]
        response = await self.make_service(rows).explain(
            ExplainVisibleRequest(ocr_text="parse_manifest"),
            user_id="local",
        )
        self.assertEqual(response.matched_symbol.name, "parse_manifest")
        self.assertFalse(response.transcript_context_used)

    def test_empty_request_validation(self):
        with self.assertRaises(ValidationError):
            ExplainVisibleRequest(ocr_text="", recent_transcript="", selected_text=None)

    def test_payload_size_validation(self):
        with self.assertRaises(ValidationError):
            ExplainVisibleRequest(ocr_text="x" * 100_001)

    async def test_disallowed_indexed_path_is_rejected(self):
        rows = [chunk("repo-a", "/private/secret.py", "def secret_function():\n    pass")]
        with self.assertRaises(SourceAccessDenied):
            await self.make_service(rows).explain(
                ExplainVisibleRequest(ocr_text="secret_function"),
                user_id="local",
            )

    def test_structured_explanation_parsing(self):
        raw = json.dumps({
            "summary": "Does work.",
            "purpose": "Appears to coordinate work.",
            "purpose_is_inference": True,
            "how_it_works": ["Validates input"],
            "inputs": ["value"],
            "outputs": ["result"],
            "side_effects": [],
            "dependencies": [],
            "callers": [],
            "risks_and_questions": ["What owns retries?"],
        })
        self.assertEqual(parse_provider_json(raw).summary, "Does work.")

    async def test_provider_failure_and_timeout_are_actionable(self):
        rows = [chunk("repo-a", "/approved/a/work.py", "def do_work():\n    pass")]
        failing = self.make_service(rows, provider=FakeProvider(error=RuntimeError("down")))
        with self.assertRaisesRegex(ExplanationProviderError, "failed"):
            await failing.explain(ExplainVisibleRequest(ocr_text="do_work"), "local")

        timing_out = self.make_service(rows, provider=FakeProvider(delay=0.1), timeout=0.01)
        with self.assertRaisesRegex(ExplanationProviderError, "timed out"):
            await timing_out.explain(ExplainVisibleRequest(ocr_text="do_work"), "local")

    async def test_no_source_leakage_between_repositories(self):
        provider = FakeProvider()
        rows = [
            chunk("repo-a", "/approved/a/shared.py", "def shared_name():\n    return 'allowed'"),
            chunk("repo-b", "/approved/b/shared.py", "def shared_name():\n    return 'SECRET_OTHER_REPO'"),
        ]
        service = self.make_service(rows, provider=provider)
        await service.explain(
            ExplainVisibleRequest(ocr_text="shared_name", repo_id="repo-a"),
            user_id="local",
        )
        serialized_context = json.dumps(provider.contexts[0].model_dump())
        self.assertNotIn("SECRET_OTHER_REPO", serialized_context)


if __name__ == "__main__":
    unittest.main()
