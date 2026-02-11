import { afterAll, beforeAll, describe, expect, it } from 'bun:test'
import {
  createTestServer,
  makeSessionMessage,
  makeValidEvent,
  type TestServerInstance,
} from '../test-utils'

// ─── Test Server Setup ───────────────────────────────────────────────

let t: TestServerInstance

beforeAll(() => {
  t = createTestServer()
})

afterAll(() => {
  t.cleanup()
})

// ─── Helpers ─────────────────────────────────────────────────────────

async function postJson(path: string, body: unknown, headers?: Record<string, string>) {
  return fetch(`${t.baseUrl}${path}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', ...headers },
    body: JSON.stringify(body),
  })
}

// ─── Integration Tests ───────────────────────────────────────────────

describe('Integration: HTTP single event round-trip', () => {
  it('POST /api/v2/events with valid event returns 200 and id', async () => {
    const event = makeValidEvent()
    const res = await postJson('/api/v2/events', event)
    const body = await res.json()

    expect(res.status).toBe(200)
    expect(body.ok).toBe(true)
    expect(body.id).toBeTruthy()
  })

  it('POST /api/v2/events with missing session_id returns 400', async () => {
    const res = await postJson('/api/v2/events', { bad: 'data' })
    const body = await res.json()

    expect(res.status).toBe(400)
    expect(body.ok).toBe(false)
  })
})

describe('Integration: HTTP batch events', () => {
  it('POST /api/v2/events with array returns results', async () => {
    const batch = [
      makeValidEvent({ session_id: 'batch-sess' }),
      makeValidEvent({ session_id: 'batch-sess' }),
      makeValidEvent({ session_id: 'batch-sess' }),
    ]
    const res = await postJson('/api/v2/events', batch)
    const body = await res.json()

    expect(res.status).toBe(200)
    expect(body.ok).toBe(true)
    expect(body.results).toHaveLength(3)
    expect(body.results[0].ok).toBe(true)
  })

  it('POST /api/v2/events with empty batch returns 400', async () => {
    const res = await postJson('/api/v2/events', [])
    const body = await res.json()

    expect(res.status).toBe(400)
    expect(body.ok).toBe(false)
  })
})

describe('Integration: WebSocket client connection', () => {
  it('connects via WS, sends an event, and receives ack', async () => {
    const ack = await new Promise<any>((resolve, reject) => {
      const ws = new WebSocket(t.wsUrl, {
        headers: { 'X-Logger-Role': 'client', 'X-Session-Id': 'ws-test-sess' },
      } as any)

      const timeout = setTimeout(() => {
        ws.close()
        reject(new Error('WebSocket ack timeout'))
      }, 5000)

      ws.onopen = () => {
        ws.send(JSON.stringify({
          type: 'event',
          session_id: 'ws-test-sess',
          message: 'hello from ws',
        }))
      }

      ws.onmessage = (event: MessageEvent) => {
        clearTimeout(timeout)
        const data = JSON.parse(String(event.data))
        ws.close()
        resolve(data)
      }

      ws.onerror = () => {
        clearTimeout(timeout)
        reject(new Error('WebSocket error'))
      }
    })

    expect(ack.type).toBe('ack')
    expect(ack.ids).toHaveLength(1)
  })
})

describe('Integration: Ring buffer persistence', () => {
  it('events via HTTP appear in ring buffer and sessions endpoint', async () => {
    const sessionId = `ring-buf-sess-${Date.now()}`

    // Send 5 events
    for (let i = 0; i < 5; i++) {
      const event = makeValidEvent({
        session_id: sessionId,
        message: `ring buffer test ${i}`,
      })
      const res = await postJson('/api/v2/events', event)
      expect(res.status).toBe(200)
    }

    // Verify session exists via /api/v2/sessions
    const sessRes = await fetch(`${t.baseUrl}/api/v2/sessions`)
    expect(sessRes.status).toBe(200)
    const sessions: any[] = await sessRes.json()
    const found = sessions.find((s) => s.sessionId === sessionId)

    expect(found).toBeDefined()
    expect(found.logCount).toBe(5)

    // Verify entries are in ring buffer
    expect(t.deps.ringBuffer.size).toBeGreaterThanOrEqual(5)
  })
})

describe('Integration: Session lifecycle', () => {
  it('session start → events → session end transitions correctly', async () => {
    const sessionId = crypto.randomUUID()

    // 1. Send session start
    const startRes = await postJson('/api/v2/session', makeSessionMessage(sessionId, 'start'))
    expect(startRes.status).toBe(200)

    // Verify session is active
    let session = t.deps.sessionManager.getSession(sessionId)
    expect(session).toBeDefined()
    expect(session!.isActive).toBe(true)

    // 2. Send some regular events
    for (let i = 0; i < 3; i++) {
      await postJson('/api/v2/events', makeValidEvent({
        session_id: sessionId,
        message: `lifecycle event ${i}`,
      }))
    }

    // Verify log count increased (session start + 3 events = 4 total)
    session = t.deps.sessionManager.getSession(sessionId)
    expect(session!.logCount).toBe(4)

    // 3. Send session end
    const endRes = await postJson('/api/v2/session', makeSessionMessage(sessionId, 'end'))
    expect(endRes.status).toBe(200)

    // Verify session is no longer active
    session = t.deps.sessionManager.getSession(sessionId)
    expect(session).toBeDefined()
    expect(session!.isActive).toBe(false)
  })

  it('session appears in GET /api/v2/sessions after start', async () => {
    const sessionId = crypto.randomUUID()

    await postJson('/api/v2/session', makeSessionMessage(sessionId, 'start'))

    const res = await fetch(`${t.baseUrl}/api/v2/sessions`)
    const sessions: any[] = await res.json()
    const found = sessions.find((s) => s.sessionId === sessionId)

    expect(found).toBeDefined()
    expect(found.isActive).toBe(true)
    expect(found.application.name).toBe('integration-test')
  })
})

describe('Integration: RPC round-trip', () => {
  it('viewer sends RPC request → client receives and responds', async () => {
    const sessionId = crypto.randomUUID()
    const rpcId = crypto.randomUUID()

    // 1. Connect a client WS that registers tools and auto-responds to requests
    const clientWs = await new Promise<WebSocket>((resolve, reject) => {
      const ws = new WebSocket(t.wsUrl, {
        headers: { 'X-Logger-Role': 'client', 'X-Session-Id': sessionId },
      } as any)

      const timeout = setTimeout(() => {
        ws.close()
        reject(new Error('Client WS open timeout'))
      }, 5000)

      ws.onopen = () => {
        clearTimeout(timeout)
        ws.send(JSON.stringify({
          type: 'register_tools',
          tools: [
            { name: 'getStatus', description: 'Get app status', category: 'getter' },
          ],
        }))
        resolve(ws)
      }

      ws.onerror = () => {
        clearTimeout(timeout)
        reject(new Error('Client WS error'))
      }
    })

    // Set up client to auto-respond to incoming RPC requests
    clientWs.onmessage = (event: MessageEvent) => {
      const data = JSON.parse(String(event.data))
      if (data.type === 'rpc_request') {
        clientWs.send(JSON.stringify({
          type: 'rpc_response',
          rpc_id: data.rpc_id,
          result: { status: 'healthy', uptime: 12345 },
        }))
      }
    }

    await new Promise((r) => setTimeout(r, 100))

    try {
      // 2. Connect a viewer WS and send an RPC request
      const rpcResult = await new Promise<any>((resolve, reject) => {
        const ws = new WebSocket(t.wsUrl, {
          headers: { 'X-Logger-Role': 'viewer' },
        } as any)

        const timeout = setTimeout(() => {
          ws.close()
          reject(new Error('Viewer RPC response timeout'))
        }, 5000)

        ws.onopen = () => {
          ws.send(JSON.stringify({
            type: 'rpc_request',
            rpc_id: rpcId,
            target_session_id: sessionId,
            method: 'getStatus',
            args: { verbose: true },
          }))
        }

        ws.onmessage = (event: MessageEvent) => {
          const data = JSON.parse(String(event.data))
          if (data.type === 'session_list') return

          if (data.type === 'rpc_response' && data.rpc_id === rpcId) {
            clearTimeout(timeout)
            ws.close()
            resolve(data)
          }
        }

        ws.onerror = () => {
          clearTimeout(timeout)
          reject(new Error('Viewer WS error'))
        }
      })

      expect(rpcResult.type).toBe('rpc_response')
      expect(rpcResult.rpc_id).toBe(rpcId)
      expect(rpcResult.result).toEqual({ status: 'healthy', uptime: 12345 })
    } finally {
      clientWs.close()
    }
  })
})

describe('Integration: Rate limiting', () => {
  it('returns 429 when per-session rate limit is exceeded', async () => {
    const rlServer = createTestServer({
      rateLimitGlobal: 1000,
      rateLimitPerSession: 2,
      rateLimitBurst: 1,
    })
    const rlUrl = rlServer.baseUrl

    try {
      const sessionId = 'rate-limit-test'

      // First two should succeed
      for (let i = 0; i < 2; i++) {
        const res = await fetch(`${rlUrl}/api/v2/events`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(makeValidEvent({ session_id: sessionId })),
        })
        expect(res.status).toBe(200)
      }

      // Third should be rate limited
      const res = await fetch(`${rlUrl}/api/v2/events`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(makeValidEvent({ session_id: sessionId })),
      })
      expect(res.status).toBe(429)
      const body = await res.json()
      expect(body.ok).toBe(false)
      expect(body.error).toContain('Rate limit')
    } finally {
      rlServer.cleanup()
    }
  })

  it('rate limit is per-session — different sessions are independent', async () => {
    const rlServer = createTestServer({
      rateLimitGlobal: 1000,
      rateLimitPerSession: 2,
      rateLimitBurst: 1,
    })

    try {
      // Fill session A
      for (let i = 0; i < 2; i++) {
        const res = await fetch(`${rlServer.baseUrl}/api/v2/events`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(makeValidEvent({ session_id: 'sess-a' })),
        })
        expect(res.status).toBe(200)
      }

      // Session A is now rate limited
      const limitedRes = await fetch(`${rlServer.baseUrl}/api/v2/events`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(makeValidEvent({ session_id: 'sess-a' })),
      })
      expect(limitedRes.status).toBe(429)

      // Session B should still succeed
      const resSessB = await fetch(`${rlServer.baseUrl}/api/v2/events`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(makeValidEvent({ session_id: 'sess-b' })),
      })
      expect(resSessB.status).toBe(200)
    } finally {
      rlServer.cleanup()
    }
  })
})

describe('Integration: Health endpoints', () => {
  it('GET /health returns basic ok', async () => {
    const res = await fetch(`${t.baseUrl}/health`)
    const body = await res.json()

    expect(res.status).toBe(200)
    expect(body.status).toBe('ok')
  })

  it('GET /api/v2/health returns detailed health after activity', async () => {
    const res = await fetch(`${t.baseUrl}/api/v2/health`)
    const body = await res.json()

    expect(res.status).toBe(200)
    expect(body.status).toBe('ok')
    expect(body.uptime).toBeGreaterThanOrEqual(0)
    expect(body).toHaveProperty('connections')
    expect(body).toHaveProperty('buffer')
    expect(body).toHaveProperty('sessions')
  })
})
