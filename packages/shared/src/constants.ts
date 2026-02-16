// ─── Size Limits ─────────────────────────────────────────────────────

/** Maximum text content size in bytes (1 MB) */
export const MAX_TEXT_SIZE = 1 * 1024 * 1024

/** Maximum entries in a single log batch */
export const MAX_BATCH_SIZE = 1000

// ─── Network Defaults ────────────────────────────────────────────────

/** Default UDP listener port */
export const DEFAULT_UDP_PORT = 8081

/** Default TCP listener port */
export const DEFAULT_TCP_PORT = 8082

/** Default host for all transports */
export const DEFAULT_HOST = 'localhost'

// ─── Canonical Contract Paths ───────────────────────────────────────

/** API v2 base path */
export const API_V2_BASE_PATH = '/api/v2'

/** Canonical HTTP and WS route paths for API v2 */
export const API_PATHS = {
	HEALTH: `${API_V2_BASE_PATH}/health`,
	SESSIONS: `${API_V2_BASE_PATH}/sessions`,
	SESSION: `${API_V2_BASE_PATH}/session`,
	EVENTS: `${API_V2_BASE_PATH}/events`,
	DATA: `${API_V2_BASE_PATH}/data`,
	UPLOAD: `${API_V2_BASE_PATH}/upload`,
	QUERY: `${API_V2_BASE_PATH}/query`,
	RPC: `${API_V2_BASE_PATH}/rpc`,
	STREAM: `${API_V2_BASE_PATH}/stream`,
} as const
