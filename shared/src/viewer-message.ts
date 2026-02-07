import { z } from 'zod';
import { Severity } from './log-entry';

// ─── Viewer Message Types ────────────────────────────────────────────

export const ViewerMessageType = z.enum([
  'subscribe',
  'unsubscribe',
  'history_query',
  'rpc_request',
  'session_list',
  'state_query',
]);
export type ViewerMessageType = z.infer<typeof ViewerMessageType>;

// ─── Viewer Message ──────────────────────────────────────────────────

export const ViewerMessage = z.object({
  type: ViewerMessageType,

  // ── For type: "subscribe" / "unsubscribe" ──
  /** Which session IDs to subscribe to. Empty = all. */
  session_ids: z.array(z.string()).optional(),
  /** Minimum severity filter */
  min_severity: Severity.optional(),
  /** Section filter */
  sections: z.array(z.string()).optional(),
  /** Text search filter (applied server-side) */
  text_filter: z.string().optional(),

  // ── For type: "history_query" ──
  query_id: z.string().optional(),
  /** ISO 8601 start time */
  from: z.string().datetime({ offset: true }).optional(),
  /** ISO 8601 end time */
  to: z.string().datetime({ offset: true }).optional(),
  /** Session ID filter for history */
  session_id: z.string().optional(),
  /** Text search within history */
  search: z.string().optional(),
  /** Max number of entries to return */
  limit: z.number().int().min(1).max(10000).optional(),
  /** Pagination cursor from previous response */
  cursor: z.string().optional(),

  // ── For type: "rpc_request" ──
  rpc_id: z.string().uuid().optional(),
  /** Target session to send the RPC to */
  target_session_id: z.string().optional(),
  rpc_method: z.string().optional(),
  rpc_args: z.unknown().optional(),

  // ── For type: "state_query" ──
  /** Session to get state for */
  state_session_id: z.string().optional(),
});
export type ViewerMessage = z.infer<typeof ViewerMessage>;
