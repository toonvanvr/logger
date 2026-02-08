import type { LogEntry } from '@logger/shared';
import { afterEach, describe, expect, it } from 'bun:test';
import { SessionManager, type SessionEvent } from './session-manager';

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

function makeSessionEntry(
  sessionId: string,
  action: 'start' | 'end' | 'heartbeat',
  app?: { name: string },
): LogEntry {
  return makeEntry({
    id: `${sessionId}-${action}-${Date.now()}`,
    session_id: sessionId,
    type: 'session',
    session_action: action,
    application: app ?? { name: 'test-app' },
  });
}

// ─── Tests ───────────────────────────────────────────────────────────

describe('SessionManager', () => {
  let manager: SessionManager;

  afterEach(() => {
    manager?.shutdown();
  });

  it('creates session on first log via getOrCreate', () => {
    manager = new SessionManager({ checkIntervalMs: 999_999 });
    const session = manager.getOrCreate('sess-1', { name: 'my-app' });

    expect(session.sessionId).toBe('sess-1');
    expect(session.application.name).toBe('my-app');
    expect(session.isActive).toBe(true);
    expect(session.logCount).toBe(0);
    expect(session.colorIndex).toBe(0);
  });

  it('returns existing session on duplicate getOrCreate', () => {
    manager = new SessionManager({ checkIntervalMs: 999_999 });
    const s1 = manager.getOrCreate('sess-1', { name: 'app-a' });
    const s2 = manager.getOrCreate('sess-1', { name: 'app-b' });

    expect(s1).toBe(s2);
    expect(s2.application.name).toBe('app-a');
  });

  it('tracks heartbeat via handleSessionAction', () => {
    manager = new SessionManager({ checkIntervalMs: 999_999 });
    manager.getOrCreate('sess-1', { name: 'app' });

    const ts = '2026-02-07T12:00:00.000Z';
    manager.handleSessionAction(
      makeEntry({
        id: 'hb-1',
        session_id: 'sess-1',
        type: 'session',
        session_action: 'heartbeat',
        timestamp: ts,
      }),
    );

    const session = manager.getSession('sess-1')!;
    expect(session.lastHeartbeat).toBe(ts);
  });

  it('assigns colors round-robin', () => {
    manager = new SessionManager({ checkIntervalMs: 999_999 });

    const colors: number[] = [];
    for (let i = 0; i < 14; i++) {
      const s = manager.getOrCreate(`sess-${i}`);
      colors.push(s.colorIndex);
    }

    // First 12 should be 0-11, then wraps
    expect(colors[0]).toBe(0);
    expect(colors[11]).toBe(11);
    expect(colors[12]).toBe(0);
    expect(colors[13]).toBe(1);
  });

  it('marks session inactive after timeout', () => {
    manager = new SessionManager({ timeoutMs: 100, checkIntervalMs: 999_999 });

    const past = new Date(Date.now() - 200).toISOString();
    const session = manager.getOrCreate('sess-old');
    session.lastHeartbeat = past;

    manager.checkTimeouts();

    expect(session.isActive).toBe(false);
  });

  it('handles session start/end lifecycle with events', () => {
    manager = new SessionManager({ checkIntervalMs: 999_999 });
    const events: SessionEvent[] = [];
    manager.on((event) => events.push(event));

    manager.handleSessionAction(makeSessionEntry('sess-1', 'start', { name: 'app' }));
    expect(events).toContain('session-start');

    const session = manager.getSession('sess-1')!;
    expect(session.isActive).toBe(true);

    manager.handleSessionAction(makeSessionEntry('sess-1', 'end'));
    expect(events).toContain('session-end');
    expect(session.isActive).toBe(false);
  });

  it('lists all sessions', () => {
    manager = new SessionManager({ checkIntervalMs: 999_999 });
    manager.getOrCreate('sess-1', { name: 'app-1' });
    manager.getOrCreate('sess-2', { name: 'app-2' });
    manager.getOrCreate('sess-3', { name: 'app-3' });

    const sessions = manager.getSessions();
    expect(sessions).toHaveLength(3);
    expect(sessions.map((s) => s.sessionId).sort()).toEqual(['sess-1', 'sess-2', 'sess-3']);
  });

  it('increments log count', () => {
    manager = new SessionManager({ checkIntervalMs: 999_999 });
    manager.getOrCreate('sess-1');

    manager.incrementLogCount('sess-1');
    manager.incrementLogCount('sess-1');
    manager.incrementLogCount('sess-1');

    expect(manager.getSession('sess-1')!.logCount).toBe(3);
  });

  it('getSession returns undefined for unknown session', () => {
    manager = new SessionManager({ checkIntervalMs: 999_999 });
    expect(manager.getSession('nonexistent')).toBeUndefined();
  });
});
