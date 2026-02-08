import type { LogEntry } from '@logger/shared';
import { afterEach, beforeEach, describe, expect, it } from 'bun:test';
import { LokiForwarder, type LokiForwarderConfig } from './loki-forwarder';

// ─── Helpers ─────────────────────────────────────────────────────────

function makeEntry(overrides: Partial<LogEntry> & { id: string }): LogEntry {
  return {
    timestamp: new Date().toISOString(),
    session_id: 'sess-1',
    severity: 'info',
    type: 'text',
    text: 'hello',
    ...overrides,
  } as LogEntry;
}

interface MockLoki {
  url: string;
  requests: any[];
  setFailCount(n: number): void;
  stop(): void;
}

function createMockLoki(): MockLoki {
  const requests: any[] = [];
  let failCount = 0;

  const server = Bun.serve({
    port: 0,
    async fetch(req) {
      if (
        req.method === 'POST' &&
        new URL(req.url).pathname === '/loki/api/v1/push'
      ) {
        const body = await req.json();
        requests.push(body);

        if (failCount > 0) {
          failCount--;
          return new Response('Internal Server Error', { status: 500 });
        }
        return new Response('', { status: 204 });
      }
      return new Response('Not Found', { status: 404 });
    },
  });

  return {
    url: `http://localhost:${server.port}`,
    requests,
    setFailCount(n: number) {
      failCount = n;
    },
    stop() {
      server.stop(true);
    },
  };
}

// ─── Tests ───────────────────────────────────────────────────────────

