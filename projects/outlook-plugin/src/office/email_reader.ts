// Email reader (Phase 2). Reads the selected message via Office.js and normalises
// it toward the ExtractInput contract, including forwarded-email sender detection.
// Office types are loose here; @types/office-js is added during Phase 2 completion.

declare const Office: any;

export interface ReadEmail {
  itemId: string | null;
  conversationId: string | null;
  subject: string;
  from: string;
  body: string;
  attachments: Array<{ filename: string; content_type: string; size_bytes?: number }>;
  forwarded: boolean;
  forwardedFrom: string | null;
}

const FWD_SUBJECT = /^\s*(fw|fwd):/i;
const FWD_FROM = /From:\s*.*?([\w.+-]+@[\w-]+\.[\w.-]+)/i;

export async function readSelectedEmail(): Promise<ReadEmail> {
  const item = Office.context.mailbox.item;
  const subject: string = item.subject ?? "";
  const body: string = await getBody(item);
  const forwarded = FWD_SUBJECT.test(subject);

  return {
    itemId: item.itemId ?? null,
    conversationId: item.conversationId ?? null,
    subject,
    from: item.from?.emailAddress ?? "",
    body,
    attachments: (item.attachments ?? []).map((a: any) => ({
      filename: a.name,
      content_type: a.contentType,
      size_bytes: a.size,
    })),
    forwarded,
    forwardedFrom: forwarded ? extractForwardedSender(body) : null,
  };
}

function getBody(item: any): Promise<string> {
  return new Promise((resolve) => {
    item.body.getAsync("text", (result: any) => {
      resolve(result?.value ?? "");
    });
  });
}

export function extractForwardedSender(body: string): string | null {
  const match = body.match(FWD_FROM);
  return match ? match[1] : null;
}
