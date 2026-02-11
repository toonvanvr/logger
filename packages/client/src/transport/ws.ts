import type { QueuedMessage } from '../logger-types'
import type { TransportAdapter } from './types'

export interface WsTransportOptions {
  url?: string
}

const DEFAULT_WS_BASE = 'ws://localhost:8080'

/**
 * WebSocket transport — primary, bidirectional.
 *
 * Sends each message as `{type: kind, ...payload}` envelope.
 * Receives ServerMessages via optional onMessage handler.
 * Auto-reconnects with exponential backoff (1s → 30s).
 */
export class WsTransport implements TransportAdapter {
  private ws: WebSocket | null = null;
  private _connected = false;
  private messageHandler: ((data: unknown) => void) | null = null;
  private readonly url: string
  private reconnectTimer: ReturnType<typeof setTimeout> | null = null;
  private reconnectDelay = 1000;
  private static readonly MAX_RECONNECT_DELAY = 30_000;
  private shouldReconnect = true;

  constructor(options?: WsTransportOptions) {
    const raw = options?.url ?? DEFAULT_WS_BASE
    // Normalise: ensure we point at the stream endpoint.
    const parsed = new URL(raw)
    if (!parsed.pathname || parsed.pathname === '/') {
      parsed.pathname = '/api/v2/stream'
    }
    this.url = parsed.toString()
  }

  get connected(): boolean {
    return this._connected
  }

  async connect(): Promise<void> {
    this.shouldReconnect = true
    return this.doConnect()
  }

  private doConnect(): Promise<void> {
    return new Promise<void>((resolve, reject) => {
      try {
        this.ws = new WebSocket(this.url, {
          headers: {
            'X-Logger-Role': 'client',
            'X-Logger-Version': '2',
            'Sec-WebSocket-Protocol': 'logger-v2',
          },
        } as any)

        this.ws.onopen = () => {
          this._connected = true
          this.reconnectDelay = 1000 // reset backoff
          resolve()
        }

        this.ws.onmessage = (event: MessageEvent) => {
          if (this.messageHandler) {
            try {
              const data = JSON.parse(String(event.data))
              this.messageHandler(data)
            } catch {
              // Ignore malformed messages
            }
          }
        }

        this.ws.onclose = () => {
          this._connected = false
          this.scheduleReconnect()
        }

        this.ws.onerror = () => {
          if (!this._connected) {
            reject(new Error(`WebSocket connection failed: ${this.url}`))
          }
        }
      } catch (err) {
        reject(err)
      }
    })
  }

  private scheduleReconnect(): void {
    if (!this.shouldReconnect) return
    this.reconnectTimer = setTimeout(() => {
      this.doConnect().catch(() => {
        // Will schedule another reconnect via onclose
      })
      this.reconnectDelay = Math.min(this.reconnectDelay * 2, WsTransport.MAX_RECONNECT_DELAY)
    }, this.reconnectDelay)
  }

  async send(messages: QueuedMessage[]): Promise<void> {
    if (!this.ws || !this._connected) {
      throw new Error('WebSocket not connected')
    }
    for (const msg of messages) {
      const { kind, ...payload } = msg
      this.ws.send(JSON.stringify({ type: kind, ...payload }))
    }
  }

  onMessage(handler: (data: unknown) => void): void {
    this.messageHandler = handler
  }

  async close(): Promise<void> {
    this.shouldReconnect = false
    if (this.reconnectTimer) {
      clearTimeout(this.reconnectTimer)
      this.reconnectTimer = null
    }
    if (this.ws) {
      this.ws.close()
      this.ws = null
    }
    this._connected = false
  }
}
