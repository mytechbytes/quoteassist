from __future__ import annotations

from app.schemas.extraction import ExtractInput, ExtractionResult


class ClaudeClient:
    """Anthropic Claude adapter (Haiku / Sonnet). Stub."""

    def __init__(self, model: str = "claude-haiku") -> None:
        self.model = model

    async def extract(self, prompt: str, payload: ExtractInput) -> ExtractionResult:
        # TODO: call the Anthropic API with temperature 0 and JSON output.
        return ExtractionResult(ai_provider="anthropic", model_version=self.model)
