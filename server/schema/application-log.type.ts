import z from 'zod';

export const ApplicationLog = z.object({
  application: z.object({
    name: z.string(),
    version: z.string().optional(),
    environment: z.record(z.string(), z.string()).optional(),
    sessionIdentifier: z.string().optional(),
  }),
})

export type ApplicationLog = z.infer<typeof ApplicationLog>