import z from 'zod';

export const ApplicationLog = z.object({
    name: z.string(),
    version: z.string().optional(),
    sessionId: z.string().optional(),
})

export type ApplicationLog = z.infer<typeof ApplicationLog>