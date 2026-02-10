import { HookManager } from './core/hooks'
import { RateLimiter } from './core/rate-limiter'
import { RingBuffer } from './modules/ring-buffer'
import { RpcBridge } from './modules/rpc-bridge'
import { SessionManager } from './modules/session-manager'
import { WebSocketHub } from './modules/ws-hub'
import { setupHttpRoutes } from './transport/http'
import type { ServerDeps } from './transport/types'
import { setupWebSocket } from './transport/ws'

// ─── Mock Modules ────────────────────────────────────────────────────

class MockLokiForwarder {
  entries: unknown[] = [];
  push(entry: unknown) {
    this.entries.push(entry)
  }
  getHealth() {
    return { status: 'healthy' as const, bufferSize: 0, bufferMax: 10000, consecutiveFailures: 0 }
  }
  async shutdown() { }
  async flush() { }
}

class MockFileStore {
  files = new Map<string, { sessionId: string; data: Uint8Array; mimeType: string }>();
  async store(sessionId: string, data: Buffer | Uint8Array, mimeType: string, _label?: string) {
    const ref = crypto.randomUUID()
    this.files.set(ref, { sessionId, data: new Uint8Array(data), mimeType })
    return ref
  }
  getUsage() {
    return { totalBytes: 0, fileCount: this.files.size }
  }
}

// ─── Test Server Factory ─────────────────────────────────────────────

export interface TestServerInstance {
  server: ReturnType<typeof Bun.serve>
  port: number
  baseUrl: string
  wsUrl: string
  deps: ServerDeps
  cleanup: () => void
}

export interface TestServerOverrides {
  rateLimitGlobal?: number
  rateLimitPerSession?: number
  rateLimitBurst?: number
  ringBufferMaxEntries?: number
  ringBufferMaxBytes?: number
  apiKey?: string | null
  sessionTimeoutMs?: number
}

/**
 * Create a fully wired test server on a random port.
 * Returns everything needed for integration testing.
 */
export function createTestServer(overrides?: TestServerOverrides): TestServerInstance {
  const config = {
    host: '127.0.0.1',
    port: 0,
    udpPort: 0,
    tcpPort: 0,
    apiKey: (overrides?.apiKey ?? null) as string | null,
    environment: 'test',
  }

  const deps: ServerDeps = {
    config,
    rateLimiter: new RateLimiter(
      overrides?.rateLimitGlobal ?? 10000,
      overrides?.rateLimitPerSession ?? 1000,
      overrides?.rateLimitBurst ?? 2,
    ),
    hookManager: new HookManager(),
    ringBuffer: new RingBuffer(
      overrides?.ringBufferMaxEntries ?? 10000,
      overrides?.ringBufferMaxBytes ?? 10 * 1024 * 1024,
    ),
    sessionManager: new SessionManager({
      timeoutMs: overrides?.sessionTimeoutMs ?? 300_000,
      checkIntervalMs: 999_999,
    }),
    wsHub: new WebSocketHub(),
    lokiForwarder: new MockLokiForwarder() as any,
    fileStore: new MockFileStore() as any,
    rpcBridge: new RpcBridge(),
  }

  const ws = setupWebSocket(deps)
  const routes = setupHttpRoutes(deps)

  const server = Bun.serve({
    port: 0,
    hostname: '127.0.0.1',
    routes,
    websocket: ws.handlers,
    fetch(req) {
      const url = new URL(req.url)
      if (url.pathname === '/api/v2/stream') {
        if (ws.upgrade(req, server)) return undefined
        return new Response('WebSocket upgrade failed', { status: 400 })
      }
      return new Response('Not Found', { status: 404 })
    },
  })

  const port = server.port
  const baseUrl = `http://127.0.0.1:${port}`
  const wsUrl = `ws://127.0.0.1:${port}/api/v2/stream`

  return {
    server,
    port,
    baseUrl,
    wsUrl,
    deps,
    cleanup() {
      server.stop()
      deps.sessionManager.shutdown()
    },
  }
}

// ─── Helpers ─────────────────────────────────────────────────────────

/** Create a valid EventMessage payload for testing. */
export function makeValidEvent(overrides?: Record<string, unknown>) {
  return {
    session_id: overrides?.session_id ?? 'test-sess',
    message: 'test message',
    severity: 'info',
    ...overrides,
  }
}

/** Create a session message payload. */
export function makeSessionMessage(
  sessionId: string,
  action: 'start' | 'end' | 'heartbeat',
  overrides?: Record<string, unknown>,
) {
  return {
    session_id: sessionId,
    action,
    application: { name: 'integration-test' },
    ...overrides,
  }
}
