import type { LogEntry } from '@logger/shared';
import type { RingBuffer } from './ring-buffer';
import type { SessionManager } from './session-manager';
import type { WebSocketHub } from './ws-hub';

// ─── SelfLogger ──────────────────────────────────────────────────────
// Creates a special session for server operational logs.
// These appear in the viewer with a distinctive "__system__" session ID.
// They are NOT forwarded to Loki/store by default (guarded in ingest).

export const SYSTEM_SESSION_ID = '__system__';
const SYSTEM_SESSION_PREFIX = '__';

export class SelfLogger {
  private counter = 0;

  constructor(
    private ringBuffer: RingBuffer,
    private wsHub: WebSocketHub,
    private sessionManager: SessionManager,
  ) {
    this.sessionManager.getOrCreate(SYSTEM_SESSION_ID, {
      name: 'logger-server',
      environment: 'system',
    });
  }

  log(severity: 'debug' | 'info' | 'warning' | 'error' | 'critical', text: string): void {
    const entry: LogEntry = {
      id: `sys-${Date.now()}-${this.counter++}`,
      timestamp: new Date().toISOString(),
      session_id: SYSTEM_SESSION_ID,
      severity,
      type: 'text',
      text,
      application: { name: 'logger-server' },
      tags: { source: 'self-logger' },
    };

    this.ringBuffer.push(entry);
    this.wsHub.broadcast({ type: 'log', entry });
    this.sessionManager.incrementLogCount(SYSTEM_SESSION_ID);
  }

  info(text: string): void {
    this.log('info', text);
  }

  warn(text: string): void {
    this.log('warning', text);
  }

  error(text: string): void {
    this.log('error', text);
  }

  debug(text: string): void {
    this.log('debug', text);
  }
}

/**
 * Returns true if the session ID is a system/internal session
 * that should NOT be forwarded to external stores.
 */
export function isSystemSession(sessionId: string): boolean {
  return sessionId.startsWith(SYSTEM_SESSION_PREFIX);
}
