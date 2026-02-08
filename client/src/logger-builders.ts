import type { ExceptionData, LogEntry, Severity as SeverityType } from '@logger/shared';
import { parseStackTrace } from './stack-parser.js';

// ─── Base fields ─────────────────────────────────────────────────────

export function baseFields(
  sessionId: string,
  app: string,
  environment: string,
  severity: SeverityType,
  section?: string,
  groupId?: string,
): LogEntry {
  return {
    id: crypto.randomUUID(),
    timestamp: new Date().toISOString(),
    session_id: sessionId,
    severity,
    type: 'text',
    application: { name: app, environment },
    ...(section ? { section } : {}),
    ...(groupId ? { group_id: groupId } : {}),
  };
}

// ─── Text / error ────────────────────────────────────────────────────

export function buildTextEntry(
  base: LogEntry,
  message: string,
  tags?: Record<string, string>,
): LogEntry {
  return { ...base, type: 'text', text: message, ...(tags ? { tags } : {}) };
}

export function buildErrorException(err: Error): ExceptionData {
  return {
    type: err.constructor.name,
    message: err.message,
    ...(err.stack ? { stackTrace: parseStackTrace(err.stack) } : {}),
    ...(err.cause instanceof Error
      ? {
          cause: {
            type: (err.cause as Error).constructor.name,
            message: (err.cause as Error).message,
            ...((err.cause as Error).stack
              ? { stackTrace: parseStackTrace((err.cause as Error).stack!) }
              : {}),
          },
        }
      : {}),
  };
}

// ─── Structured entries ──────────────────────────────────────────────

export function buildJsonEntry(base: LogEntry, data: unknown): LogEntry {
  return { ...base, type: 'json', json: data };
}

export function buildHtmlEntry(base: LogEntry, content: string): LogEntry {
  return { ...base, type: 'html', html: content };
}

export function buildBinaryEntry(base: LogEntry, data: Uint8Array): LogEntry {
  const b64 = Buffer.from(data).toString('base64');
  return { ...base, type: 'binary', binary: b64 };
}

// ─── Group ───────────────────────────────────────────────────────────

export function buildGroupOpenEntry(
  base: LogEntry,
  groupId: string,
  name: string,
  options?: { sticky?: boolean },
): LogEntry {
  return {
    ...base,
    type: 'group',
    group_id: groupId,
    group_action: 'open',
    group_label: name,
    ...(options?.sticky ? { sticky: true } : {}),
  };
}

export function buildGroupCloseEntry(
  base: LogEntry,
  groupId: string,
): LogEntry {
  return {
    ...base,
    type: 'group',
    group_id: groupId,
    group_action: 'close',
  };
}

// ─── Sticky actions ──────────────────────────────────────────────────

export function buildUnstickyEntry(
  base: LogEntry,
  groupId: string,
  entryId?: string,
): LogEntry {
  return {
    ...base,
    type: 'text',
    text: '',
    group_id: groupId,
    sticky_action: 'unpin',
    ...(entryId ? { id: entryId } : {}),
  };
}

// ─── State / Image / Custom ─────────────────────────────────────────

export function buildStateEntry(
  base: LogEntry,
  key: string,
  value: unknown,
): LogEntry {
  return { ...base, type: 'state', state_key: key, state_value: value };
}

export function buildImageEntry(
  base: LogEntry,
  data: Buffer | Uint8Array | string,
  mime: string,
  id?: string,
): LogEntry {
  const b64 =
    typeof data === 'string' ? data : Buffer.from(data).toString('base64');
  return {
    ...base,
    ...(id ? { id, replace: true } : {}),
    type: 'image',
    image: { data: b64, mimeType: mime },
  };
}

export function buildCustomEntry(
  base: LogEntry,
  type: string,
  data: unknown,
  options?: { id?: string; replace?: boolean },
): LogEntry {
  return {
    ...base,
    ...(options?.id ? { id: options.id } : {}),
    ...(options?.replace || options?.id ? { replace: true } : {}),
    type: 'custom',
    custom_type: type,
    custom_data: data,
  };
}

// ─── Utility ─────────────────────────────────────────────────────────

export function stringifyTags(
  meta: Record<string, unknown>,
): Record<string, string> {
  const tags: Record<string, string> = {};
  for (const [k, v] of Object.entries(meta)) {
    tags[k] = typeof v === 'string' ? v : JSON.stringify(v);
  }
  return tags;
}
