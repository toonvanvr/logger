import { z } from 'zod'
import { DisplayLocation } from './data-message.js'
import { ExceptionData, IconRef, Severity } from './event-message.js'
import { ApplicationInfo } from './session-message.js'
import { WidgetPayload } from './widget.js'

// ─── EntryKind ───────────────────────────────────────────────────────

export const EntryKind = z.enum(['session', 'event', 'data'])

// ─── StoredEntry ─────────────────────────────────────────────────────

export const StoredEntry = z.object({
  /** Auto-generated or client-provided */
  id: z.string(),
  /** ISO 8601, server-assigned */
  timestamp: z.string().datetime({ offset: true }),
  session_id: z.string(),
  kind: EntryKind,
  severity: Severity.default('info'),

  // ── Event fields (null when kind ≠ event) ──
  message: z.string().nullable().default(null),
  tag: z.string().nullable().default(null),
  exception: ExceptionData.nullable().default(null),
  parent_id: z.string().nullable().default(null),
  group_id: z.string().nullable().default(null),
  prev_id: z.string().nullable().default(null),
  next_id: z.string().nullable().default(null),
  widget: WidgetPayload.nullable().default(null),
  replace: z.boolean().default(false),
  icon: IconRef.nullable().default(null),
  labels: z.record(z.string(), z.string()).nullable().default(null),
  generated_at: z.string().datetime({ offset: true }).nullable().default(null),
  sent_at: z.string().datetime({ offset: true }).nullable().default(null),

  // ── Data fields (null when kind ≠ data) ──
  key: z.string().nullable().default(null),
  value: z.unknown().optional(),
  override: z.boolean().default(true),
  display: DisplayLocation.default('default'),

  // ── Session fields (null when kind ≠ session) ──
  session_action: z.enum(['start', 'end', 'heartbeat']).nullable().default(null),
  application: ApplicationInfo.nullable().default(null),
  metadata: z.record(z.string(), z.unknown()).nullable().default(null),

  // ── Server-assigned ──
  received_at: z.string().datetime({ offset: true }),
})

export type StoredEntry = z.infer<typeof StoredEntry>
export type EntryKind = z.infer<typeof EntryKind>
