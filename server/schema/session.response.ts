import z from 'zod';

export const SessionResponse = z.object({
  sessionId: z.string(),
  startedAt: z.iso.datetime(),
})