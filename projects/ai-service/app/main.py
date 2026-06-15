from fastapi import FastAPI

from app.api.routes import classify, embed, extract

app = FastAPI(title="QuoteAssist AI / extraction service", version="0.1.0")


@app.get("/health")
async def health() -> dict[str, str]:
    return {"status": "ok", "service": "quote-assist-ai"}


app.include_router(extract.router, prefix="/v1", tags=["extraction"])
app.include_router(classify.router, prefix="/v1", tags=["classification"])
app.include_router(embed.router, prefix="/v1", tags=["embeddings"])
