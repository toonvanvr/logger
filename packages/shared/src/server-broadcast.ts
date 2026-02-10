import { z } from 'zod'
import { DisplayLocation, WidgetConfig } from './data-message.js'
import { IconRef } from './event-message.js'
import { ApplicationInfo } from './session-message.js'
import { StoredEntry } from './stored-entry.js'

// ─── Sub-schemas ─────────────────────────────────────────────────────

export const SessionInfo = z.object({
  session_id: z.string(),
  application: ApplicationInfo,
  started_at: z.string().datetime({ offset: true }),
  last_heartbeat: z.string().datetime({ offset: true }),
  is_active: z.boolean(),
  log_count: z.number().int(),
  color_index: z.number().int(),
})

export const DataState = z.object({
  value: z.unknown(),
  history: z.array(z.unknown()),
  display: DisplayLocation,
  widget: WidgetConfig.optional(),
  label: z.string().optional(),
  icon: IconRef.optional(),
  updated_at: z.string().datetime({ offset: true }),
})

// ─── ServerBroadcast (discriminated union) ───────────────────────────

export const ServerBroadcast = z.discriminatedUnion('type', [
  z.object({ type: z.literal('event'), entry: StoredEntry }),
  z.object({
    type: z.literal('data_update'),
    session_id: z.string(),
    key: z.string(),
    value: z.unknown().optional(),
    display: DisplayLocation.optional(),
    widget: WidgetConfig.optional(),
  }),
  z.object({
    type: z.literal('session_update'),
    session_id: z.string(),
    action: z.enum(['start', 'end', 'heartbeat']),
    application: ApplicationInfo.optional(),
  }),
  z.object({
    type: z.literal('session_list'),
    sessions: z.array(SessionInfo),
  }),
  z.object({
    type: z.literal('data_snapshot'),
    session_id: z.string(),
    data: z.record(z.string(), DataState),
  }),
  z.object({
    type: z.literal('history'),
    query_id: z.string(),
    entries: z.array(StoredEntry),
    has_more: z.boolean(),
    cursor: z.string().optional(),
    source: z.enum(['buffer', 'store']),
    fence_ts: z.string().datetime({ offset: true }).optional(),
  }),
  z.object({ type: z.literal('ack'), ids: z.array(z.string()) }),
  z.object({
    type: z.literal('error'),
    code: z.string(),
    message: z.string(),
    entry_id: z.string().optional(),
  }),
  z.object({ type: z.literal('subscribe_ack') }),
  z.object({
    type: z.literal('rpc_request'),
    rpc_id: z.string(),
    method: z.string(),
    args: z.unknown().optional(),
  }),
  z.object({
    type: z.literal('rpc_response'),
    rpc_id: z.string(),
    result: z.unknown().optional(),
    error: z.string().optional(),
  }),
])

export type ServerBroadcast = z.infer<typeof ServerBroadcast>
export type SessionInfo = z.infer<typeof SessionInfo>
export type DataState = z.infer<typeof DataState>
