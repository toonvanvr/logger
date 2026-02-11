// TODO(zod-config): migrate to z.object() for validation — would give type-safe parsing and clear error messages on invalid env vars
function safeInt(env: string | undefined, fallback: number): number {
  if (!env) return fallback
  const val = parseInt(env, 10)
  return isNaN(val) ? fallback : val
}

function safeFloat(env: string | undefined, fallback: number): number {
  if (!env) return fallback
  const val = parseFloat(env)
  return isNaN(val) ? fallback : val
}

export const config = {
  // Server
  host: process.env.LOGGER_BIND_ADDRESS ?? '127.0.0.1',
  port: safeInt(process.env.LOGGER_PORT, 8080),
  udpPort: safeInt(process.env.LOGGER_UDP_PORT, 8081),
  tcpPort: safeInt(process.env.LOGGER_TCP_PORT, 8082),

  // Ring Buffer
  ringBufferMaxEntries: safeInt(process.env.LOGGER_BUFFER_MAX_ENTRIES, 1000000),
  ringBufferMaxBytes: safeInt(process.env.LOGGER_BUFFER_MAX_BYTES, 256 * 1024 * 1024),

  // Rate Limiting
  rateLimitGlobal: safeInt(process.env.LOGGER_RATE_LIMIT_GLOBAL, 10000),
  rateLimitPerSession: safeInt(process.env.LOGGER_RATE_LIMIT_SESSION, 1000),
  rateLimitBurstMultiplier: safeFloat(process.env.LOGGER_RATE_LIMIT_BURST, 2),

  // Loki
  lokiUrl: process.env.LOGGER_LOKI_URL ?? process.env.LOKI_URL /* deprecated */ ?? 'http://localhost:3100',
  lokiBatchSize: safeInt(process.env.LOGGER_LOKI_BATCH_SIZE, 100),
  lokiFlushInterval: safeInt(process.env.LOGGER_LOKI_FLUSH_MS, 1000),
  lokiMaxBuffer: safeInt(process.env.LOGGER_LOKI_MAX_BUFFER, 10000),
  lokiRetries: safeInt(process.env.LOGGER_LOKI_RETRIES, 3),

  // Security
  apiKey: process.env.LOGGER_API_KEY ?? null,
  maxTimestampSkew: safeInt(process.env.LOGGER_MAX_TIMESTAMP_SKEW_MS, 24 * 60 * 60 * 1000),

  // Environment
  environment: process.env.LOGGER_ENVIRONMENT ?? 'dev',

  // Images
  imageStorePath: process.env.LOGGER_IMAGE_STORE_PATH ?? '/tmp/logger-images',
  imageStoreMaxBytes: safeInt(process.env.LOGGER_IMAGE_STORE_MAX_BYTES, 2 * 1024 * 1024 * 1024),

  // Store
  storeBackend: (process.env.LOGGER_STORE_BACKEND ?? 'loki') as 'loki' | 'memory',

  // Hooks
  hookRedactPatterns: (process.env.LOGGER_HOOK_REDACT_PATTERNS ?? '').split(',').filter(Boolean),
} as const;
