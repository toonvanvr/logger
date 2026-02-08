import z from 'zod'
import { ApplicationLog } from './application-log.type'
import { ExceptionLog } from './exception-log.type'
import { RequestTimestamps } from './request-timestamps.type'
import { LogSeverity } from './severity.enum'

export const LogRequest = z.object({
  // Tracing
  request: RequestTimestamps.optional(),

  // Display metadata
  severity: LogSeverity,
  application: ApplicationLog.optional(),

  // Body
  payload: z.any(),
  exception: ExceptionLog.optional(),
})

export type LogRequest = z.infer<typeof LogRequest>