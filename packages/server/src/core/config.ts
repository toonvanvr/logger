import { z } from 'zod'

const envInt = (fallback: number) =>
  z.coerce.number().int().default(fallback)

const envFloat = (fallback: number) =>
  z.coerce.number().default(fallback)

export const ConfigSchema = z.object({
  // Server
  host: z.string().default('127.0.0.1').describe('Bind address'),
  port: envInt(8080).describe('HTTP API port'),
  udpPort: envInt(8081).describe('UDP ingest port'),
  tcpPort: envInt(8082).describe('TCP/WebSocket port'),

  // Ring Buffer
  ringBufferMaxEntries: envInt(1000000).describe('Max entries in ring buffer'),
  ringBufferMaxBytes: envInt(256 * 1024 * 1024).describe('Max bytes in ring buffer'),

  // Rate Limiting
  rateLimitGlobal: envInt(10000).describe('Global rate limit (entries/sec)'),
  rateLimitPerSession: envInt(1000).describe('Per-session rate limit (entries/sec)'),
  rateLimitBurstMultiplier: envFloat(2).describe('Burst multiplier for rate limiting'),

  // Loki
  lokiUrl: z.string().default(process.env.LOKI_URL ?? 'http://localhost:3100').describe('Loki push API URL'),
  lokiBatchSize: envInt(100).describe('Loki batch size'),
  lokiFlushInterval: envInt(1000).describe('Loki flush interval (ms)'),
  lokiMaxBuffer: envInt(10000).describe('Loki max buffer size'),
  lokiRetries: envInt(3).describe('Loki retry count'),

  // Security
  apiKey: z.string().nullable().default(null).describe('API key for authentication'),
  maxTimestampSkew: envInt(24 * 60 * 60 * 1000).describe('Max timestamp skew (ms)'),

  // Environment
  environment: z.string().default('dev').describe('Environment name'),

  // Images
  imageStorePath: z.string().default('/tmp/logger-images').describe('Image store directory path'),
  imageStoreMaxBytes: envInt(2 * 1024 * 1024 * 1024).describe('Image store max bytes'),

  // Store
  storeBackend: z.enum(['loki', 'memory']).default('memory').describe('Storage backend'),

  // Hooks
  hookRedactPatterns: z.string().default('').transform(s => s.split(',').filter(Boolean)).describe('Comma-separated redaction patterns'),
})

export type Config = z.infer<typeof ConfigSchema>

export const config = ConfigSchema.parse({
  host: process.env.LOGGER_BIND_ADDRESS,
  port: process.env.LOGGER_PORT,
  udpPort: process.env.LOGGER_UDP_PORT,
  tcpPort: process.env.LOGGER_TCP_PORT,
  ringBufferMaxEntries: process.env.LOGGER_BUFFER_MAX_ENTRIES,
  ringBufferMaxBytes: process.env.LOGGER_BUFFER_MAX_BYTES,
  rateLimitGlobal: process.env.LOGGER_RATE_LIMIT_GLOBAL,
  rateLimitPerSession: process.env.LOGGER_RATE_LIMIT_SESSION,
  rateLimitBurstMultiplier: process.env.LOGGER_RATE_LIMIT_BURST,
  lokiUrl: process.env.LOGGER_LOKI_URL,
  lokiBatchSize: process.env.LOGGER_LOKI_BATCH_SIZE,
  lokiFlushInterval: process.env.LOGGER_LOKI_FLUSH_MS,
  lokiMaxBuffer: process.env.LOGGER_LOKI_MAX_BUFFER,
  lokiRetries: process.env.LOGGER_LOKI_RETRIES,
  apiKey: process.env.LOGGER_API_KEY,
  maxTimestampSkew: process.env.LOGGER_MAX_TIMESTAMP_SKEW_MS,
  environment: process.env.LOGGER_ENVIRONMENT,
  imageStorePath: process.env.LOGGER_IMAGE_STORE_PATH,
  imageStoreMaxBytes: process.env.LOGGER_IMAGE_STORE_MAX_BYTES,
  storeBackend: process.env.LOGGER_STORE_BACKEND,
  hookRedactPatterns: process.env.LOGGER_HOOK_REDACT_PATTERNS,
})
