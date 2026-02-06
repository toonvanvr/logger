import z from 'zod';
import { ApplicationLog } from './application-log.type';
import { RequestTimestamps } from './request-timestamps.type';

export const SessionRequest = z.object({
  application: ApplicationLog.optional(),
  request: RequestTimestamps.optional(),
})