import { z } from 'zod'

export const LogSeverity = z.enum(['debug', 'info', 'warning', 'error', 'critical'])

export type LogSeverity = z.infer<typeof LogSeverity>