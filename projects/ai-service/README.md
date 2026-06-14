# QuoteAssist — AI / extraction service (Python)

The AI plane. Exposes a small, versioned contract the Elixir platform calls:
`extract`, `classify`, `embed`. All model logic — prompt versioning, complexity
routing, fallback chain, RAG enrichment, confidence scoring — lives here so the
platform never embeds it (see §8.1).

- **Stack:** FastAPI · Pydantic · httpx · Anthropic / Azure OpenAI SDKs · jsonschema · pgvector (via the platform DB)

## Develop
```bash
python -m venv .venv && source .venv/bin/activate
pip install -e ".[dev]"
uvicorn app.main:app --reload --port 8000
# http://localhost:8000/docs
```

## Endpoints
| Method | Path          | Purpose                                  |
|--------|---------------|------------------------------------------|
| GET    | `/health`     | Liveness                                 |
| POST   | `/v1/extract` | Structured requirement + confidence (AX) |
| POST   | `/v1/classify`| Category classification (LA-03)          |
| POST   | `/v1/embed`   | Embeddings for RAG / similarity (LR)     |
