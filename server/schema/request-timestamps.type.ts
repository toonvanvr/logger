import z from 'zod';

export const RequestTimestamps = z.object({
  generatedAt: z.iso.datetime().optional(),
  sentAt: z.iso.datetime().optional(),
})

export type RequestTimestamps = z.infer<typeof RequestTimestamps>;