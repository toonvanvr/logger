// ─── Size Limits ─────────────────────────────────────────────────────

/** Maximum text content size in bytes (1 MB) */
export const MAX_TEXT_SIZE = 1 * 1024 * 1024

/** Maximum JSON content size in bytes (4 MB) */
export const MAX_JSON_SIZE = 4 * 1024 * 1024

/** Maximum binary content size in bytes (16 MB) */
export const MAX_BINARY_SIZE = 16 * 1024 * 1024

/** Maximum image content size in bytes (32 MB) */
export const MAX_IMAGE_SIZE = 32 * 1024 * 1024

/** Maximum number of tags per log entry */
export const MAX_TAGS = 32

/** Maximum session ID length in characters */
export const MAX_SESSION_ID_LENGTH = 256

/** Maximum entries in a single log batch */
export const MAX_BATCH_SIZE = 1000

/** Default ring buffer capacity in entries */
export const RING_BUFFER_DEFAULT_SIZE = 1_000_000

// ─── Network Defaults ────────────────────────────────────────────────

/** Default HTTP/WS server port */
export const DEFAULT_SERVER_PORT = 8080

/** Default UDP listener port */
export const DEFAULT_UDP_PORT = 8081

/** Default TCP listener port */
export const DEFAULT_TCP_PORT = 8082

/** Default host for all transports */
export const DEFAULT_HOST = 'localhost'

/** Default WebSocket stream URL */
export const DEFAULT_WS_URL = `ws://${DEFAULT_HOST}:${DEFAULT_SERVER_PORT}/api/v2/stream`

/** Default session endpoint */
export const DEFAULT_SESSION_URL = `http://${DEFAULT_HOST}:${DEFAULT_SERVER_PORT}/api/v2/session`

/** Default events endpoint */
export const DEFAULT_EVENTS_URL = `http://${DEFAULT_HOST}:${DEFAULT_SERVER_PORT}/api/v2/events`

/** Default data endpoint */
export const DEFAULT_DATA_URL = `http://${DEFAULT_HOST}:${DEFAULT_SERVER_PORT}/api/v2/data`

// ─── Error Codes ─────────────────────────────────────────────────────

export const ERROR_CODES = {
  /** Zod schema validation failed */
  VALIDATION_FAILED: 'VALIDATION_FAILED',
  /** Rate limit exceeded */
  RATE_LIMITED: 'RATE_LIMITED',
  /** Session ID not found */
  SESSION_NOT_FOUND: 'SESSION_NOT_FOUND',
  /** Internal server error */
  INTERNAL_ERROR: 'INTERNAL_ERROR',
  /** Payload too large */
  PAYLOAD_TOO_LARGE: 'PAYLOAD_TOO_LARGE',
  /** Authentication required or failed */
  AUTH_FAILED: 'AUTH_FAILED',
  /** WebSocket backpressure — messages dropped */
  BACKPRESSURE: 'BACKPRESSURE',
  /** RPC timeout */
  RPC_TIMEOUT: 'RPC_TIMEOUT',
  /** RPC target session not found or disconnected */
  RPC_TARGET_NOT_FOUND: 'RPC_TARGET_NOT_FOUND',
  /** Max connections exceeded */
  MAX_CONNECTIONS: 'MAX_CONNECTIONS',
} as const

export type ErrorCode = (typeof ERROR_CODES)[keyof typeof ERROR_CODES]
