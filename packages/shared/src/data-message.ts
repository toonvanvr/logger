import { z } from 'zod'
import { IconRef } from './event-message.js'

// ─── Sub-schemas ─────────────────────────────────────────────────────

export const WidgetConfig = z.object({
  type: z.string().describe('Widget type (chart, progress, kv, etc)'),
}).passthrough().describe('Widget rendering configuration')

export const DisplayLocation = z.enum(['default', 'static', 'shelf'])

// ─── DataMessage ─────────────────────────────────────────────────────

export const DataMessage = z.object({
  session_id: z.string().describe('Target session ID'),
  key: z.string().max(256).describe('Unique data key per session'),
  value: z.unknown().optional().describe('Any JSON value'),
  override: z.boolean().optional().default(true).describe('true=replace, false=append'),
  display: DisplayLocation.optional().default('default').describe('Where to render'),
  widget: WidgetConfig.optional().describe('Rendering configuration'),
  label: z.string().max(256).optional().describe('Display name'),
  icon: IconRef.optional(),
})

export type DataMessage = z.infer<typeof DataMessage>
export type DisplayLocation = z.infer<typeof DisplayLocation>

