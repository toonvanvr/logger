import { z } from 'zod'

// ─── Sub-schemas ─────────────────────────────────────────────────────

export const ApplicationInfo = z.object({
  name: z.string().min(1).max(128).describe('Application name'),
  version: z.string().max(64).optional().describe('App version'),
  environment: z.string().max(64).optional().describe('Environment (dev/staging/prod)'),
}).describe('Application identity')

// ─── SessionMessage ──────────────────────────────────────────────────

export const SessionMessage = z.object({
  session_id: z.string().uuid().describe('Client-generated session UUID'),
  action: z.enum(['start', 'end', 'heartbeat']).describe('Session lifecycle action'),
  application: ApplicationInfo.optional().describe('Required on start'),
  metadata: z.record(z.string(), z.unknown()).optional().describe('Arbitrary session metadata'),
}).refine(
  (d) => d.action !== 'start' || d.application !== undefined,
  { message: 'application is required when action is start', path: ['application'] },
)

export type SessionMessage = z.infer<typeof SessionMessage>
export type ApplicationInfo = z.infer<typeof ApplicationInfo>

