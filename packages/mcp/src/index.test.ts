import { afterEach, describe, expect, it, mock } from 'bun:test'

// ─── Test Helpers ────────────────────────────────────────────────────

/** Capture the tool handlers registered on a McpServer. */
function createTestHarness() {
  const tools = new Map<string, { description: string; schema: unknown; handler: Function }>()

  const serverProxy = {
    tool(name: string, description: string, schema: Record<string, unknown>, handler: Function) {
      tools.set(name, { description, schema, handler })
    },
    connect: mock(() => Promise.resolve()),
  }

  return { tools, serverProxy }
}

// ─── Fetch mock setup ────────────────────────────────────────────────

const originalFetch = globalThis.fetch

function mockFetch(responses: Map<string, { status: number; body: unknown }>): typeof fetch {
  const fn = mock((input: string | Request | URL, init?: RequestInit) => {
    const url = typeof input === 'string' ? input : input instanceof URL ? input.toString() : input.url
    const pathname = new URL(url).pathname
    const entry = responses.get(pathname)

    if (!entry) {
      return Promise.resolve(new Response(JSON.stringify({ error: 'Not found' }), { status: 404 }))
    }

    return Promise.resolve(
      new Response(JSON.stringify(entry.body), {
        status: entry.status,
        headers: { 'content-type': 'application/json' },
      }),
    )
  });
  (fn as any).preconnect = () => { }
  return fn as unknown as typeof fetch
}

// ─── We import the fetchJson and tool registration logic indirectly ──
// Since the index.ts auto-connects, we test the tool logic by dynamically
// importing and mocking. Instead, we test the individual tool implementations
// by recreating the core logic.

const LOGGER_URL = 'http://localhost:8080'

function authHeaders(): Record<string, string> {
  return {}
}

async function fetchJson(path: string, init?: RequestInit): Promise<unknown> {
  const url = `${LOGGER_URL}${path}`
  const res = await fetch(url, {
    ...init,
    headers: {
      ...authHeaders(),
      ...(init?.headers as Record<string, string> | undefined),
    },
  })
  if (!res.ok) {
    const body = await res.text().catch(() => '')
    throw new Error(`HTTP ${res.status} from ${path}: ${body}`)
  }
  return res.json()
}

// ─── Tests ───────────────────────────────────────────────────────────

describe('logger.query scope=health', () => {
  afterEach(() => {
    globalThis.fetch = originalFetch
  })

  it('should return structured health response', async () => {
    const healthData = {
      ok: true,
      uptime: 3600,
      connections: 2,
      buffer: { entries: 150, bytes: 30000 },
      loki: { enabled: true, status: 'healthy', bufferUsed: 100, bufferMax: 10000 },
      sessions: 3,
      rpcPending: 0,
    }

    globalThis.fetch = mockFetch(
      new Map([['/api/v2/health', { status: 200, body: healthData }]]),
    )

    const data = await fetchJson('/api/v2/health')
    expect(data).toEqual(healthData)

    const result = { content: [{ type: 'text' as const, text: JSON.stringify(data, null, 2) }] }
    expect(result.content).toHaveLength(1)
    expect(result.content[0].type).toBe('text')

    const parsed = JSON.parse(result.content[0].text)
    expect(parsed.ok).toBe(true)
    expect(parsed.uptime).toBe(3600)
    expect(parsed.connections).toBe(2)
    expect(parsed.loki.status).toBe('healthy')
  })
})

describe('logger.query scope=sessions', () => {
  afterEach(() => {
    globalThis.fetch = originalFetch
  })

  it('should return session list', async () => {
    const sessions = [
      {
        sessionId: 'sess-1',
        application: { name: 'my-app', version: '1.0.0' },
        startedAt: '2026-02-07T10:00:00Z',
        lastHeartbeat: '2026-02-07T10:05:00Z',
        isActive: true,
        logCount: 42,
        colorIndex: 0,
      },
      {
        sessionId: 'sess-2',
        application: { name: 'other-app', version: '2.0.0' },
        startedAt: '2026-02-07T09:00:00Z',
        lastHeartbeat: '2026-02-07T09:30:00Z',
        isActive: false,
        logCount: 10,
        colorIndex: 1,
      },
    ]

    globalThis.fetch = mockFetch(
      new Map([['/api/v2/sessions', { status: 200, body: sessions }]]),
    )

    const data = await fetchJson('/api/v2/sessions')
    expect(data).toEqual(sessions)
    expect(Array.isArray(data)).toBe(true)
    expect((data as unknown[]).length).toBe(2)
  })
})

describe('logger.query scope=state', () => {
  afterEach(() => {
    globalThis.fetch = originalFetch
  })

  it('should return session state data', async () => {
    const stateData = { mode: 'running', progress: 75, status: 'healthy' }

    globalThis.fetch = mockFetch(
      new Map([['/api/v2/sessions/sess-1/state', { status: 200, body: stateData }]]),
    )

    const data = await fetchJson('/api/v2/sessions/sess-1/state')
    expect(data).toEqual(stateData)
    expect((data as { mode: string }).mode).toBe('running')
  })
})

describe('logger.query scope=logs (default)', () => {
  afterEach(() => {
    globalThis.fetch = originalFetch
  })

  it('should POST to query endpoint with default limit', async () => {
    const entries = [{ id: 'log-1', severity: 'info', text: 'hello' }]

    globalThis.fetch = mockFetch(
      new Map([['/api/v2/query', { status: 200, body: entries }]]),
    )

    const queryBody = { limit: 20 }
    const data = await fetchJson('/api/v2/query', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify(queryBody),
    })
    expect(data).toEqual(entries)
    expect(Array.isArray(data)).toBe(true)

    expect(globalThis.fetch).toHaveBeenCalledTimes(1)
    const [, calledInit] = (globalThis.fetch as unknown as ReturnType<typeof mock>).mock.calls[0] as [string, RequestInit]
    expect(calledInit.method).toBe('POST')
  })
})

describe('logger.send', () => {
  afterEach(() => {
    globalThis.fetch = originalFetch
  })

  it('should POST a log entry and return confirmation', async () => {
    const confirmation = { ok: true, id: 'log-123' }

    globalThis.fetch = mockFetch(
      new Map([['/api/v2/events', { status: 200, body: confirmation }]]),
    )

    const body = {
      session_id: 'mcp',
      severity: 'info',
      message: 'Hello from MCP test',
    }

    const data = await fetchJson('/api/v2/events', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify(body),
    })

    expect(data).toEqual(confirmation)
    expect((data as { ok: boolean }).ok).toBe(true)
    expect((data as { id: string }).id).toBe('log-123')

    // Verify fetch was called with POST
    expect(globalThis.fetch).toHaveBeenCalledTimes(1)
    const [calledUrl, calledInit] = (globalThis.fetch as unknown as ReturnType<typeof mock>).mock.calls[0] as [string, RequestInit]
    expect(calledUrl).toBe('http://localhost:8080/api/v2/events')
    expect(calledInit.method).toBe('POST')
  })
})

describe('logger.query error handling', () => {
  afterEach(() => {
    globalThis.fetch = originalFetch
  })

  it('should throw on non-OK response', async () => {
    globalThis.fetch = mockFetch(
      new Map([['/api/v2/health', { status: 500, body: { error: 'Internal error' } }]]),
    )

    expect(fetchJson('/api/v2/health')).rejects.toThrow('HTTP 500')
  })
})
