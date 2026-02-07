export const config = {
  // Server
  host: process.env.LOGGER_BIND_ADDRESS ?? '127.0.0.1',
  port: parseInt(process.env.LOGGER_PORT ?? '8080'),
  udpPort: parseInt(process.env.LOGGER_UDP_PORT ?? '8081'),
  tcpPort: parseInt(process.env.LOGGER_TCP_PORT ?? '8082'),

  // Ring Buffer
  ringBufferMaxEntries: parseInt(process.env.LOGGER_BUFFER_MAX_ENTRIES ?? '1000000'),
  ringBufferMaxBytes: parseInt(process.env.LOGGER_BUFFER_MAX_BYTES ?? String(256 * 1024 * 1024)),

  // Rate Limiting
  rateLimitGlobal: parseInt(process.env.LOGGER_RATE_LIMIT_GLOBAL ?? '10000'),
  rateLimitPerSession: parseInt(process.env.LOGGER_RATE_LIMIT_SESSION ?? '1000'),
  rateLimitBurstMultiplier: parseFloat(process.env.LOGGER_RATE_LIMIT_BURST ?? '2'),

  // Loki
  lokiUrl: process.env.LOKI_URL ?? 'http://localhost:3100',
  lokiBatchSize: parseInt(process.env.LOGGER_LOKI_BATCH_SIZE ?? '100'),
  lokiFlushInterval: parseInt(process.env.LOGGER_LOKI_FLUSH_MS ?? '1000'),
  lokiMaxBuffer: parseInt(process.env.LOGGER_LOKI_MAX_BUFFER ?? '10000'),
  lokiRetries: parseInt(process.env.LOGGER_LOKI_RETRIES ?? '3'),

  // Security
  apiKey: process.env.LOGGER_API_KEY ?? null,
  maxTimestampSkew: parseInt(process.env.LOGGER_MAX_TIMESTAMP_SKEW_MS ?? String(24 * 60 * 60 * 1000)),

  // Environment
  environment: process.env.LOGGER_ENVIRONMENT ?? 'dev',

  // Images
  imageStorePath: process.env.LOGGER_IMAGE_STORE_PATH ?? '/tmp/logger-images',
  imageStoreMaxBytes: parseInt(process.env.LOGGER_IMAGE_STORE_MAX_BYTES ?? String(2 * 1024 * 1024 * 1024)),

  // Hooks
  hookRedactPatterns: (process.env.LOGGER_HOOK_REDACT_PATTERNS ?? '').split(',').filter(Boolean),
} as const;
