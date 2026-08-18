"""Grounded matching and explanation pipeline for visible repository code."""

from __future__ import annotations

import asyncio
import json
import os
import re
import time
from typing import Any, Optional, Protocol

from pydantic import BaseModel, Field, model_validator


DECLARATION_PATTERN = re.compile(
    r"(?m)^\s*(?:(?:public|private|internal|protected|static|async|export)\s+)*"
    r"(?P<kind>def|func|function|class|struct|enum|protocol|actor|interface)\s+"
    r"(?P<name>[A-Za-z_][A-Za-z0-9_]*)"
)
IDENTIFIER_PATTERN = re.compile(r"\b[A-Za-z_][A-Za-z0-9_]{2,}\b")
IGNORED_IDENTIFIERS = {
    "actor", "async", "await", "class", "def", "else", "enum", "false",
    "func", "function", "guard", "import", "interface", "internal", "let",
    "none", "null", "private", "protocol", "public", "return", "static",
    "struct", "throw", "throws", "true", "var", "while",
}


class ExplainVisibleRequest(BaseModel):
    ocr_text: str = Field(default="", max_length=100_000)
    recent_transcript: str = Field(default="", max_length=50_000)
    selected_text: Optional[str] = Field(default=None, max_length=50_000)
    repo_id: Optional[str] = Field(default=None, max_length=100)
    visible_app: Optional[str] = Field(default=None, max_length=200)
    top_k_candidates: int = Field(default=5, ge=1, le=10)

    @model_validator(mode="after")
    def require_context(self) -> "ExplainVisibleRequest":
        if not any(
            value and value.strip()
            for value in (self.ocr_text, self.recent_transcript, self.selected_text)
        ):
            raise ValueError("OCR text, transcript, or selected text is required")
        return self


class MatchedSymbol(BaseModel):
    name: str
    kind: str
    repo_id: str
    file_path: str
    line_start: int
    line_end: int
    confidence: float


class Explanation(BaseModel):
    summary: str
    purpose: str
    purpose_is_inference: bool
    how_it_works: list[str]
    inputs: list[str]
    outputs: list[str]
    side_effects: list[str]
    dependencies: list[str]
    callers: list[str]
    risks_and_questions: list[str]


class SourceReference(BaseModel):
    file_path: str
    line_start: int
    line_end: int
    reason: str


class ExplainVisibleResponse(BaseModel):
    matched_symbol: Optional[MatchedSymbol] = None
    candidate_symbols: list[MatchedSymbol] = Field(default_factory=list)
    explanation: Optional[Explanation] = None
    sources: list[SourceReference] = Field(default_factory=list)
    transcript_context_used: bool = False
    latency_ms: float


class ExplanationContext(BaseModel):
    matched_symbol: MatchedSymbol
    primary_code: str
    related_code: list[str]
    imports_and_dependencies: list[str]
    likely_callers: list[str]
    recent_transcript: Optional[str] = None


class ExplanationProvider(Protocol):
    async def generate(self, context: ExplanationContext) -> Explanation: ...


class ExplanationProviderError(RuntimeError):
    """Provider is unavailable, failed, or returned invalid structured output."""


class SourceAccessDenied(RuntimeError):
    """An indexed source path no longer passes the active allowlist."""


def extract_identifiers(text: str) -> list[str]:
    """Return declaration names first, then other unique code identifiers."""
    if not text:
        return []

    ordered: list[str] = []
    seen: set[str] = set()
    for match in DECLARATION_PATTERN.finditer(text):
        name = match.group("name")
        if name not in seen:
            ordered.append(name)
            seen.add(name)
    for name in IDENTIFIER_PATTERN.findall(text):
        if name.lower() in IGNORED_IDENTIFIERS or name in seen:
            continue
        ordered.append(name)
        seen.add(name)
    return ordered[:200]


def parse_provider_json(raw: str) -> Explanation:
    """Parse the provider's strict JSON response without accepting prose fallback."""
    cleaned = raw.strip()
    if cleaned.startswith("```"):
        cleaned = re.sub(r"^```(?:json)?\s*", "", cleaned)
        cleaned = re.sub(r"\s*```$", "", cleaned)
    try:
        return Explanation.model_validate(json.loads(cleaned))
    except Exception as exc:
        raise ExplanationProviderError("Explanation provider returned invalid structured JSON") from exc


class GroqExplanationProvider:
    """Explicitly configured OpenAI-compatible Groq provider."""

    def __init__(self, api_key: str, model: str):
        import openai

        self.client = openai.OpenAI(
            base_url="https://api.groq.com/openai/v1",
            api_key=api_key,
        )
        self.model = model

    async def generate(self, context: ExplanationContext) -> Explanation:
        prompt = (
            "Explain the matched symbol using only the supplied repository context. "
            "Do not invent intent, callers, side effects, or dependencies. Mark purpose "
            "as an inference unless directly documented. Return only JSON matching these "
            "keys: summary, purpose, purpose_is_inference, how_it_works, inputs, outputs, "
            "side_effects, dependencies, callers, risks_and_questions.\n\n"
            + context.model_dump_json()
        )

        def request() -> str:
            response = self.client.chat.completions.create(
                model=self.model,
                messages=[
                    {"role": "system", "content": "You are a grounded code explainer."},
                    {"role": "user", "content": prompt},
                ],
                temperature=0.1,
                max_tokens=1200,
                response_format={"type": "json_object"},
            )
            return response.choices[0].message.content or ""

        return parse_provider_json(await asyncio.to_thread(request))