describe('LokiForwarder', () => {
  let mock: MockLoki;

  beforeEach(() => {
    mock = createMockLoki();
  });

  afterEach(() => {
    mock.stop();
  });

  function fw(overrides?: Partial<LokiForwarderConfig>): LokiForwarder {
    return new LokiForwarder({
      lokiUrl: mock.url,
      batchSize: 100,
      flushIntervalMs: 60_000,
      maxBuffer: 10_000,
      retries: 3,
      environment: 'test',
      retryBaseMs: 10,
      ...overrides,
    });
  }

  // ── Batching ─────────────────────────────────────────────────────

  it('buffers entries and flushes when batch size reached', async () => {
    const f = fw({ batchSize: 3 });

    f.push(makeEntry({ id: 'e1' }));
    f.push(makeEntry({ id: 'e2' }));
    expect(mock.requests).toHaveLength(0);

    f.push(makeEntry({ id: 'e3' }));
    await Bun.sleep(30);

    expect(mock.requests).toHaveLength(1);
    expect(mock.requests[0].streams[0].values).toHaveLength(3);

    await f.shutdown();
  });

  it('flushes on interval timer', async () => {
    const f = fw({ flushIntervalMs: 50 });

    f.push(makeEntry({ id: 'e1' }));
    f.push(makeEntry({ id: 'e2' }));

    await Bun.sleep(150);

    expect(mock.requests.length).toBeGreaterThanOrEqual(1);
    const total = mock.requests.reduce(
      (sum: number, r: any) => sum + r.streams[0].values.length,
      0,
    );
    expect(total).toBe(2);

    await f.shutdown();
  });

  it('shutdown flushes remaining entries', async () => {
    const f = fw();

    f.push(makeEntry({ id: 'e1' }));
    f.push(makeEntry({ id: 'e2' }));
    expect(mock.requests).toHaveLength(0);

    await f.shutdown();

    expect(mock.requests).toHaveLength(1);
    expect(mock.requests[0].streams[0].values).toHaveLength(2);
  });

  // ── Label grouping ──────────────────────────────────────────────

  it('groups entries by label set correctly', async () => {
    const f = fw();

    f.push(makeEntry({ id: 'e1', severity: 'info', application: { name: 'app-a' } }));
    f.push(makeEntry({ id: 'e2', severity: 'error', application: { name: 'app-a' } }));
    f.push(makeEntry({ id: 'e3', severity: 'info', application: { name: 'app-b' } }));
    f.push(makeEntry({ id: 'e4', severity: 'info', application: { name: 'app-a' } }));

    await f.flush();

    // 3 groups: (app-a, info), (app-a, error), (app-b, info)
    expect(mock.requests).toHaveLength(3);

    const streams = mock.requests.map((r: any) => r.streams[0]);
    const labels = streams.map((s: any) => s.stream);

    expect(labels).toContainEqual({ app: 'app-a', severity: 'info', environment: 'test' });
    expect(labels).toContainEqual({ app: 'app-a', severity: 'error', environment: 'test' });
    expect(labels).toContainEqual({ app: 'app-b', severity: 'info', environment: 'test' });

    const appAInfo = streams.find(
      (s: any) => s.stream.app === 'app-a' && s.stream.severity === 'info',
    );
    expect(appAInfo.values).toHaveLength(2);

    await f.shutdown();
  });

  it('defaults app label to unknown when no application info', async () => {
    const f = fw({ batchSize: 1 });

    f.push(makeEntry({ id: 'e1' }));
    await Bun.sleep(30);

    expect(mock.requests[0].streams[0].stream.app).toBe('unknown');

    await f.shutdown();
  });

  // ── Loki payload format ─────────────────────────────────────────

  it('sends correct Loki push payload with structured metadata', async () => {
    const f = fw({ batchSize: 1 });

    const entry = makeEntry({
      id: 'e1',
      session_id: 'sess-42',
      severity: 'warning',
      type: 'json',
      section: 'network',
      application: { name: 'my-api' },
    });

    f.push(entry);
    await Bun.sleep(30);

    expect(mock.requests).toHaveLength(1);
    const payload = mock.requests[0];

    expect(payload.streams).toHaveLength(1);
    expect(payload.streams[0].stream).toEqual({
      app: 'my-api',
      severity: 'warning',
      environment: 'test',
    });

    const [timestamp, line, metadata] = payload.streams[0].values[0];
    expect(timestamp).toMatch(/^\d+$/);
    expect(JSON.parse(line).id).toBe('e1');
    expect(metadata).toEqual({
      session: 'sess-42',
      section: 'network',
      type: 'json',
    });

    await f.shutdown();
  });

  it('defaults section to events in structured metadata', async () => {
    const f = fw({ batchSize: 1 });

    f.push(makeEntry({ id: 'e1' }));
    await Bun.sleep(30);

    const [, , metadata] = mock.requests[0].streams[0].values[0];
    expect(metadata.section).toBe('events');

    await f.shutdown();
  });

  // ── Retry ───────────────────────────────────────────────────────

  it('retries on failure with backoff', async () => {
    mock.setFailCount(2);
    const f = fw({ batchSize: 1, retries: 3 });

    f.push(makeEntry({ id: 'e1' }));
    await Bun.sleep(150);

    expect(mock.requests).toHaveLength(3); // 2 failures + 1 success
    expect(f.getHealth().consecutiveFailures).toBe(0);

    await f.shutdown();
  });

  it('increments consecutive failures when all retries exhausted', async () => {
    mock.setFailCount(100);
    const f = fw({ batchSize: 1, retries: 2 });

    f.push(makeEntry({ id: 'e1' }));
    await Bun.sleep(100);

    expect(f.getHealth().consecutiveFailures).toBe(1);
    expect(mock.requests).toHaveLength(2);

    await f.shutdown();
  });

  // ── Health states ───────────────────────────────────────────────

  it('reports healthy when buffer below 80%', () => {
    const f = fw({ maxBuffer: 10, batchSize: 100 });

    for (let i = 0; i < 7; i++) f.push(makeEntry({ id: `e${i}` }));

    expect(f.getHealth().status).toBe('healthy');
    f.shutdown();
  });

  it('reports warning when buffer reaches 80%', () => {
    const f = fw({ maxBuffer: 10, batchSize: 100 });

    for (let i = 0; i < 8; i++) f.push(makeEntry({ id: `e${i}` }));

    expect(f.getHealth().status).toBe('warning');
    f.shutdown();
  });

  it('reports full when buffer at max', () => {
    const f = fw({ maxBuffer: 5, batchSize: 100 });

    for (let i = 0; i < 5; i++) f.push(makeEntry({ id: `e${i}` }));

    expect(f.getHealth().status).toBe('full');
    f.shutdown();
  });

  it('reports warning on 3+ consecutive failures', async () => {
    mock.setFailCount(100);
    const f = fw({ batchSize: 1, retries: 1 });

    for (let i = 0; i < 3; i++) {
      f.push(makeEntry({ id: `e${i}` }));
      await Bun.sleep(50);
    }

    expect(f.getHealth().consecutiveFailures).toBeGreaterThanOrEqual(3);
    expect(f.getHealth().status).toBe('warning');

    await f.shutdown();
  });

  // ── Buffer overflow ─────────────────────────────────────────────

  it('drops newest entries when buffer is full', async () => {
    const f = fw({ maxBuffer: 3, batchSize: 100 });

    f.push(makeEntry({ id: 'e1' }));
    f.push(makeEntry({ id: 'e2' }));
    f.push(makeEntry({ id: 'e3' }));
    f.push(makeEntry({ id: 'e4' })); // dropped

    expect(f.getHealth().bufferSize).toBe(3);
    expect(f.getHealth().status).toBe('full');

    await f.flush();

    expect(mock.requests).toHaveLength(1);
    const values = mock.requests[0].streams[0].values;
    expect(values).toHaveLength(3);

    const ids = values.map((v: any) => JSON.parse(v[1]).id);
    expect(ids).toEqual(['e1', 'e2', 'e3']);

    await f.shutdown();
  });
});
