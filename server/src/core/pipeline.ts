import { LogEntry } from '@logger/shared';

export type PipelineResult =
  | { ok: true; entry: LogEntry; isLegacy: boolean }
  | { ok: false; error: string };

/**
 * Detect if raw data is a legacy LogRequest (has `payload` but no `type` field).
 */
function isLegacyLogRequest(raw: unknown): raw is {
  severity: string;
  payload: unknown;
  application?: { name: string; version?: string; sessionId?: string };
  exception?: { type?: string; message: string };
  request?: { generatedAt?: string; sentAt?: string };
} {
  if (typeof raw !== 'object' || raw === null) return false;
  const obj = raw as Record<string, unknown>;
  return 'payload' in obj && !('type' in obj);
}

/**
 * Convert a legacy LogRequest to a LogEntry.
 */
function convertLegacy(raw: {
  severity: string;
  payload: unknown;
  application?: { name: string; version?: string; sessionId?: string };
  exception?: { type?: string; message: string };
  request?: { generatedAt?: string; sentAt?: string };
}): Record<string, unknown> {
  const now = new Date().toISOString();
  const isTextPayload = typeof raw.payload === 'string';

  const entry: Record<string, unknown> = {
    id: crypto.randomUUID(),
    timestamp: now,
    session_id: raw.application?.sessionId ?? 'unknown',
    severity: raw.severity,
    type: isTextPayload ? 'text' : 'json',
  };

  if (isTextPayload) {
    entry.text = raw.payload;
  } else {
    entry.json = raw.payload;
  }

  if (raw.application) {
    entry.application = {
      name: raw.application.name,
      version: raw.application.version,
    };
  }

  if (raw.exception) {
    entry.exception = {
      type: raw.exception.type,
      message: raw.exception.message,
    };
  }

  if (raw.request?.generatedAt) {
    entry.generated_at = raw.request.generatedAt;
  }
  if (raw.request?.sentAt) {
    entry.sent_at = raw.request.sentAt;
  }

  return entry;
}

/**
 * Normalize a LogEntry: fill defaults for missing optional fields.
 */
function normalize(entry: LogEntry): LogEntry {
  const now = new Date().toISOString();
  const patched: Record<string, unknown> = { ...entry };

  if (!patched.generated_at) {
    patched.generated_at = now;
  }
  if (!patched.section) {
    patched.section = 'events';
  }

  return patched as LogEntry;
}

/**
 * Process raw input through the ingestion pipeline.
 *
 * Steps:
 * 1. Legacy detection & conversion
 * 2. Zod validation
 * 3. Normalization (fill defaults)
 */
export function processPipeline(raw: unknown): PipelineResult {
  let isLegacy = false;
  let data = raw;

  // Step 1: Legacy conversion
  if (isLegacyLogRequest(data)) {
    data = convertLegacy(data);
    isLegacy = true;
  }

  // Step 2: Validate with Zod
  const result = LogEntry.safeParse(data);
  if (!result.success) {
    const issues = result.error.issues.map(
      (i) => `${i.path.join('.')}: ${i.message}`
    );
    return { ok: false, error: `Validation failed: ${issues.join('; ')}` };
  }

  // Step 3: Normalize
  const entry = normalize(result.data);

  return { ok: true, entry, isLegacy };
}
