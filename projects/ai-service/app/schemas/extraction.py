from __future__ import annotations

from typing import Any

from pydantic import BaseModel, Field


class ExtractInput(BaseModel):
    """The normalised contract every channel adapter produces (LI-01)."""

    raw_text: str
    source_channel: str
    source_type: str  # "shared" | "individual"
    tenant_id: str
    conversation_id: str | None = None
    is_forwarded: bool = False


class ExtractionResult(BaseModel):
    fields: dict[str, Any] = Field(default_factory=dict)
    overall_confidence: float = 0.0
    confidence_breakdown: dict[str, float] = Field(default_factory=dict)
    missing_fields: list[str] = Field(default_factory=list)
    ambiguous_fields: list[str] = Field(default_factory=list)
    prompt_version: str = "v1"
    ai_provider: str = "anthropic"
    model_version: str = "claude-haiku"
