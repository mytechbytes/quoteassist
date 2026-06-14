from __future__ import annotations

from app.schemas.extraction import ExtractInput


def route_model(payload: ExtractInput) -> str:
    """Route each request to the cheapest capable model (AX-05)."""
    text = payload.raw_text or ""
    if len(text) < 300:
        return "claude-haiku"
    # TODO: detect multi-itinerary / ambiguous dates / non-English -> top tier (gpt-4o)
    return "claude-sonnet"
