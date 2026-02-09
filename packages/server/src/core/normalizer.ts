import type { LogEntry } from '@logger/shared'
import type {
  DataMessage,
  EventMessage,
  SessionMessage,
  StoredEntry,
} from '@logger/shared/src/v2/index.ts'

// ─── Normalizer ──────────────────────────────────────────────────────
// Converts v2 input messages and v1 LogEntry to unified StoredEntry.

function now(): string {
  return new Date().toISOString()
}

/** Normalize a v2 SessionMessage → StoredEntry. */
export function normalizeSession(msg: SessionMessage): StoredEntry {
  const ts = now()
  return {
    id: crypto.randomUUID(),
    timestamp: ts,
    session_id: msg.session_id,
    kind: 'session',
    severity: 'info',
    // Event fields
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
    // Data fields
    key: null,
    value: undefined,
    override: true,
    display: 'default',
    // Session fields
    session_action: msg.action,
    application: msg.application ?? null,
    metadata: msg.metadata ?? null,
    // Server-assigned
    received_at: ts,
  }
}

/** Normalize a v2 EventMessage → StoredEntry. */
export function normalizeEvent(msg: EventMessage): StoredEntry {
  const ts = now()
  return {
    id: msg.id ?? crypto.randomUUID(),
    timestamp: ts,
    session_id: msg.session_id,
    kind: 'event',
    severity: msg.severity ?? 'info',
    // Event fields
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
    // Data fields
    key: null,
    value: undefined,
    override: true,
    display: 'default',
    // Session fields
    session_action: null,
    application: null,
    metadata: null,
    // Server-assigned
    received_at: ts,
  }
}

/** Normalize a v2 DataMessage → StoredEntry. */
export function normalizeData(msg: DataMessage): StoredEntry {
  const ts = now()
  return {
    id: crypto.randomUUID(),
    timestamp: ts,
    session_id: msg.session_id,
    kind: 'data',
    severity: 'info',
    // Event fields
    message: null,
    tag: null,
    exception: null,
    parent_id: null,
    group_id: null,
    prev_id: null,
    next_id: null,
    widget: msg.widget ?? null,
    replace: false,
    icon: msg.icon ?? null,
    labels: null,
    generated_at: null,
    sent_at: null,
    // Data fields
    key: msg.key,
    value: msg.value,
    override: msg.override ?? true,
    display: msg.display ?? 'default',
    // Session fields
    session_action: null,
    application: null,
    metadata: null,
    // Server-assigned
    received_at: ts,
  }
}

/** Normalize a v1 LogEntry → StoredEntry (backward compat). */
export function normalizeV1(entry: LogEntry): StoredEntry {
  const ts = now()
  const kind = entry.type === 'session'
    ? 'session' as const
    : 'event' as const

  return {
    id: entry.id,
    timestamp: entry.timestamp,
    session_id: entry.session_id,
    kind,
    severity: entry.severity ?? 'info',
    // Event fields
    message: entry.text ?? null,
    tag: entry.section ?? null,
    exception: entry.exception ?? null,
    parent_id: entry.parent_id ?? null,
    group_id: null,
    prev_id: null,
    next_id: null,
    widget: null,
    replace: entry.replace ?? false,
    icon: entry.icon ?? null,
    labels: entry.tags ?? null,
    generated_at: entry.generated_at ?? null,
    sent_at: entry.sent_at ?? null,
    // Data fields
    key: null,
    value: undefined,
    override: true,
    display: 'default',
    // Session fields
    session_action: entry.session_action ?? null,
    application: entry.application ?? null,
    metadata: null,
    // Server-assigned
    received_at: ts,
  }
}
