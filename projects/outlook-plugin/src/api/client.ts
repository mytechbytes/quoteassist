// Typed API client for the QuoteAssist platform (CC). Adds a correlation id and
// bearer token to every request and normalises errors. Mirrors the LiveView app's
// server-side calls; the add-in talks to the same /api/v1 surface.

import type { ExtractInput, ExtractionResult } from "../types/contracts";

export interface ApiError {
  status: number;
  error: string;
  message: string;
}

export class ApiClient {
  private baseUrl: string;
  private getToken: () => Promise<string>;

  constructor(baseUrl: string, getToken: () => Promise<string>) {
    this.baseUrl = baseUrl.replace(/\/$/, "");
    this.getToken = getToken;
  }

  async extract(input: ExtractInput): Promise<ExtractionResult> {
    return this.request<ExtractionResult>("POST", "/api/v1/extract", input, input.correlation_id);
  }

  private async request<T>(
    method: string,
    path: string,
    body: unknown,
    correlationId: string,
  ): Promise<T> {
    const token = await this.getToken();

    const res = await fetch(`${this.baseUrl}${path}`, {
      method,
      headers: {
        "content-type": "application/json",
        authorization: `Bearer ${token}`,
        "x-correlation-id": correlationId,
      },
      body: body === undefined ? undefined : JSON.stringify(body),
    });

    if (!res.ok) {
      const detail = (await res.json().catch(() => ({}))) as Partial<ApiError>;
      const err: ApiError = {
        status: res.status,
        error: detail.error ?? "request_failed",
        message: detail.message ?? res.statusText,
      };
      throw err;
    }

    return (await res.json()) as T;
  }
}

export function newCorrelationId(): string {
  return crypto.randomUUID();
}