def get_explanation_provider() -> Optional[ExplanationProvider]:
    """Cloud access is opt-in; a key alone never enables source transmission."""
    provider_name = os.getenv("REPOWHISPER_EXPLANATION_PROVIDER", "").strip().lower()
    if not provider_name:
        return None
    if provider_name != "groq":
        raise ExplanationProviderError(f"Unsupported explanation provider: {provider_name}")
    api_key = os.getenv("GROQ_API_KEY", "").strip()
    if not api_key:
        raise ExplanationProviderError(
            "Groq is selected but GROQ_API_KEY is not configured."
        )
    model = os.getenv("REPOWHISPER_EXPLANATION_MODEL", "openai/gpt-oss-120b")
    try:
        return GroqExplanationProvider(api_key=api_key, model=model)
    except Exception as exc:
        raise ExplanationProviderError(
            "The configured explanation provider could not be initialized."
        ) from exc


def _value(row: Any, key: str, default: Any = None) -> Any:
    if isinstance(row, dict):
        return row.get(key, default)
    return getattr(row, key, default)


def _kind_name(kind: str) -> str:
    return "function" if kind in {"def", "func", "function"} else kind


class ExplainVisibleService:
    def __init__(
        self,
        store: Any,
        path_validator: Any,
        provider: Optional[ExplanationProvider],
        provider_timeout_seconds: float = 20.0,
    ):
        self.store = store
        self.path_validator = path_validator
        self.provider = provider
        self.provider_timeout_seconds = provider_timeout_seconds

    async def explain(
        self,
        request: ExplainVisibleRequest,
        user_id: str,
    ) -> ExplainVisibleResponse:
        started = time.perf_counter()
        identifiers, confidence_by_identifier = self._ranked_identifiers(request)
        rows = self.store.list_chunks(
            user_id=user_id,
            repo_id=request.repo_id,
            limit=5000,
        )
        candidates = self._exact_candidates(
            rows,
            identifiers,
            confidence_by_identifier,
        )

        if not candidates:
            query = "\n".join(
                part for part in (
                    request.selected_text,
                    request.ocr_text,
                    request.recent_transcript,
                ) if part
            )[:4000]
            semantic_rows, _ = self.store.search(
                query=query,
                user_id=user_id,
                repo_id=request.repo_id,
                top_k=request.top_k_candidates,
            )
            candidates = self._semantic_candidates(semantic_rows)
            rows = [*rows, *semantic_rows]

        candidates = candidates[:request.top_k_candidates]
        if not candidates:
            return ExplainVisibleResponse(
                candidate_symbols=[],
                transcript_context_used=bool(request.recent_transcript.strip()),
                latency_ms=(time.perf_counter() - started) * 1000,
            )

        if self._requires_selection(candidates, request.repo_id):
            return ExplainVisibleResponse(
                candidate_symbols=candidates,
                transcript_context_used=bool(request.recent_transcript.strip()),
                latency_ms=(time.perf_counter() - started) * 1000,
            )

        matched = candidates[0]
        try:
            self.path_validator.validate_path(matched.file_path)
        except PermissionError as exc:
            raise SourceAccessDenied(
                "The matched source is no longer inside an approved repository."
            ) from exc

        context, sources = self._build_context(
            matched=matched,
            rows=rows,
            recent_transcript=request.recent_transcript,
        )
        if self.provider is None:
            raise ExplanationProviderError(
                "Explanation provider is not configured. Set "
                "REPOWHISPER_EXPLANATION_PROVIDER=groq and GROQ_API_KEY, then restart. "
                "Only retrieved repository context will be sent."
            )

        try:
            explanation = await asyncio.wait_for(
                self.provider.generate(context),
                timeout=self.provider_timeout_seconds,
            )
        except asyncio.TimeoutError as exc:
            raise ExplanationProviderError("Explanation provider timed out. Try again.") from exc
        except ExplanationProviderError:
            raise
        except Exception as exc:
            raise ExplanationProviderError("Explanation provider failed. Try again.") from exc

        return ExplainVisibleResponse(
            matched_symbol=matched,
            explanation=explanation,
            sources=sources,
            transcript_context_used=bool(request.recent_transcript.strip()),
            latency_ms=(time.perf_counter() - started) * 1000,
        )

    def _ranked_identifiers(
        self,
        request: ExplainVisibleRequest,
    ) -> tuple[list[str], dict[str, float]]:
        ordered: list[str] = []
        confidence: dict[str, float] = {}
        for text, score in (
            (request.selected_text or "", 0.99),
            (request.ocr_text, 0.95),
            (request.recent_transcript, 0.91),
        ):
            for identifier in extract_identifiers(text):
                if identifier not in confidence:
                    ordered.append(identifier)
                    confidence[identifier] = score
        return ordered, confidence

    def _exact_candidates(
        self,
        rows: list[Any],
        identifiers: list[str],
        confidence: dict[str, float],
    ) -> list[MatchedSymbol]:
        identifier_set = set(identifiers)
        found: dict[tuple[str, str, int, str], MatchedSymbol] = {}
        for row in rows:
            content = str(_value(row, "content", ""))
            base_line = int(_value(row, "line_start", 1))
            for declaration in DECLARATION_PATTERN.finditer(content):
                name = declaration.group("name")
                if name not in identifier_set:
                    continue
                line = base_line + content[:declaration.start()].count("\n")
                symbol = MatchedSymbol(
                    name=name,
                    kind=_kind_name(declaration.group("kind")),
                    repo_id=str(_value(row, "repo_id", "")),
                    file_path=str(_value(row, "file_path", "")),
                    line_start=line,
                    line_end=int(_value(row, "line_end", line)),
                    confidence=confidence[name],
                )
                found[(symbol.repo_id, symbol.file_path, symbol.line_start, name)] = symbol
        priority = {name: index for index, name in enumerate(identifiers)}
        return sorted(
            found.values(),
            key=lambda item: (-item.confidence, priority.get(item.name, 999), item.file_path),
        )

    def _semantic_candidates(self, rows: list[Any]) -> list[MatchedSymbol]:
        candidates: list[MatchedSymbol] = []
        for row in rows:
            content = str(_value(row, "content", ""))
            declaration = DECLARATION_PATTERN.search(content)
            if declaration is None:
                continue
            raw_score = float(_value(row, "score", 0.5))
            confidence = max(0.45, min(0.89, raw_score))
            base_line = int(_value(row, "line_start", 1))
            line = base_line + content[:declaration.start()].count("\n")
            candidates.append(MatchedSymbol(
                name=declaration.group("name"),
                kind=_kind_name(declaration.group("kind")),
                repo_id=str(_value(row, "repo_id", "")),
                file_path=str(_value(row, "file_path", "")),
                line_start=line,
                line_end=int(_value(row, "line_end", line)),
                confidence=confidence,
            ))
        return candidates

    def _requires_selection(
        self,
        candidates: list[MatchedSymbol],
        repo_id: Optional[str],
    ) -> bool:
        if len(candidates) < 2:
            return False
        first, second = candidates[0], candidates[1]
        return (
            repo_id is None
            and first.name == second.name
            and abs(first.confidence - second.confidence) < 0.08
        ) or (first.confidence < 0.7 and abs(first.confidence - second.confidence) < 0.1)

    def _build_context(
        self,
        matched: MatchedSymbol,
        rows: list[Any],
        recent_transcript: str,
    ) -> tuple[ExplanationContext, list[SourceReference]]:
        scoped_rows = [
            row for row in rows
            if str(_value(row, "repo_id", "")) == matched.repo_id
        ]
        primary = next(
            row for row in scoped_rows
            if str(_value(row, "file_path", "")) == matched.file_path
            and matched.name in str(_value(row, "content", ""))
        )
        primary_code = str(_value(primary, "content", ""))[:20_000]
        dependencies = [
            line.strip() for line in primary_code.splitlines()[:100]
            if line.lstrip().startswith(("import ", "from ", "use ", "#include"))
        ][:20]

        call_rows = [
            row for row in scoped_rows
            if str(_value(row, "file_path", "")) != matched.file_path
            and re.search(rf"\b{re.escape(matched.name)}\s*\(", str(_value(row, "content", "")))
        ][:5]
        callers = [
            f"{_value(row, 'file_path')}:{_value(row, 'line_start', 1)}-{_value(row, 'line_end', 1)}"
            for row in call_rows
        ]
        related = [str(_value(row, "content", ""))[:4000] for row in call_rows]

        sources = [SourceReference(
            file_path=matched.file_path,
            line_start=matched.line_start,
            line_end=matched.line_end,
            reason="Primary implementation",
        )]
        for row in call_rows:
            path = str(_value(row, "file_path", ""))
            try:
                self.path_validator.validate_path(path)
            except PermissionError:
                continue
            sources.append(SourceReference(
                file_path=path,
                line_start=int(_value(row, "line_start", 1)),
                line_end=int(_value(row, "line_end", 1)),
                reason="Likely call site",
            ))

        return ExplanationContext(
            matched_symbol=matched,
            primary_code=primary_code,
            related_code=related,
            imports_and_dependencies=dependencies,
            likely_callers=callers,
            recent_transcript=recent_transcript.strip()[:4000] or None,
        ), sources
