import type { ApplicationInfo, StoredEntry } from '@logger/shared'

// ─── Types ───────────────────────────────────────────────────────────

export interface InternalSessionInfo {
  sessionId: string
  application: ApplicationInfo
  startedAt: string
  lastHeartbeat: string
  isActive: boolean
  logCount: number
  colorIndex: number
}

export type SessionEvent = 'session-start' | 'session-end' | 'session-update'
export type SessionEventListener = (event: SessionEvent, session: InternalSessionInfo) => void

// ─── Constants ───────────────────────────────────────────────────────

const COLOR_POOL_SIZE = 12
const SESSION_TIMEOUT_MS = 5 * 60 * 1000 // 5 minutes

// ─── Session Manager ─────────────────────────────────────────────────

export class SessionManager {
  private sessions = new Map<string, InternalSessionInfo>();
  private nextColorIndex = 0;
  private listeners: SessionEventListener[] = [];
  private timeoutTimer: Timer | null = null;
  private readonly timeoutMs: number

  constructor(options?: { timeoutMs?: number; checkIntervalMs?: number }) {
    this.timeoutMs = options?.timeoutMs ?? SESSION_TIMEOUT_MS
    const checkInterval = options?.checkIntervalMs ?? 60_000
    this.timeoutTimer = setInterval(() => this.checkTimeouts(), checkInterval)
  }

  /** Register an event listener. */
  on(listener: SessionEventListener): void {
    this.listeners.push(listener)
  }

  /** Process a StoredEntry with kind=session. */
  handleSession(entry: StoredEntry): void {
    const action = entry.session_action
    if (!action) return

    switch (action) {
      case 'start': {
        const app = entry.application ?? undefined
        const session = this.getOrCreate(entry.session_id, app)
        session.isActive = true
        session.lastHeartbeat = entry.timestamp
        this.emit('session-start', session)
        break
      }
      case 'end': {
        const session = this.sessions.get(entry.session_id)
        if (session) {
          session.isActive = false
          session.lastHeartbeat = entry.timestamp
          this.emit('session-end', session)
        }
        break
      }
      case 'heartbeat': {
        const session = this.sessions.get(entry.session_id)
        if (session) {
          this.updateHeartbeat(session.sessionId, entry.timestamp)
        }
        break
      }
    }
  }

  /** Get existing session or create a new one. */
  getOrCreate(sessionId: string, application?: ApplicationInfo): InternalSessionInfo {
    let session = this.sessions.get(sessionId)
    if (session) return session

    const now = new Date().toISOString()
    session = {
      sessionId,
      application: application ?? { name: 'unknown' },
      startedAt: now,
      lastHeartbeat: now,
      isActive: true,
      logCount: 0,
      colorIndex: this.assignColor(),
    }
    this.sessions.set(sessionId, session)
    return session
  }

  /** Get a session by ID. */
  getSession(sessionId: string): InternalSessionInfo | undefined {
    return this.sessions.get(sessionId)
  }

  /** List all sessions. */
  getSessions(): InternalSessionInfo[] {
    return Array.from(this.sessions.values())
  }

  /** Refresh a session's heartbeat timestamp. */
  updateHeartbeat(sessionId: string, timestamp?: string): void {
    const session = this.sessions.get(sessionId)
    if (session) {
      session.lastHeartbeat = timestamp ?? new Date().toISOString()
      this.emit('session-update', session)
    }
  }

  /** Increment a session's log counter. */
  incrementLogCount(sessionId: string): void {
    const session = this.sessions.get(sessionId)
    if (session) {
      session.logCount++
    }
  }

  /** Shutdown: clear the timeout check timer. */
  shutdown(): void {
    if (this.timeoutTimer) {
      clearInterval(this.timeoutTimer)
      this.timeoutTimer = null
    }
  }

  // ─── Internals ───────────────────────────────────────────────────

  /** Assign next color index from the pool (round-robin). */
  private assignColor(): number {
    const index = this.nextColorIndex
    this.nextColorIndex = (this.nextColorIndex + 1) % COLOR_POOL_SIZE
    return index
  }

  /** Check sessions for heartbeat timeout. */
  checkTimeouts(): void {
    const now = Date.now()
    for (const session of this.sessions.values()) {
      if (!session.isActive) continue
      const elapsed = now - new Date(session.lastHeartbeat).getTime()
      if (elapsed > this.timeoutMs) {
        session.isActive = false
        this.emit('session-end', session)
      }
    }
  }

  /** Emit event to all listeners. */
  private emit(event: SessionEvent, session: InternalSessionInfo): void {
    for (const listener of this.listeners) {
      listener(event, session)
    }
  }
}
