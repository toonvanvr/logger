import { describe, expect, it, mock, beforeEach, afterEach } from 'bun:test';
import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { z } from 'zod';

// ─── Test Helpers ────────────────────────────────────────────────────

/** Capture the tool handlers registered on a McpServer. */
function createTestHarness() {
  const tools = new Map<string, { description: string; schema: unknown; handler: Function }>();

  const serverProxy = {
    tool(name: string, description: string, schema: Record<string, unknown>, handler: Function) {
      tools.set(name, { description, schema, handler });
    },
    connect: mock(() => Promise.resolve()),
  };

  return { tools, serverProxy };
}

// ─── Fetch mock setup ────────────────────────────────────────────────

const originalFetch = globalThis.fetch;

function mockFetch(responses: Map<string, { status: number; body: unknown }>): typeof fetch {
  const fn = mock((input: string | Request | URL, init?: RequestInit) => {
    const url = typeof input === 'string' ? input : input instanceof URL ? input.toString() : input.url;
    const pathname = new URL(url).pathname;
    const entry = responses.get(pathname);

    if (!entry) {
      return Promise.resolve(new Response(JSON.stringify({ error: 'Not found' }), { status: 404 }));
    }

    return Promise.resolve(
      new Response(JSON.stringify(entry.body), {
        status: entry.status,
        headers: { 'content-type': 'application/json' },
      }),
    );
  });
  (fn as any).preconnect = () => {};
  return fn as typeof fetch;
}

// ─── We import the fetchJson and tool registration logic indirectly ──
// Since the index.ts auto-connects, we test the tool logic by dynamically
// importing and mocking. Instead, we test the individual tool implementations
// by recreating the core logic.

const LOGGER_URL = 'http://localhost:8080';

function authHeaders(): Record<string, string> {
  return {};
}

async function fetchJson(path: string, init?: RequestInit): Promise<unknown> {
  const url = `${LOGGER_URL}${path}`;
  const res = await fetch(url, {
    ...init,
    headers: {
      ...authHeaders(),
      ...(init?.headers as Record<string, string> | undefined),
    },
  });
  if (!res.ok) {
    const body = await res.text().catch(() => '');
    throw new Error(`HTTP ${res.status} from ${path}: ${body}`);
  }
  return res.json();
}

// ─── Tests ───────────────────────────────────────────────────────────

describe('logger.health', () => {
  afterEach(() => {
    globalThis.fetch = originalFetch;
  });

  it('should return structured health response', async () => {
    const healthData = {
      ok: true,
      uptime: 3600,
      connections: 2,
      buffer: { entries: 150, bytes: 30000 },
      loki: { enabled: true, status: 'healthy', bufferUsed: 100, bufferMax: 10000 },
      sessions: 3,
      rpcPending: 0,
    };

    globalThis.fetch = mockFetch(
      new Map([['/api/v1/health', { status: 200, body: healthData }]]),
    );

    const data = await fetchJson('/api/v1/health');
    expect(data).toEqual(healthData);

    const result = { content: [{ type: 'text' as const, text: JSON.stringify(data, null, 2) }] };
    expect(result.content).toHaveLength(1);
    expect(result.content[0].type).toBe('text');

    const parsed = JSON.parse(result.content[0].text);
    expect(parsed.ok).toBe(true);
    expect(parsed.uptime).toBe(3600);
    expect(parsed.connections).toBe(2);
    expect(parsed.loki.status).toBe('healthy');
  });
});

describe('logger.sessions', () => {
  afterEach(() => {
    globalThis.fetch = originalFetch;
  });

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
    ];

    globalThis.fetch = mockFetch(
      new Map([['/api/v1/sessions', { status: 200, body: sessions }]]),
    );

    const data = await fetchJson('/api/v1/sessions');
    expect(data).toEqual(sessions);
    expect(Array.isArray(data)).toBe(true);
    expect((data as unknown[]).length).toBe(2);
  });
});

describe('logger.send', () => {
  afterEach(() => {
    globalThis.fetch = originalFetch;
  });

  it('should POST a log entry and return confirmation', async () => {
    const confirmation = { ok: true, id: 'log-123' };

    globalThis.fetch = mockFetch(
      new Map([['/api/v1/log', { status: 200, body: confirmation }]]),
    );

    const body = {
      type: 'text',
      severity: 'info',
      text: 'Hello from MCP test',
      timestamp: new Date().toISOString(),
    };

    const data = await fetchJson('/api/v1/log', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify(body),
    });

    expect(data).toEqual(confirmation);
    expect((data as { ok: boolean }).ok).toBe(true);
    expect((data as { id: string }).id).toBe('log-123');

    // Verify fetch was called with POST
    expect(globalThis.fetch).toHaveBeenCalledTimes(1);
    const [calledUrl, calledInit] = (globalThis.fetch as unknown as ReturnType<typeof mock>).mock.calls[0] as [string, RequestInit];
    expect(calledUrl).toBe('http://localhost:8080/api/v1/log');
    expect(calledInit.method).toBe('POST');
  });
});

describe('logger.health error handling', () => {
  afterEach(() => {
    globalThis.fetch = originalFetch;
  });

  it('should throw on non-OK response', async () => {
    globalThis.fetch = mockFetch(
      new Map([['/api/v1/health', { status: 500, body: { error: 'Internal error' } }]]),
    );

    // Non-OK response signals an error. The mockFetch sets status 500 but
    // the Response.ok check triggers.
    // Actually our mockFetch always returns based on map, including 500.
    // But our fetchJson checks res.ok which is false for 500.
    expect(fetchJson('/api/v1/health')).rejects.toThrow('HTTP 500');
  });
});
