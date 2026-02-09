import { afterAll, beforeAll, describe, expect, it } from 'bun:test'
import { HookManager } from '../core/hooks'
import { processPipeline } from '../core/pipeline'
import { RateLimiter } from '../core/rate-limiter'
import { RingBuffer } from '../modules/ring-buffer'
import { RpcBridge } from '../modules/rpc-bridge'
import { SessionManager } from '../modules/session-manager'
import { WebSocketHub } from '../modules/ws-hub'
import type { ServerDeps } from './types'
import { setupWebSocketV2 } from './ws-v2'

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

describe('WebSocket v2', () => {
  let server: ReturnType<typeof Bun.serve>
  let baseUrl: string
  let deps: ServerDeps
  let wsV2: ReturnType<typeof setupWebSocketV2>

  beforeAll(() => {
    deps = createTestDeps()
    wsV2 = setupWebSocketV2(deps)
    server = Bun.serve({
      port: 0,
      hostname: '127.0.0.1',
      websocket: wsV2.handlers,
      fetch(req) {
        if (wsV2.upgrade(req, server)) return undefined
        return new Response('WebSocket upgrade failed', { status: 400 })
      },
    })
    baseUrl = `ws://127.0.0.1:${server.port}`
  })

  afterAll(() => {
    server.stop()
    deps.sessionManager.shutdown()
  })

  function connectClient(sessionId: string): Promise<WebSocket> {
    return new Promise((resolve, reject) => {
      const ws = new WebSocket(baseUrl, {
        headers: {
          'x-logger-role': 'client',
          'x-session-id': sessionId,
          'sec-websocket-protocol': 'logger-v2',
        },
      } as any)
      ws.onopen = () => resolve(ws)
      ws.onerror = (e) => reject(e)
    })
  }

  function connectViewer(): Promise<WebSocket> {
    return new Promise((resolve, reject) => {
      const ws = new WebSocket(baseUrl, {
        headers: {
          'x-logger-role': 'viewer',
          'sec-websocket-protocol': 'logger-v2',
        },
      } as any)
      ws.onopen = () => resolve(ws)
      ws.onerror = (e) => reject(e)
    })
  }

  function waitForMessage(ws: WebSocket): Promise<any> {
    return new Promise((resolve) => {
      ws.onmessage = (e) => resolve(JSON.parse(e.data))
    })
  }

  it('isV2 returns true for logger-v2 protocol header', () => {
    const req = new Request('http://localhost/ws', {
      headers: { 'sec-websocket-protocol': 'logger-v2' },
    })
    expect(wsV2.isV2(req)).toBe(true)
  })

  it('isV2 returns true for x-logger-version: 2', () => {
    const req = new Request('http://localhost/ws', {
      headers: { 'x-logger-version': '2' },
    })
    expect(wsV2.isV2(req)).toBe(true)
  })

  it('isV2 returns false for regular requests', () => {
    const req = new Request('http://localhost/ws')
    expect(wsV2.isV2(req)).toBe(false)
  })

  it('client can send event and receives ack', async () => {
    const ws = await connectClient('ws-test-sess-1')

    const msgPromise = waitForMessage(ws)
    ws.send(JSON.stringify({
      type: 'event',
      session_id: 'ws-test-sess-1',
      message: 'hello from ws v2',
    }))

    const response = await msgPromise
    expect(response.type).toBe('ack')
    expect(response.ids).toHaveLength(1)

    ws.close()
  })

  it('client can send session message', async () => {
    const sessId = crypto.randomUUID()
    const ws = await connectClient(sessId)

    const msgPromise = waitForMessage(ws)
    ws.send(JSON.stringify({
      type: 'session',
      session_id: sessId,
      action: 'start',
      application: { name: 'ws-test-app' },
    }))

    const response = await msgPromise
    expect(response.type).toBe('ack')
    ws.close()
  })

  it('client can send data message', async () => {
    const ws = await connectClient('ws-data-sess')

    const msgPromise = waitForMessage(ws)
    ws.send(JSON.stringify({
      type: 'data',
      session_id: 'ws-data-sess',
      key: 'cpu',
      value: 85.2,
    }))

    const response = await msgPromise
    expect(response.type).toBe('ack')
    ws.close()
  })

  it('viewer receives session_list on connect', async () => {
    const ws = await connectViewer()
    const msg = await waitForMessage(ws)
    expect(msg.type).toBe('session_list')
    expect(Array.isArray(msg.sessions)).toBe(true)
    ws.close()
  })

  it('viewer can request session_list', async () => {
    const ws = await connectViewer()
    // Skip initial session_list
    await waitForMessage(ws)

    const msgPromise = waitForMessage(ws)
    ws.send(JSON.stringify({ type: 'session_list' }))
    const msg = await msgPromise
    expect(msg.type).toBe('session_list')
    ws.close()
  })
})
