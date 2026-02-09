import { afterAll, beforeAll, describe, expect, it } from 'bun:test'
import { HookManager } from '../core/hooks'
import { processPipeline } from '../core/pipeline'
import { RateLimiter } from '../core/rate-limiter'
import { RingBuffer } from '../modules/ring-buffer'
import { RpcBridge } from '../modules/rpc-bridge'
import { SessionManager } from '../modules/session-manager'
import { WebSocketHub } from '../modules/ws-hub'
import { setupHttpV2Routes } from './http-v2'
import type { ServerDeps } from './types'

// ─── Mocks ───────────────────────────────────────────────────────────

class MockLokiForwarder {
  entries: any[] = [];
  push(entry: any) { this.entries.push(entry) }
  getHealth() { return { status: 'healthy' as const, bufferSize: 0, bufferMax: 10000, consecutiveFailures: 0 } }
  async shutdown() { }
  async flush() { }
}

class MockFileStore {
  async store() { return crypto.randomUUID() }
  getUsage() { return { totalBytes: 0, fileCount: 0 } }
}

function createTestDeps(): ServerDeps {
  return {
    config: { host: '127.0.0.1', port: 0, udpPort: 0, tcpPort: 0, apiKey: null, environment: 'test' },
    pipeline: processPipeline,
    rateLimiter: new RateLimiter(10000, 1000, 2),
    hookManager: new HookManager(),
    ringBuffer: new RingBuffer(10000, 10 * 1024 * 1024),
    sessionManager: new SessionManager({ timeoutMs: 300_000, checkIntervalMs: 999_999 }),
    wsHub: new WebSocketHub(),
    lokiForwarder: new MockLokiForwarder() as any,
    fileStore: new MockFileStore() as any,
    rpcBridge: new RpcBridge(),
  }
}

// ─── Tests ───────────────────────────────────────────────────────────

describe('HTTP v2 Transport', () => {
  let server: ReturnType<typeof Bun.serve>
  let baseUrl: string
  let deps: ServerDeps

  beforeAll(() => {
    deps = createTestDeps()
    const routes = setupHttpV2Routes(deps)
    server = Bun.serve({ port: 0, hostname: '127.0.0.1', routes })
    baseUrl = `http://127.0.0.1:${server.port}`
  })

  afterAll(() => {
    server.stop()
    deps.sessionManager.shutdown()
  })

  // ─── POST /api/v2/session ────────────────────────────────────────

  it('POST /api/v2/session with valid start returns ok', async () => {
    const res = await fetch(`${baseUrl}/api/v2/session`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ session_id: crypto.randomUUID(), action: 'start', application: { name: 'test' } }),
    })
    const body = await res.json()
    expect(res.status).toBe(200)
    expect(body.ok).toBe(true)
    expect(body.session_id).toBeTruthy()
  })

  it('POST /api/v2/session rejects invalid body', async () => {
    const res = await fetch(`${baseUrl}/api/v2/session`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ action: 'start' }),
    })
    const body = await res.json()
    expect(res.status).toBe(400)
    expect(body.ok).toBe(false)
  })

  it('POST /api/v2/session rejects non-JSON', async () => {
    const res = await fetch(`${baseUrl}/api/v2/session`, {
      method: 'POST',
      body: 'not json',
    })
    expect(res.status).toBe(400)
  })

  // ─── POST /api/v2/events ─────────────────────────────────────────

  it('POST /api/v2/events with single event returns ok + id', async () => {
    const res = await fetch(`${baseUrl}/api/v2/events`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ session_id: 'sess-1', message: 'hello v2', severity: 'info' }),
    })
    const body = await res.json()
    expect(res.status).toBe(200)
    expect(body.ok).toBe(true)
    expect(body.id).toBeTruthy()
  })

  it('POST /api/v2/events with batch returns results array', async () => {
    const batch = [
      { session_id: 'sess-1', message: 'one' },
      { session_id: 'sess-1', message: 'two' },
    ]
    const res = await fetch(`${baseUrl}/api/v2/events`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(batch),
    })
    const body = await res.json()
    expect(res.status).toBe(200)
    expect(body.ok).toBe(true)
    expect(body.results).toHaveLength(2)
    expect(body.results[0].ok).toBe(true)
    expect(body.results[0].id).toBeTruthy()
  })

  it('POST /api/v2/events rejects empty batch', async () => {
    const res = await fetch(`${baseUrl}/api/v2/events`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify([]),
    })
    expect(res.status).toBe(400)
  })

  it('POST /api/v2/events rejects invalid event', async () => {
    const res = await fetch(`${baseUrl}/api/v2/events`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ severity: 'invalid_level' }),
    })
    const body = await res.json()
    expect(res.status).toBe(400)
    expect(body.ok).toBe(false)
  })

  // ─── POST /api/v2/data ───────────────────────────────────────────

  it('POST /api/v2/data with single data point returns ok', async () => {
    const res = await fetch(`${baseUrl}/api/v2/data`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ session_id: 'sess-1', key: 'cpu', value: 72.5 }),
    })
    const body = await res.json()
    expect(res.status).toBe(200)
    expect(body.ok).toBe(true)
    expect(body.id).toBeTruthy()
  })

  it('POST /api/v2/data with batch returns results', async () => {
    const batch = [
      { session_id: 'sess-1', key: 'cpu', value: 72.5 },
      { session_id: 'sess-1', key: 'mem', value: 1024 },
    ]
    const res = await fetch(`${baseUrl}/api/v2/data`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(batch),
    })
    const body = await res.json()
    expect(res.status).toBe(200)
    expect(body.ok).toBe(true)
    expect(body.results).toHaveLength(2)
  })

  it('POST /api/v2/data rejects missing key', async () => {
    const res = await fetch(`${baseUrl}/api/v2/data`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ session_id: 'sess-1', value: 42 }),
    })
    const body = await res.json()
    expect(res.status).toBe(400)
    expect(body.ok).toBe(false)
  })

  // ─── Auth ─────────────────────────────────────────────────────────

  it('rejects requests when API key is set but not provided', async () => {
    const authDeps = createTestDeps();
    (authDeps.config as any).apiKey = 'secret-key'
    const routes = setupHttpV2Routes(authDeps)
    const authServer = Bun.serve({ port: 0, hostname: '127.0.0.1', routes })

    try {
      const res = await fetch(`http://127.0.0.1:${authServer.port}/api/v2/events`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ session_id: 'sess-1', message: 'test' }),
      })
      expect(res.status).toBe(401)
    } finally {
      authServer.stop()
      authDeps.sessionManager.shutdown()
    }
  })
})
