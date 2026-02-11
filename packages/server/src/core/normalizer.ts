import type {
    DataMessage,
    EventMessage,
    SessionMessage,
    StoredEntry,
} from '@logger/shared'

// ─── Normalizer ──────────────────────────────────────────────────────

function now(): string {
  return new Date().toISOString()
}

function baseEntry(sessionId: string): StoredEntry {
  const ts = now()
  return {
    id: crypto.randomUUID(),
    timestamp: ts,
    session_id: sessionId,
    kind: 'event',
    severity: 'info',
    message: null,
    tag: null,
    exception: null,
    parent_id: null,
    group_id: null,
    prev_id: null,
    next_id: null,
    widget: null,
    replace: false,
    icon: null,
    labels: null,
    generated_at: null,
    sent_at: null,
    key: null,
    value: undefined,
    override: true,
    display: 'default',
    session_action: null,
    application: null,
    metadata: null,
    received_at: ts,
  }
}

/** Normalize a SessionMessage → StoredEntry. */
export function normalizeSession(msg: SessionMessage, sessionId?: string): StoredEntry {
  return {
    ...baseEntry(sessionId ?? msg.session_id),
    kind: 'session',
    session_action: msg.action,
    application: msg.application ?? null,
    metadata: msg.metadata ?? null,
  }
}

/** Normalize an EventMessage → StoredEntry. */
export function normalizeEvent(msg: EventMessage, sessionId?: string): StoredEntry {
  const base = baseEntry(sessionId ?? msg.session_id)
  return {
    ...base,
    id: msg.id ?? base.id,
    kind: 'event',
    severity: msg.severity ?? 'info',
    message: msg.message ?? null,
    tag: msg.tag ?? null,
    exception: msg.exception ?? null,
    parent_id: msg.parent_id ?? null,
    group_id: msg.group_id ?? null,
    prev_id: msg.prev_id ?? null,
    next_id: msg.next_id ?? null,
    widget: msg.widget ?? null,
    replace: msg.replace ?? false,
    icon: msg.icon ?? null,
    labels: msg.labels ?? null,
    generated_at: msg.generated_at ?? null,
    sent_at: msg.sent_at ?? null,
  }
}

/** Normalize a DataMessage → StoredEntry. */
export function normalizeData(msg: DataMessage, sessionId?: string): StoredEntry {
  return {
    ...baseEntry(sessionId ?? msg.session_id),
    kind: 'data',
    key: msg.key,
    value: msg.value,
    override: msg.override ?? true,
    display: msg.display ?? 'default',
    widget: msg.widget ?? null,
    icon: msg.icon ?? null,
  }
}


