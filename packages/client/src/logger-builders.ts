import type { QueuedMessage } from './logger-types.js'

// ─── Severity type ───────────────────────────────────────────────────

export type Severity = 'debug' | 'info' | 'warning' | 'error' | 'critical'

// ─── Base fields ─────────────────────────────────────────────────────

export function baseFields(
  sessionId: string,
  _app: string,
  _environment: string,
  severity: Severity,
  tag?: string,
  groupId?: string,
): QueuedMessage {
  return {
    kind: 'event',
    session_id: sessionId,
    id: crypto.randomUUID(),
    severity,
    generated_at: new Date().toISOString(),
    ...(tag ? { tag } : {}),
    ...(groupId ? { group_id: groupId } : {}),
  }
}

// ─── Text / error ────────────────────────────────────────────────────

export function buildTextEntry(
  base: QueuedMessage,
  message: string,
  labels?: Record<string, string>,
): QueuedMessage {
  return { ...base, message, ...(labels ? { labels } : {}) }
}

export function buildErrorException(err: Error): Record<string, unknown> {
  return {
    type: err.constructor.name,
    message: err.message,
    ...(err.stack ? { stack_trace: err.stack } : {}),
    handled: true,
    ...(err.cause instanceof Error
      ? { inner: buildErrorException(err.cause as Error) }
      : {}),
  }
}

// ─── Structured entries ──────────────────────────────────────────────

export function buildJsonEntry(base: QueuedMessage, data: unknown): QueuedMessage {
  return { ...base, widget: { type: 'json', data } }
}

export function buildHtmlEntry(base: QueuedMessage, content: string): QueuedMessage {
  return { ...base, widget: { type: 'html', content } }
}

export function buildBinaryEntry(base: QueuedMessage, data: Uint8Array): QueuedMessage {
  const b64 = Buffer.from(data).toString('base64')
  return { ...base, widget: { type: 'binary', data: b64, encoding: 'base64' } }
}

// ─── Group ───────────────────────────────────────────────────────────

export function buildGroupOpenEntry(
  base: QueuedMessage,
  groupId: string,
  name: string,
  _options?: { sticky?: boolean },
): QueuedMessage {
  return {
    ...base,
    id: groupId,
    message: name,
    group_id: groupId,
  }
}

export function buildGroupCloseEntry(
  base: QueuedMessage,
  groupId: string,
): QueuedMessage {
  return {
    ...base,
    group_id: groupId,
    message: '',
  }
}

// ─── Sticky actions ──────────────────────────────────────────────────

export function buildUnstickyEntry(
  base: QueuedMessage,
  groupId: string,
  entryId?: string,
): QueuedMessage {
  return {
    ...base,
    message: '',
    group_id: groupId,
    labels: { _sticky_action: 'unpin' },
    ...(entryId ? { id: entryId } : {}),
  }
}

// ─── State (→ DataMessage) ───────────────────────────────────────────

export function buildStateEntry(
  base: QueuedMessage,
  key: string,
  value: unknown,
): QueuedMessage {
  return {
    kind: 'data',
    session_id: base.session_id as string,
    key,
    value,
    override: true,
    display: 'default',
  }
}

// ─── Image ───────────────────────────────────────────────────────────

export function buildImageEntry(
  base: QueuedMessage,
  data: Buffer | Uint8Array | string,
  mime: string,
  id?: string,
): QueuedMessage {
  const b64 =
    typeof data === 'string' ? data : Buffer.from(data).toString('base64')
  return {
    ...base,
    ...(id ? { id, replace: true } : {}),
    widget: { type: 'image', data: b64, mime_type: mime },
  }
}

// ─── Custom (→ EventMessage with widget) ─────────────────────────────

export function buildCustomEntry(
  base: QueuedMessage,
  type: string,
  data: unknown,
  options?: { id?: string; replace?: boolean },
): QueuedMessage {
  return {
    ...base,
    ...(options?.id ? { id: options.id } : {}),
    ...(options?.replace || options?.id ? { replace: true } : {}),
    widget: { type, ...(data && typeof data === 'object' ? data : { data }) },
  }
}

// ─── HTTP Request ────────────────────────────────────────────────────

export function buildHttpEntry(
  base: QueuedMessage,
  data: {
    method: string
    url: string
    status?: number
    duration_ms?: number
    request_headers?: Record<string, string>
    response_headers?: Record<string, string>
    request_body?: string
    response_body?: string
    request_id?: string
    started_at?: string
  },
): QueuedMessage {
  const contentType = data.response_headers?.['content-type']
    ?? data.response_headers?.['Content-Type']
  const isError = data.status != null ? data.status >= 400 : undefined

  return buildCustomEntry(base, 'http_request', {
    method: data.method,
    url: data.url,
    ...(data.request_headers ? { request_headers: data.request_headers } : {}),
    ...(data.request_body ? { request_body: data.request_body } : {}),
    ...(data.response_headers ? { response_headers: data.response_headers } : {}),
    ...(data.response_body ? { response_body: data.response_body } : {}),
    ...(data.status != null ? { status: data.status } : {}),
    ...(data.duration_ms != null ? { duration_ms: data.duration_ms } : {}),
    ...(data.request_id ? { request_id: data.request_id } : {}),
    started_at: data.started_at ?? new Date().toISOString(),
    ...(contentType ? { content_type: contentType } : {}),
    ...(isError != null ? { is_error: isError } : {}),
  })
}

// ─── Utility ─────────────────────────────────────────────────────────

export function stringifyTags(
  meta: Record<string, unknown>,
): Record<string, string> {
  const tags: Record<string, string> = {}
  for (const [k, v] of Object.entries(meta)) {
    tags[k] = typeof v === 'string' ? v : JSON.stringify(v)
  }
  return tags
}
