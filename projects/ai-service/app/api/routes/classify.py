from __future__ import annotations

from fastapi import APIRouter

from app.schemas.extraction import ExtractInput

router = APIRouter()


@router.post("/classify")
async def classify(payload: ExtractInput) -> dict:
    # TODO: rules-first, LLM-fallback category classification (LA-03).
    return {"category": None, "confidence": 0.0}
