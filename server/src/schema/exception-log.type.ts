import z from 'zod';

export const ExceptionLog = z.object({
  type: z.string().optional(),
  message: z.string(),
  baseUri: z.string().optional(),
  trace: z.object({
    baseUri: z.string().optional(),
    frames: z.array(z.object({
      location: z.object({
        uri: z.string().optional(),
        cursor: z.object({
          line: z.number().optional(),
          character: z.number().optional(),
        }).optional()
      })
    }))
  }).optional()
})