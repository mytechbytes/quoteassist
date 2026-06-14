# Shared contracts

The **only** thing the two runtimes agree on: the request/response shapes at the
service boundary between the Elixir platform plane and the Python AI service
(§8.1, §20). Swapping models, prompts or RAG behaviour never changes these.

| Schema                              | Direction                  | Used by                          |
| ----------------------------------- | -------------------------- | -------------------------------- |
| `extract-input.schema.json`         | platform → ai-service      | normalised intake (`ExtractInput`) |
| `extraction-result.schema.json`     | ai-service → platform      | `/extract` response              |
| `pricing-request.schema.json`       | platform → pricing source  | `PricingRequest`                 |
| `pricing-response.schema.json`      | pricing source → platform  | `PricingResponse`                |

- JSON Schema **draft 2020-12**.
- The Elixir `extraction/` context is a thin client to the Python `ai-service`;
  it validates payloads against these schemas at the boundary.
- The Python service validates inbound `ExtractInput` and its own
  `ExtractionResult` output against the same files (single source of truth).
- Versioned config (prompt/schema versions) is referenced by id inside payloads;
  see `extraction_schemas` / `prompt_templates` in the platform (PF-10).
