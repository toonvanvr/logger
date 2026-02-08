import { afterAll, beforeAll, describe, expect, it } from 'bun:test';
import { HookManager } from '../core/hooks';
import { processPipeline } from '../core/pipeline';
import { RateLimiter } from '../core/rate-limiter';
import { RingBuffer } from '../modules/ring-buffer';
import { RpcBridge } from '../modules/rpc-bridge';
import { SessionManager } from '../modules/session-manager';
import { WebSocketHub } from '../modules/ws-hub';
import { setupHttpRoutes } from './http';
import type { ServerDeps } from './types';

// ─── Mock Modules ────────────────────────────────────────────────────

class MockLokiForwarder {
  entries: any[] = [];
  push(entry: any) {
    this.entries.push(entry);
  }
  getHealth() {
    return { status: 'healthy' as const, bufferSize: 0, bufferMax: 10000, consecutiveFailures: 0 };
  }
  async shutdown() {}
  async flush() {}
}

class MockFileStore {
  files = new Map<string, { sessionId: string; data: Uint8Array; mimeType: string }>();
  async store(sessionId: string, data: Buffer | Uint8Array, mimeType: string, _label?: string) {
    const ref = crypto.randomUUID();
    this.files.set(ref, { sessionId, data: new Uint8Array(data), mimeType });
    return ref;
  }
  getUsage() {
    return { totalBytes: 0, fileCount: this.files.size };
  }
}

// ─── Test Helpers ────────────────────────────────────────────────────

function createTestDeps(configOverrides?: Record<string, unknown>): ServerDeps {
  const config = {
    host: '127.0.0.1',
    port: 0,
    udpPort: 0,
    tcpPort: 0,
    apiKey: null as string | null,
    environment: 'test',
    ...configOverrides,
  };

  return {
    config,
    pipeline: processPipeline,
    rateLimiter: new RateLimiter(10000, 1000, 2),
    hookManager: new HookManager(),
    ringBuffer: new RingBuffer(10000, 10 * 1024 * 1024),
    sessionManager: new SessionManager({ timeoutMs: 300_000, checkIntervalMs: 999_999 }),
    wsHub: new WebSocketHub(),
    lokiForwarder: new MockLokiForwarder() as any,
    fileStore: new MockFileStore() as any,
    rpcBridge: new RpcBridge(),
  };
}

function makeValidEntry(overrides?: Record<string, unknown>) {
  return {
    id: crypto.randomUUID(),
    timestamp: new Date().toISOString(),
    session_id: 'test-sess',
    severity: 'info',
    type: 'text',
    text: 'test message',
    ...overrides,
  };
}

// ─── Tests ───────────────────────────────────────────────────────────

