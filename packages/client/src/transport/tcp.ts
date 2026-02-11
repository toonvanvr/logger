import type { QueuedMessage } from '../logger-types'
import type { TransportAdapter } from './types'

const DEFAULT_HOST = 'localhost'
const DEFAULT_TCP_PORT = 8082

export interface TcpTransportOptions {
  host?: string
  port?: number
}

/**
 * TCP transport — NDJSON (one JSON object per newline).
 *
 * Reconnects on disconnect using Bun.connect.
 */
export class TcpTransport implements TransportAdapter {
  private _connected = false;
  private socket: any = null;
  private readonly host: string
  private readonly port: number
  private shouldReconnect = true;
  private reconnectDelay = 1000;
  private static readonly MAX_RECONNECT_DELAY = 30_000;
  private reconnectTimer: ReturnType<typeof setTimeout> | null = null;

  constructor(options?: TcpTransportOptions) {
    this.host = options?.host ?? DEFAULT_HOST
    this.port = options?.port ?? DEFAULT_TCP_PORT
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
      if (typeof Bun === 'undefined' || typeof Bun.connect !== 'function') {
        reject(new Error('TCP transport requires Bun runtime'))
        return
      }

      Bun.connect({
        hostname: this.host,
        port: this.port,
        socket: {
          open: (socket: any) => {
            this.socket = socket
            this._connected = true
            this.reconnectDelay = 1000
            resolve()
          },
          data: () => {
            // TCP transport is send-only; ignore incoming data.
          },
          close: () => {
            this._connected = false
            this.socket = null
            this.scheduleReconnect()
          },
          error: (_socket: any, err: Error) => {
            if (!this._connected) {
              reject(err)
            }
          },
        },
      }).catch(reject)
    })
  }

  private scheduleReconnect(): void {
    if (!this.shouldReconnect) return
    this.reconnectTimer = setTimeout(() => {
      this.doConnect().catch(() => {
        // Will schedule another reconnect via close handler.
      })
      this.reconnectDelay = Math.min(this.reconnectDelay * 2, TcpTransport.MAX_RECONNECT_DELAY)
    }, this.reconnectDelay)
  }

  async send(messages: QueuedMessage[]): Promise<void> {
    if (!this.socket || !this._connected) {
      throw new Error('TCP socket not connected')
    }
    const ndjson = messages.map((m) => {
      const { kind, ...payload } = m
      return JSON.stringify({ type: kind, ...payload })
    }).join('\n') + '\n'
    this.socket.write(ndjson)
  }

  async close(): Promise<void> {
    this.shouldReconnect = false
    if (this.reconnectTimer) {
      clearTimeout(this.reconnectTimer)
      this.reconnectTimer = null
    }
    if (this.socket) {
      this.socket.end()
      this.socket = null
    }
    this._connected = false
  }
}
