import type { StoredEntry } from '@logger/shared'
import type { RingBuffer } from './ring-buffer'
import type { SessionManager } from './session-manager'
import type { WebSocketHub } from './ws-hub'

// ─── SelfLogger ──────────────────────────────────────────────────────
// Creates a special session for server operational logs.
// These appear in the viewer with a distinctive "__system__" session ID.
// They are NOT forwarded to Loki/store by default (guarded in ingest).

export const SYSTEM_SESSION_ID = '__system__'
const SYSTEM_SESSION_PREFIX = '__'

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
    })
  }

  log(severity: 'debug' | 'info' | 'warning' | 'error' | 'critical', text: string): void {
    const ts = new Date().toISOString()
    const entry: StoredEntry = {
      id: `sys-${Date.now()}-${this.counter++}`,
      timestamp: ts,
      session_id: SYSTEM_SESSION_ID,
      kind: 'event',
      severity,
      message: text,
      tag: 'system',
      exception: null,
      parent_id: null,
      group_id: null,
      prev_id: null,
      next_id: null,
      widget: null,
      replace: false,
      icon: null,
      labels: { source: 'self-logger' },
      generated_at: null,
      sent_at: null,
      key: null,
      value: undefined,
      override: true,
      display: 'default',
      session_action: null,
      application: { name: 'logger-server' },
      metadata: null,
      received_at: ts,
    }

    this.ringBuffer.push(entry)
    this.wsHub.broadcast({ type: 'log', entry })
    this.sessionManager.incrementLogCount(SYSTEM_SESSION_ID)
  }

  info(text: string): void {
    this.log('info', text)
  }

  warn(text: string): void {
    this.log('warning', text)
  }

  error(text: string): void {
    this.log('error', text)
  }

  debug(text: string): void {
    this.log('debug', text)
  }
}

/**
 * Returns true if the session ID is a system/internal session
 * that should NOT be forwarded to external stores.
 */
export function isSystemSession(sessionId: string): boolean {
  return sessionId.startsWith(SYSTEM_SESSION_PREFIX)
}
