import type { LogEntry, ServerMessage, ViewerMessage } from '@logger/shared';
import type { ServerWebSocket } from 'bun';
import { describe, expect, it } from 'bun:test';
import { WebSocketHub } from './ws-hub';

// ─── Mock WebSocket ──────────────────────────────────────────────────

class MockWebSocket {
  sent: any[] = [];
  send(data: string) {
    this.sent.push(JSON.parse(data));
  }
  close() {}
  readyState = 1;
}

// ─── Helpers ─────────────────────────────────────────────────────────

function makeLogMessage(overrides: Partial<LogEntry> & { id: string }): ServerMessage {
  return {
    type: 'log',
    entry: {
      timestamp: new Date().toISOString(),
      session_id: 'sess-1',
      severity: 'info',
      type: 'text',
      text: 'hello',
      ...overrides,
    } as LogEntry,
  };
}

// ─── Tests ───────────────────────────────────────────────────────────

describe('WebSocketHub', () => {
  it('adds and removes viewers', () => {
    const hub = new WebSocketHub();
    const ws1 = new MockWebSocket() as unknown as ServerWebSocket<any>;
    const ws2 = new MockWebSocket() as unknown as ServerWebSocket<any>;

    hub.addViewer(ws1);
    hub.addViewer(ws2);
    expect(hub.getViewerCount()).toBe(2);

    hub.removeViewer(ws1);
    expect(hub.getViewerCount()).toBe(1);
  });

  it('broadcasts to all viewers', () => {
    const hub = new WebSocketHub();
    const ws1 = new MockWebSocket() as unknown as ServerWebSocket<any>;
    const ws2 = new MockWebSocket() as unknown as ServerWebSocket<any>;
    const mock1 = ws1 as unknown as MockWebSocket;
    const mock2 = ws2 as unknown as MockWebSocket;

    hub.addViewer(ws1);
    hub.addViewer(ws2);

    const msg = makeLogMessage({ id: 'e1' });
    hub.broadcast(msg);

    expect(mock1.sent).toHaveLength(1);
    expect(mock1.sent[0].type).toBe('log');
    expect(mock2.sent).toHaveLength(1);
  });

  it('filters by sessionId subscription', () => {
    const hub = new WebSocketHub();
    const ws = new MockWebSocket() as unknown as ServerWebSocket<any>;
    const mock = ws as unknown as MockWebSocket;

    hub.addViewer(ws);
    hub.setSubscription(ws, { sessionIds: ['sess-a'] });

    hub.broadcast(makeLogMessage({ id: 'e1', session_id: 'sess-a' }));
    hub.broadcast(makeLogMessage({ id: 'e2', session_id: 'sess-b' }));

    expect(mock.sent).toHaveLength(1);
    expect(mock.sent[0].entry.session_id).toBe('sess-a');
  });

  it('filters by severity', () => {
    const hub = new WebSocketHub();
    const ws = new MockWebSocket() as unknown as ServerWebSocket<any>;
    const mock = ws as unknown as MockWebSocket;

    hub.addViewer(ws);
    hub.setSubscription(ws, { sessionIds: [], minSeverity: 'warning' });

    hub.broadcast(makeLogMessage({ id: 'e1', severity: 'debug' }));
    hub.broadcast(makeLogMessage({ id: 'e2', severity: 'info' }));
    hub.broadcast(makeLogMessage({ id: 'e3', severity: 'warning' }));
    hub.broadcast(makeLogMessage({ id: 'e4', severity: 'error' }));
    hub.broadcast(makeLogMessage({ id: 'e5', severity: 'critical' }));

    expect(mock.sent).toHaveLength(3);
    expect(mock.sent.map((m: any) => m.entry.severity)).toEqual(['warning', 'error', 'critical']);
  });

  it('filters by text in entry text and tags', () => {
    const hub = new WebSocketHub();
    const ws = new MockWebSocket() as unknown as ServerWebSocket<any>;
    const mock = ws as unknown as MockWebSocket;

    hub.addViewer(ws);
    hub.setSubscription(ws, { sessionIds: [], textFilter: 'needle' });

    hub.broadcast(makeLogMessage({ id: 'e1', text: 'This has a NEEDLE in it' }));
    hub.broadcast(makeLogMessage({ id: 'e2', text: 'No match here' }));
    hub.broadcast(
      makeLogMessage({
        id: 'e3',
        text: 'Tag match',
        tags: { env: 'Needle-prod' },
      }),
    );

    expect(mock.sent).toHaveLength(2);
    expect(mock.sent.map((m: any) => m.entry.id)).toEqual(['e1', 'e3']);
  });

  it('tracks viewer count correctly', () => {
    const hub = new WebSocketHub();
    expect(hub.getViewerCount()).toBe(0);

    const viewers = Array.from({ length: 5 }, () => new MockWebSocket() as unknown as ServerWebSocket<any>);
    for (const ws of viewers) hub.addViewer(ws);
    expect(hub.getViewerCount()).toBe(5);

    hub.removeViewer(viewers[0]);
    hub.removeViewer(viewers[1]);
    expect(hub.getViewerCount()).toBe(3);
  });

  it('handles subscribe message and updates filter', () => {
    const hub = new WebSocketHub();
    const ws = new MockWebSocket() as unknown as ServerWebSocket<any>;

    hub.addViewer(ws);

    const subscribeMsg: ViewerMessage = {
      type: 'subscribe',
      session_ids: ['sess-x', 'sess-y'],
      min_severity: 'error',
      sections: ['network'],
      text_filter: 'timeout',
    };

    hub.handleViewerMessage(ws, subscribeMsg);

    const sub = hub.getSubscription(ws)!;
    expect(sub.sessionIds).toEqual(['sess-x', 'sess-y']);
    expect(sub.minSeverity).toBe('error');
    expect(sub.sections).toEqual(['network']);
    expect(sub.textFilter).toBe('timeout');
  });

  it('handles unsubscribe message and resets filter', () => {
    const hub = new WebSocketHub();
    const ws = new MockWebSocket() as unknown as ServerWebSocket<any>;

    hub.addViewer(ws);
    hub.setSubscription(ws, { sessionIds: ['sess-1'], minSeverity: 'error' });

    hub.handleViewerMessage(ws, { type: 'unsubscribe' });

    const sub = hub.getSubscription(ws)!;
    expect(sub.sessionIds).toEqual([]);
    expect(sub.minSeverity).toBeUndefined();
  });

  it('non-log messages are broadcast to all viewers regardless of filter', () => {
    const hub = new WebSocketHub();
    const ws = new MockWebSocket() as unknown as ServerWebSocket<any>;
    const mock = ws as unknown as MockWebSocket;

    hub.addViewer(ws);
    hub.setSubscription(ws, { sessionIds: ['sess-other'] });

    // A session_list message (not a log) should go through
    const msg: ServerMessage = { type: 'session_list', sessions: [] };
    hub.broadcast(msg);

    expect(mock.sent).toHaveLength(1);
    expect(mock.sent[0].type).toBe('session_list');
  });

  it('filters by section', () => {
    const hub = new WebSocketHub();
    const ws = new MockWebSocket() as unknown as ServerWebSocket<any>;
    const mock = ws as unknown as MockWebSocket;

    hub.addViewer(ws);
    hub.setSubscription(ws, { sessionIds: [], sections: ['network'] });

    hub.broadcast(makeLogMessage({ id: 'e1', section: 'network' }));
    hub.broadcast(makeLogMessage({ id: 'e2', section: 'database' }));
    hub.broadcast(makeLogMessage({ id: 'e3' })); // defaults to 'events', should be filtered

    expect(mock.sent).toHaveLength(1);
    expect(mock.sent[0].entry.id).toBe('e1');
  });
});
