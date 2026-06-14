// Boundary types mirroring projects/shared/contracts/*.json. Kept in sync by hand
// for now; a codegen step from the JSON Schemas can replace this later.

export type Channel = "email" | "webform" | "whatsapp" | "voice";
export type SourceType = "shared" | "individual";

export interface ExtractInput {
  correlation_id: string;
  tenant_id: string;
  channel: Channel;
  source_type: SourceType;
  sender_identity?: string;
  conversation_id?: string | null;
  subject?: string | null;
  content: string;
  locale?: string;
  received_at?: string;
  attachments?: Array<{ filename: string; content_type: string; size_bytes?: number }>;
  schema_version?: string;
  prompt_version?: string;
}

export interface ExtractionResult {
  correlation_id: string;
  fields: Record<string, unknown>;
  items?: Array<{ item_id: string } & Record<string, unknown>>;
  overall_confidence: number;
  confidence_breakdown?: Record<string, number>;
  missing_fields?: string[];
  ambiguous_fields?: string[];
  prompt_version: string;
  schema_version?: string;
  ai_provider?: string;
  model_version: string;
  latency_ms?: number;
}
