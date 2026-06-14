from __future__ import annotations

from fastapi import APIRouter

from app.models.router import route_model
from app.schemas.extraction import ExtractInput, ExtractionResult

router = APIRouter()


@router.post("/extract", response_model=ExtractionResult)
async def extract(payload: ExtractInput) -> ExtractionResult:
    model = route_model(payload)
    # TODO: compose the versioned prompt (+RAG few-shot), call the routed
    # ModelClient, validate against the active JSON schema, score confidence.
    return ExtractionResult(model_version=model)
