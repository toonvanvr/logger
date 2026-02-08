import { z } from 'zod';
import { ApplicationInfo, LogEntry, SessionAction } from './log-entry';

// ─── Server Message Types ────────────────────────────────────────────

export const ServerMessageType = z.enum([
  'ack',
  'error',
  'log',
  'logs',
  'rpc_request',
  'rpc_response',
  'session_list',
  'session_update',
  'state_snapshot',
  'history',
  'subscribe_ack',
]);
export type ServerMessageType = z.infer<typeof ServerMessageType>;

// ─── Session Info (used in session_list) ─────────────────────────────

export const SessionInfo = z.object({
  session_id: z.string(),
  application: ApplicationInfo,
  started_at: z.string().datetime({ offset: true }),
  last_heartbeat: z.string().datetime({ offset: true }),
  is_active: z.boolean(),
  log_count: z.number().int(),
  color_index: z.number().int(),
});
export type SessionInfo = z.infer<typeof SessionInfo>;

// ─── Server Message ──────────────────────────────────────────────────

export const ServerMessage = z.object({
  type: ServerMessageType,

  // ── For type: "ack" ──
  /** IDs of acknowledged log entries */
  ack_ids: z.array(z.string()).optional(),

  // ── For type: "error" ──
  error_code: z.string().optional(),
  error_message: z.string().optional(),
  /** The ID of the log entry that caused the error */
  error_entry_id: z.string().optional(),

  // ── For type: "log" ──
  entry: LogEntry.optional(),

  // ── For type: "logs" ──
  entries: z.array(LogEntry).optional(),

  // ── For type: "rpc_request" / "rpc_response" ──
  rpc_id: z.string().uuid().optional(),
  rpc_method: z.string().optional(),
  rpc_args: z.unknown().optional(),
  rpc_response: z.unknown().optional(),
  rpc_error: z.string().optional(),

  // ── For type: "session_list" ──
  sessions: z.array(SessionInfo).optional(),

  // ── For type: "session_update" ──
  session_id: z.string().optional(),
  session_action: SessionAction.optional(),
  application: ApplicationInfo.optional(),

  // ── For type: "state_snapshot" ──
  state: z.record(z.string(), z.unknown()).optional(),

  // ── For type: "history" ──
  query_id: z.string().optional(),
  history_entries: z.array(LogEntry).optional(),
  has_more: z.boolean().optional(),
  cursor: z.string().optional(),
  /** Which backend served this response */
  source: z.enum(['buffer', 'store']).optional(),
  /** ISO 8601 server timestamp when query was executed (for dedup) */
  fence_ts: z.string().datetime({ offset: true }).optional(),
});
export type ServerMessage = z.infer<typeof ServerMessage>;
