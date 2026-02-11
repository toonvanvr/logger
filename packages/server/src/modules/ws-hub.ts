import { ViewerCommand, type ServerBroadcast, type SeverityLevel } from '@logger/shared';
import type { ServerWebSocket } from 'bun';
import type { WsData } from '../transport/types';

// ─── Types ───────────────────────────────────────────────────────────────

export interface ViewerSubscription {
  sessionIds: string[]
  minSeverity?: SeverityLevel
  sections?: string[]
  textFilter?: string
}

interface ViewerEntry {
  ws: ServerWebSocket<WsData>
  subscription: ViewerSubscription
  buffer: string[]
  flushTimer: Timer | null
}

// ─── Severity ordering for filter comparison ─────────────────────────

const SEVERITY_ORDER: Record<string, number> = {
  debug: 0,
  info: 1,
  warning: 2,
  error: 3,
  critical: 4,
}

// ─── WebSocket Hub ───────────────────────────────────────────────────

export class WebSocketHub {
  private viewers = new Map<ServerWebSocket<WsData>, ViewerEntry>();

  /** Register a viewer WebSocket connection. */
  addViewer(ws: ServerWebSocket<WsData>): void {
    this.viewers.set(ws, {
      ws,
      subscription: { sessionIds: [] },
      buffer: [],
      flushTimer: null,
    })
  }

  /** Unregister a viewer WebSocket connection. */
  removeViewer(ws: ServerWebSocket<WsData>): void {
    const entry = this.viewers.get(ws)
    if (entry?.flushTimer) {
      clearTimeout(entry.flushTimer)
    }
    this.viewers.delete(ws)
  }

  /** Get the number of connected viewers. */
  getViewerCount(): number {
    return this.viewers.size
  }

  /** Update a viewer's subscription filter. */
  setSubscription(ws: ServerWebSocket<WsData>, sub: ViewerSubscription): void {
    const entry = this.viewers.get(ws)
    if (entry) {
      entry.subscription = sub
    }
  }

  /** Get a viewer's current subscription. */
  getSubscription(ws: ServerWebSocket<WsData>): ViewerSubscription | undefined {
    return this.viewers.get(ws)?.subscription
  }

  /** Broadcast a server message to all viewers whose subscription matches. */
  broadcast(message: ServerBroadcast): void {
    const data = JSON.stringify(message)

    for (const entry of this.viewers.values()) {
      if (!this.matchesSubscription(message, entry.subscription)) continue

      if (message.type === 'event') {
        entry.buffer.push(data)
        if (!entry.flushTimer) {
          entry.flushTimer = setTimeout(() => this.flushViewer(entry), 16)
        }
      } else {
        entry.ws.send(data)
      }
    }
  }

  /** Flush buffered event messages for a viewer. */
  private flushViewer(entry: ViewerEntry): void {
    entry.flushTimer = null
    if (entry.buffer.length === 0) return

    const messages = entry.buffer
    entry.buffer = []

    for (const msg of messages) {
      entry.ws.send(msg)
    }
  }

  /** Process an incoming viewer message (subscribe/unsubscribe). */
  handleViewerMessage(ws: ServerWebSocket<WsData>, raw: unknown): void {
    const parsed = ViewerCommand.safeParse(raw)
    if (!parsed.success) {
      console.warn('[WsHub] Invalid viewer message:', parsed.error.message)
      return
    }
    const message = parsed.data

    switch (message.type) {
      case 'subscribe': {
        this.setSubscription(ws, {
          sessionIds: message.session_ids ?? [],
          minSeverity: message.min_severity,
          sections: message.tags,
          textFilter: message.text_filter,
        })
        break
      }
      case 'unsubscribe': {
        this.setSubscription(ws, { sessionIds: [] })
        break
      }
      // Other message types (history, rpc_request, etc.) are handled
      // by other modules; this hub only processes subscription management.
    }
  }

  /** Close all viewer connections and clear state. */
  shutdown(): void {
    for (const entry of this.viewers.values()) {
      if (entry.flushTimer) clearTimeout(entry.flushTimer)
      try { entry.ws.close() } catch { /* already closed */ }
    }
    this.viewers.clear()
  }

  // ─── Internals ───────────────────────────────────────────────────

  /** Check if a server message matches a viewer's subscription. */
  private matchesSubscription(message: ServerBroadcast, sub: ViewerSubscription): boolean {
    // Non-log messages are broadcast to all
    if (message.type !== 'event') {
      return true
    }

    const entry = message.entry

    // Session filter: empty sessionIds means "all sessions"
    if (sub.sessionIds.length > 0 && !sub.sessionIds.includes(entry.session_id)) {
      return false
    }

    // Severity filter
    if (sub.minSeverity) {
      const entrySev = SEVERITY_ORDER[entry.severity] ?? 0
      const minSev = SEVERITY_ORDER[sub.minSeverity] ?? 0
      if (entrySev < minSev) {
        return false
      }
    }

    // Section/tag filter
    if (sub.sections && sub.sections.length > 0) {
      const entryTag = entry.tag ?? 'events'
      if (!sub.sections.includes(entryTag)) {
        return false
      }
    }

    // Text filter: case-insensitive substring match against message and label values
    if (sub.textFilter) {
      const filter = sub.textFilter.toLowerCase()
      let matched = false

      if (entry.message && entry.message.toLowerCase().includes(filter)) {
        matched = true
      }

      if (!matched && entry.labels) {
        for (const value of Object.values(entry.labels)) {
          if (value.toLowerCase().includes(filter)) {
            matched = true
            break
          }
        }
      }

      if (!matched) {
        return false
      }
    }

    return true
  }
}
