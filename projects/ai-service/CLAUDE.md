# CLAUDE.md — ai-service (Python/FastAPI)

The AI / extraction plane. Owns extraction, model routing, RAG and confidence
behind the versioned `extract / embed / classify` contract. The Elixir platform
never embeds model logic — it calls this service (§8.1). Read the root `CLAUDE.md`
first.

## Layout

```
app/
├── main.py            # FastAPI app: /health + /v1/{extract,classify,embed}
├── api/routes/        # extract.py, classify.py, embed.py
├── models/            # ModelClient adapters (base.py, claude.py) + router.py
├── prompts/           # AX-02 prompt loader + versioning
├── schemas/           # AX-03 pydantic / json-schema validation
├── confidence/        # VC-03 confidence calculator
├── rag/               # LR embeddings + pgvector similarity (R2)
└── core/              # config, logging, cache, telemetry
```

## Contract is law

Request/response shapes live in `../shared/contracts/` (JSON Schema). Validate
inbound `ExtractInput` and outbound `ExtractionResult` against them — that file is
the single source of truth shared with the platform. Model/prompt/RAG changes stay
inside this service and must not change the contract.

## Conventions

- **Anthropic-first.** Default to the latest Claude models (Haiku/Sonnet) via the
  complexity router (`models/router.py`); GPT-4o / Gemini / local are fallbacks.
- `temperature = 0`, JSON output, bounded tokens; reject output that fails schema
  validation (§9.1). Bounded concurrency (≤5 AI calls).
- Per-field + overall confidence with an auditable breakdown.

## Status

R1 implements `extract` (+ scaffolds for `classify`/`embed`); RAG is enabled in
R2. Phase 5 wires this service to the platform via a Phoenix Channel for streaming.

## Commands

```sh
pip install -e ".[dev]"
uvicorn app.main:app --reload --port 8000   # or: make ai (from repo root)
ruff check . && mypy app && pytest -q
```
