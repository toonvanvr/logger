import { z } from 'zod'
import { MAX_TEXT_SIZE } from './constants'
import { WidgetPayload } from './widget'

// ─── Enums & Sub-schemas ─────────────────────────────────────────────

export const Severity = z.enum(['debug', 'info', 'warning', 'error', 'critical'])
export type SeverityLevel = z.infer<typeof Severity>

export const IconRef = z.object({
  icon: z.string(),
  color: z.string().optional(),
  size: z.number().optional(),
})

export const ExceptionData: z.ZodType<{
  type: string
  message: string
  stack_trace?: string
  source?: string
  handled?: boolean
  inner?: unknown
}> = z.object({
  type: z.string().describe('Exception class/type name'),
  message: z.string().describe('Error message'),
  stack_trace: z.string().optional().describe('Stack trace string'),
  source: z.string().optional().describe('File/module where error occurred'),
  handled: z.boolean().optional().default(true).describe('Whether exception was caught'),
  inner: z.lazy(() => ExceptionData).optional().describe('Inner/cause exception'),
})

// ─── EventMessage ────────────────────────────────────────────────────

export const EventMessage = z.object({
  session_id: z.string().describe('Target session ID'),
  id: z.string().optional().describe('Event ID for idempotency/upsert'),
  severity: Severity.optional().default('info'),
  message: z.string().max(MAX_TEXT_SIZE).optional().describe('Human-readable text'),
  tag: z.string().max(128).optional().describe('Category label'),
  exception: ExceptionData.optional(),
  parent_id: z.string().optional().describe('Parent event ID for tree nesting'),
  group_id: z.string().optional().describe('Flat grouping reference'),
  prev_id: z.string().optional().describe('Insert after this event'),
  next_id: z.string().optional().describe('Insert before this event'),
  widget: WidgetPayload.optional().describe('Rich rendered content'),
  replace: z.boolean().optional().default(false).describe('Upsert: replace entry with same id'),
  generated_at: z.string().datetime({ offset: true }).optional(),
  sent_at: z.string().datetime({ offset: true }).optional(),
  icon: IconRef.optional(),
  labels: z.record(z.string(), z.string()).optional().describe('Key-value metadata for filtering'),
}).refine(
  (d) => !(d.parent_id && d.group_id),
  { message: 'parent_id and group_id are mutually exclusive', path: ['parent_id'] },
)

export type EventMessage = z.infer<typeof EventMessage>
export type Severity = z.infer<typeof Severity>
export type ExceptionData = z.infer<typeof ExceptionData>
export type IconRef = z.infer<typeof IconRef>

// ─── StackFrame ──────────────────────────────────────────────────────

export const SourceLocation = z.object({
  uri: z.string(),
  line: z.number().optional(),
  column: z.number().optional(),
  symbol: z.string().optional(),
})

export const StackFrame = z.object({
  location: SourceLocation,
  is_vendor: z.boolean().optional(),
  raw: z.string().optional(),
})

export type SourceLocation = z.infer<typeof SourceLocation>
export type StackFrame = z.infer<typeof StackFrame>