describe('HTTP Transport', () => {
  let server: ReturnType<typeof Bun.serve>;
  let baseUrl: string;
  let deps: ServerDeps;

  beforeAll(() => {
    deps = createTestDeps();
    const routes = setupHttpRoutes(deps);
    server = Bun.serve({
      port: 0,
      hostname: '127.0.0.1',
      routes,
    });
    baseUrl = `http://127.0.0.1:${server.port}`;
  });

  afterAll(() => {
    server.stop();
    deps.sessionManager.shutdown();
  });

  // ─── /health ─────────────────────────────────────────────────────

  it('GET /health returns ok', async () => {
    const res = await fetch(`${baseUrl}/health`);
    const body = await res.json();
    expect(res.status).toBe(200);
    expect(body.ok).toBe(true);
  });

  // ─── /api/v1/health ──────────────────────────────────────────────

  it('GET /api/v1/health returns detailed health JSON', async () => {
    const res = await fetch(`${baseUrl}/api/v1/health`);
    const body = await res.json();
    expect(res.status).toBe(200);
    expect(body.ok).toBe(true);
    expect(body.uptime).toBeGreaterThanOrEqual(0);
    expect(body).toHaveProperty('connections');
    expect(body).toHaveProperty('buffer');
    expect(body.buffer).toHaveProperty('entries');
    expect(body.buffer).toHaveProperty('bytes');
    expect(body).toHaveProperty('loki');
    expect(body).toHaveProperty('sessions');
    expect(body).toHaveProperty('rpcPending');
  });

  // ─── /api/v1/log ─────────────────────────────────────────────────

  it('POST /api/v1/log with valid entry returns 200', async () => {
    const entry = makeValidEntry();
    const res = await fetch(`${baseUrl}/api/v1/log`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(entry),
    });
    const body = await res.json();
    expect(res.status).toBe(200);
    expect(body.ok).toBe(true);
    expect(body.id).toBe(entry.id);
  });

  it('POST /api/v1/log with invalid entry returns 400', async () => {
    const res = await fetch(`${baseUrl}/api/v1/log`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ bad: 'data' }),
    });
    const body = await res.json();
    expect(res.status).toBe(400);
    expect(body.ok).toBe(false);
    expect(body.error).toContain('Validation failed');
  });

  it('POST /api/v1/log with invalid JSON returns 400', async () => {
    const res = await fetch(`${baseUrl}/api/v1/log`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: 'not json',
    });
    const body = await res.json();
    expect(res.status).toBe(400);
    expect(body.ok).toBe(false);
  });

  // ─── /api/v1/logs ────────────────────────────────────────────────

  it('POST /api/v1/logs batch returns 200 with counts', async () => {
    const entries = [makeValidEntry(), makeValidEntry(), makeValidEntry()];
    const res = await fetch(`${baseUrl}/api/v1/logs`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ entries }),
    });
    const body = await res.json();
    expect(res.status).toBe(200);
    expect(body.ok).toBe(true);
    expect(body.count).toBe(3);
    expect(body.ids).toHaveLength(3);
  });

  it('POST /api/v1/logs with empty batch returns 400', async () => {
    const res = await fetch(`${baseUrl}/api/v1/logs`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ entries: [] }),
    });
    const body = await res.json();
    expect(res.status).toBe(400);
    expect(body.ok).toBe(false);
  });

  // ─── /api/v1/sessions ────────────────────────────────────────────

  it('GET /api/v1/sessions returns sessions list', async () => {
    const res = await fetch(`${baseUrl}/api/v1/sessions`);
    expect(res.status).toBe(200);
    const body = await res.json();
    expect(Array.isArray(body)).toBe(true);
  });

  // ─── /log (legacy) ───────────────────────────────────────────────

  it('POST /log legacy endpoint returns 200', async () => {
    const legacy = {
      severity: 'info',
      payload: 'legacy log message',
      application: { name: 'test-app', version: '1.0', sessionId: 'legacy-sess' },
    };
    const res = await fetch(`${baseUrl}/log`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(legacy),
    });
    const body = await res.json();
    expect(res.status).toBe(200);
    expect(body.ok).toBe(true);
    expect(body.id).toBeDefined();
  });

  // ─── Rate limiting ───────────────────────────────────────────────

  it('returns 429 when rate limited', async () => {
    const rlDeps = createTestDeps();
    rlDeps.rateLimiter = new RateLimiter(1000, 2, 1); // 2 per session, no burst

    const routes = setupHttpRoutes(rlDeps);
    const rlServer = Bun.serve({ port: 0, hostname: '127.0.0.1', routes });
    const rlUrl = `http://127.0.0.1:${rlServer.port}`;

    try {
      // First two should succeed
      for (let i = 0; i < 2; i++) {
        const res = await fetch(`${rlUrl}/api/v1/log`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(makeValidEntry()),
        });
        expect(res.status).toBe(200);
      }

      // Third should be rate limited
      const res = await fetch(`${rlUrl}/api/v1/log`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(makeValidEntry()),
      });
      expect(res.status).toBe(429);
      const body = await res.json();
      expect(body.ok).toBe(false);
      expect(body.error).toContain('Rate limit');
    } finally {
      rlServer.stop();
      rlDeps.sessionManager.shutdown();
    }
  });

  // ─── Auth ─────────────────────────────────────────────────────────

  describe('with auth enabled', () => {
    let authServer: ReturnType<typeof Bun.serve>;
    let authUrl: string;
    let authDeps: ServerDeps;

    beforeAll(() => {
      authDeps = createTestDeps({ apiKey: 'test-secret-key' });
      const routes = setupHttpRoutes(authDeps);
      authServer = Bun.serve({ port: 0, hostname: '127.0.0.1', routes });
      authUrl = `http://127.0.0.1:${authServer.port}`;
    });

    afterAll(() => {
      authServer.stop();
      authDeps.sessionManager.shutdown();
    });

    it('rejects requests without auth', async () => {
      const res = await fetch(`${authUrl}/api/v1/log`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(makeValidEntry()),
      });
      expect(res.status).toBe(401);
      const body = await res.json();
      expect(body.ok).toBe(false);
    });

    it('accepts requests with Bearer token', async () => {
      const res = await fetch(`${authUrl}/api/v1/log`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: 'Bearer test-secret-key',
        },
        body: JSON.stringify(makeValidEntry()),
      });
      expect(res.status).toBe(200);
    });

    it('accepts requests with X-API-Key header', async () => {
      const res = await fetch(`${authUrl}/api/v1/log`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-API-Key': 'test-secret-key',
        },
        body: JSON.stringify(makeValidEntry()),
      });
      expect(res.status).toBe(200);
    });

    it('rejects requests with wrong key', async () => {
      const res = await fetch(`${authUrl}/api/v1/log`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: 'Bearer wrong-key',
        },
        body: JSON.stringify(makeValidEntry()),
      });
      expect(res.status).toBe(401);
    });

    it('does not require auth for /health', async () => {
      const res = await fetch(`${authUrl}/health`);
      expect(res.status).toBe(200);
    });
  });
});
