import z from 'zod'
import { LogSeverity } from './severity.enum'
import { ExceptionLog } from './exception-log.type'
import { ApplicationLog } from './application-log.type'
import { RequestTimestamps } from './request-timestamps.type'

export const LogRequest = z.object({
  // Tracing
  request: RequestTimestamps.optional(),

  // Display metadata
  severity: LogSeverity,
  application: ApplicationLog.optional(),

  // Body
  payload: z.any(),
  exception: ExceptionLog,
})