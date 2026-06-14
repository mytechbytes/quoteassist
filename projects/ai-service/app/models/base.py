from __future__ import annotations

from typing import Protocol

from app.schemas.extraction import ExtractInput, ExtractionResult


class ModelClient(Protocol):
    """Every AI provider sits behind this interface (AX-06).

    Swapping the active model is a configuration change, not a code change.
    """

    async def extract(self, prompt: str, payload: ExtractInput) -> ExtractionResult: ...
