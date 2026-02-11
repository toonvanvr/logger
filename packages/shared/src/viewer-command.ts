import { z } from 'zod'
import { Severity } from './event-message'

// ─── ViewerCommand (discriminated union) ─────────────────────────────

export const ViewerCommand = z.discriminatedUnion('type', [
  z.object({
    type: z.literal('subscribe'),
    session_ids: z.array(z.string()).optional(),
    min_severity: Severity.optional(),
    tags: z.array(z.string()).optional(),
    text_filter: z.string().optional(),
  }),
  z.object({
    type: z.literal('unsubscribe'),
    session_ids: z.array(z.string()).optional(),
  }),
  z.object({
    type: z.literal('history'),
    query_id: z.string(),
    from: z.string().datetime({ offset: true }).optional(),
    to: z.string().datetime({ offset: true }).optional(),
    session_id: z.string().optional(),
    search: z.string().optional(),
    limit: z.number().int().min(1).max(10000).optional(),
    cursor: z.string().optional(),
    source: z.enum(['buffer', 'store', 'auto']).optional(),
  }),
  z.object({
    type: z.literal('rpc_request'),
    rpc_id: z.string(),
    target_session_id: z.string(),
    method: z.string(),
    args: z.unknown().optional(),
  }),
  z.object({
    type: z.literal('session_list'),
  }),
  z.object({
    type: z.literal('data_query'),
    session_id: z.string(),
  }),
])

export type ViewerCommand = z.infer<typeof ViewerCommand>
