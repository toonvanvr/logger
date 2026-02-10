import type { QueuedMessage } from '../logger-types.js'
import type { TransportAdapter } from './types.js'

export interface HttpTransportOptions {
  url?: string
}

const DEFAULT_BASE = 'http://localhost:8080'

/**
 * HTTP transport — fallback, unidirectional.
 *
 * Routes messages by kind to endpoints:
 *   session → POST /api/v2/session (one at a time)
 *   event   → POST /api/v2/events  (single or batch)
 *   data    → POST /api/v2/data    (single or batch)
 */
export class HttpTransport implements TransportAdapter {
  private _connected = false;
  private readonly baseUrl: string

  constructor(options?: HttpTransportOptions) {
    const raw = options?.url ?? DEFAULT_BASE
    const url = new URL(raw)
    this.baseUrl = `${url.protocol}//${url.host}`
  }

  get connected(): boolean {
    return this._connected
  }

  async connect(): Promise<void> {
    this._connected = true
  }

  async send(messages: QueuedMessage[]): Promise<void> {
    if (!this._connected) {
      throw new Error('HttpTransport not connected')
    }

    const sessions: Record<string, unknown>[] = []
    const events: Record<string, unknown>[] = []
    const data: Record<string, unknown>[] = []

    for (const msg of messages) {
      const { kind, ...payload } = msg
      switch (kind) {
        case 'session': sessions.push(payload); break
        case 'event': events.push(payload); break
        case 'data': data.push(payload); break
        // rpc_response / register_tools are WS-only — skip for HTTP.
      }
    }

    const promises: Promise<void>[] = []

    // Sessions are sent one at a time (no batch endpoint).
    for (const s of sessions) {
      promises.push(this.post(`${this.baseUrl}/api/v2/session`, s))
    }
    if (events.length > 0) {
      const body = events.length === 1 ? events[0] : events
      promises.push(this.post(`${this.baseUrl}/api/v2/events`, body))
    }
    if (data.length > 0) {
      const body = data.length === 1 ? data[0] : data
      promises.push(this.post(`${this.baseUrl}/api/v2/data`, body))
    }

    await Promise.all(promises)
  }

  private async post(url: string, body: unknown): Promise<void> {
    const res = await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
    })
    if (!res.ok) {
      throw new Error(`HTTP ${res.status}: ${await res.text()}`)
    }
  }

  async close(): Promise<void> {
    this._connected = false
  }
}
