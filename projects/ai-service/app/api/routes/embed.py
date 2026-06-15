from __future__ import annotations

from fastapi import APIRouter
from pydantic import BaseModel

router = APIRouter()


class EmbedRequest(BaseModel):
    text: str


@router.post("/embed")
async def embed(payload: EmbedRequest) -> dict[str, object]:
    # TODO: text-embedding-3-small; used for RAG + historical-quote similarity.
    return {"embedding": [], "model": "text-embedding-3-small"}
