import { afterAll, beforeAll, describe, expect, it } from 'bun:test';
import {
    createTestServer,
    makeLegacyEntry,
    makeSessionEntry,
    makeValidEntry,
    type TestServerInstance,
} from './test-utils';

// ─── Test Server Setup ───────────────────────────────────────────────

let t: TestServerInstance;

beforeAll(() => {
  t = createTestServer();
});

afterAll(() => {
  t.cleanup();
});

// ─── Helpers ─────────────────────────────────────────────────────────

async function postJson(path: string, body: unknown, headers?: Record<string, string>) {
  return fetch(`${t.baseUrl}${path}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', ...headers },
    body: JSON.stringify(body),
  });
}

// ─── Integration Tests ───────────────────────────────────────────────

describe('Integration: HTTP single log round-trip', () => {
  it('POST /api/v1/log with valid entry returns 200 and echoes id', async () => {
    const entry = makeValidEntry();
    const res = await postJson('/api/v1/log', entry);
    const body = await res.json();

    expect(res.status).toBe(200);
    expect(body.ok).toBe(true);
    expect(body.id).toBe(entry.id);
  });

  it('POST /api/v1/log with missing required fields returns 400', async () => {
    const res = await postJson('/api/v1/log', { bad: 'data' });
    const body = await res.json();

    expect(res.status).toBe(400);
    expect(body.ok).toBe(false);
    expect(body.error).toContain('Validation failed');
  });
});

describe('Integration: HTTP batch log', () => {
  it('POST /api/v1/logs with multiple entries returns 200 and correct count', async () => {
    const entries = [
      makeValidEntry({ session_id: 'batch-sess' }),
      makeValidEntry({ session_id: 'batch-sess' }),
      makeValidEntry({ session_id: 'batch-sess' }),
    ];
    const res = await postJson('/api/v1/logs', { entries });
    const body = await res.json();

    expect(res.status).toBe(200);
    expect(body.ok).toBe(true);
    expect(body.count).toBe(3);
    expect(body.ids).toHaveLength(3);
  });

  it('POST /api/v1/logs with empty batch returns 400', async () => {
    const res = await postJson('/api/v1/logs', { entries: [] });
    const body = await res.json();

    expect(res.status).toBe(400);
    expect(body.ok).toBe(false);
  });
});

describe('Integration: HTTP legacy endpoint', () => {
  it('POST /log with legacy LogRequest format returns 200 and converts', async () => {
    const legacy = makeLegacyEntry();
    const res = await postJson('/log', legacy);
    const body = await res.json();

    expect(res.status).toBe(200);
    expect(body.ok).toBe(true);
    expect(body.id).toBeDefined();
    expect(typeof body.id).toBe('string');
  });

  it('POST /log with JSON payload converts to json type', async () => {
    const legacy = makeLegacyEntry({ payload: { key: 'value', nested: true } });
    const res = await postJson('/log', legacy);
    const body = await res.json();

    expect(res.status).toBe(200);
    expect(body.ok).toBe(true);
  });
});

describe('Integration: WebSocket client connection', () => {
  it('connects via WS, sends a log entry, and receives ack', async () => {
    const entry = makeValidEntry({ session_id: 'ws-test-sess' });

    const ack = await new Promise<any>((resolve, reject) => {
      const ws = new WebSocket(t.wsUrl, {
        headers: { 'X-Logger-Role': 'client', 'X-Session-Id': 'ws-test-sess' },
      } as any);

      const timeout = setTimeout(() => {
        ws.close();
        reject(new Error('WebSocket ack timeout'));
      }, 5000);

      ws.onopen = () => {
        // Server WS handler expects individual entries, not arrays
        ws.send(JSON.stringify(entry));
      };

      ws.onmessage = (event: MessageEvent) => {
        clearTimeout(timeout);
        const data = JSON.parse(String(event.data));
        ws.close();
        resolve(data);
      };

      ws.onerror = () => {
        clearTimeout(timeout);
        reject(new Error('WebSocket error'));
      };
    });

    expect(ack.type).toBe('ack');
    expect(ack.ack_ids).toContain(entry.id);
  });

  it('receives error for invalid entry over WS', async () => {
    const error = await new Promise<any>((resolve, reject) => {
      const ws = new WebSocket(t.wsUrl, {
        headers: { 'X-Logger-Role': 'client' },
      } as any);

      const timeout = setTimeout(() => {
        ws.close();
        reject(new Error('WebSocket response timeout'));
      }, 5000);

      ws.onopen = () => {
        ws.send(JSON.stringify({ bad: 'data' }));
      };

      ws.onmessage = (event: MessageEvent) => {
        clearTimeout(timeout);
        const data = JSON.parse(String(event.data));
        ws.close();
        resolve(data);
      };

      ws.onerror = () => {
        clearTimeout(timeout);
        reject(new Error('WebSocket error'));
      };
    });

    expect(error.type).toBe('error');
    expect(error.error_message).toContain('Validation failed');
  });
});

describe('Integration: Ring buffer persistence', () => {
  it('logs via HTTP appear in ring buffer and sessions endpoint', async () => {
    const sessionId = `ring-buf-sess-${Date.now()}`;

    // Send 5 logs
    for (let i = 0; i < 5; i++) {
      const entry = makeValidEntry({
        session_id: sessionId,
        text: `ring buffer test ${i}`,
        application: { name: 'ring-test' },
      });
      const res = await postJson('/api/v1/log', entry);
      expect(res.status).toBe(200);
    }

    // Verify session exists via /api/v1/sessions
    const sessRes = await fetch(`${t.baseUrl}/api/v1/sessions`);
    expect(sessRes.status).toBe(200);
    const sessions: any[] = await sessRes.json();
    const found = sessions.find((s) => s.sessionId === sessionId);

    expect(found).toBeDefined();
    expect(found.logCount).toBe(5);

    // Verify entries are in ring buffer
    expect(t.deps.ringBuffer.size).toBeGreaterThanOrEqual(5);
  });
});

describe('Integration: Session lifecycle', () => {
  it('session start → logs → session end transitions correctly', async () => {
    const sessionId = `lifecycle-sess-${Date.now()}`;

    // 1. Send session start
    const startEntry = makeSessionEntry(sessionId, 'start');
    const startRes = await postJson('/api/v1/log', startEntry);
    expect(startRes.status).toBe(200);

    // Verify session is active
    let session = t.deps.sessionManager.getSession(sessionId);
    expect(session).toBeDefined();
    expect(session!.isActive).toBe(true);

    // 2. Send some regular logs
    for (let i = 0; i < 3; i++) {
      const entry = makeValidEntry({
        session_id: sessionId,
        text: `lifecycle log ${i}`,
        application: { name: 'lifecycle-test' },
      });
      await postJson('/api/v1/log', entry);
    }

    // Verify log count increased (session start + 3 logs = 4 total)
    session = t.deps.sessionManager.getSession(sessionId);
    expect(session!.logCount).toBe(4);

    // 3. Send session end
    const endEntry = makeSessionEntry(sessionId, 'end');
    const endRes = await postJson('/api/v1/log', endEntry);
    expect(endRes.status).toBe(200);

    // Verify session is no longer active
    session = t.deps.sessionManager.getSession(sessionId);
    expect(session).toBeDefined();
    expect(session!.isActive).toBe(false);
  });

  it('session appears in GET /api/v1/sessions after start', async () => {
    const sessionId = `list-sess-${Date.now()}`;

    await postJson('/api/v1/log', makeSessionEntry(sessionId, 'start'));

    const res = await fetch(`${t.baseUrl}/api/v1/sessions`);
    const sessions: any[] = await res.json();
    const found = sessions.find((s) => s.sessionId === sessionId);

    expect(found).toBeDefined();
    expect(found.isActive).toBe(true);
    expect(found.application.name).toBe('integration-test');
  });
});

describe('Integration: RPC round-trip', () => {
  // TODO: Full RPC round-trip requires coordinating a client WS (with registered tools),
  // a viewer WS (sending rpc_request), and the RPC bridge routing between them.
  // This is complex to test end-to-end; skipping for now.
  it.todo('viewer sends RPC request → client receives and responds');
});

describe('Integration: Rate limiting', () => {
  it('returns 429 when per-session rate limit is exceeded', async () => {
    // Create a separate server with very low rate limits
    const rlServer = createTestServer({
      rateLimitGlobal: 1000,
      rateLimitPerSession: 2,
      rateLimitBurst: 1, // 2 per session, no burst
    });
    const rlUrl = rlServer.baseUrl;

    try {
      const sessionId = 'rate-limit-test';

      // First two should succeed
      for (let i = 0; i < 2; i++) {
        const res = await fetch(`${rlUrl}/api/v1/log`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(makeValidEntry({ session_id: sessionId })),
        });
        expect(res.status).toBe(200);
      }

      // Third should be rate limited
      const res = await fetch(`${rlUrl}/api/v1/log`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(makeValidEntry({ session_id: sessionId })),
      });
      expect(res.status).toBe(429);
      const body = await res.json();
      expect(body.ok).toBe(false);
      expect(body.error).toContain('Rate limit');
    } finally {
      rlServer.cleanup();
    }
  });

  it('rate limit is per-session — different sessions are independent', async () => {
    const rlServer = createTestServer({
      rateLimitGlobal: 1000,
      rateLimitPerSession: 2,
      rateLimitBurst: 1,
    });

    try {
      // Fill session A
      for (let i = 0; i < 2; i++) {
        const res = await fetch(`${rlServer.baseUrl}/api/v1/log`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(makeValidEntry({ session_id: 'sess-a' })),
        });
        expect(res.status).toBe(200);
      }

      // Session A is now rate limited
      const limitedRes = await fetch(`${rlServer.baseUrl}/api/v1/log`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(makeValidEntry({ session_id: 'sess-a' })),
      });
      expect(limitedRes.status).toBe(429);

      // Session B should still succeed
      const resSessB = await fetch(`${rlServer.baseUrl}/api/v1/log`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(makeValidEntry({ session_id: 'sess-b' })),
      });
      expect(resSessB.status).toBe(200);
    } finally {
      rlServer.cleanup();
    }
  });
});

describe('Integration: Health endpoints', () => {
  it('GET /health returns basic ok', async () => {
    const res = await fetch(`${t.baseUrl}/health`);
    const body = await res.json();

    expect(res.status).toBe(200);
    expect(body.ok).toBe(true);
  });

  it('GET /api/v1/health returns detailed health after activity', async () => {
    const res = await fetch(`${t.baseUrl}/api/v1/health`);
    const body = await res.json();

    expect(res.status).toBe(200);
    expect(body.ok).toBe(true);
    expect(body.uptime).toBeGreaterThanOrEqual(0);
    expect(body).toHaveProperty('connections');
    expect(body).toHaveProperty('buffer');
    expect(body).toHaveProperty('sessions');
  });
});
