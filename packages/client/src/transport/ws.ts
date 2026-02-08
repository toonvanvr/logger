import type { LogEntry } from '@logger/shared';
import { DEFAULT_WS_URL } from '@logger/shared';
import type { TransportAdapter } from './types.js';

export interface WsTransportOptions {
  url?: string;
}

/**
 * WebSocket transport — primary, bidirectional.
 *
 * - Sends batches of LogEntry as JSON arrays.
 * - Receives ServerMessages via optional onMessage handler.
 * - Auto-reconnects with exponential backoff (1s → 30s).
 */
export class WsTransport implements TransportAdapter {
  private ws: WebSocket | null = null;
  private _connected = false;
  private messageHandler: ((data: unknown) => void) | null = null;
  private readonly url: string;
  private reconnectTimer: ReturnType<typeof setTimeout> | null = null;
  private reconnectDelay = 1000;
  private static readonly MAX_RECONNECT_DELAY = 30_000;
  private shouldReconnect = true;

  constructor(options?: WsTransportOptions) {
    this.url = options?.url ?? DEFAULT_WS_URL;
  }

  get connected(): boolean {
    return this._connected;
  }

  async connect(): Promise<void> {
    this.shouldReconnect = true;
    return this.doConnect();
  }

  private doConnect(): Promise<void> {
    return new Promise<void>((resolve, reject) => {
      try {
        this.ws = new WebSocket(this.url, {
          headers: { 'X-Logger-Role': 'client' },
        } as any);

        this.ws.onopen = () => {
          this._connected = true;
          this.reconnectDelay = 1000; // reset backoff
          resolve();
        };

        this.ws.onmessage = (event: MessageEvent) => {
          if (this.messageHandler) {
            try {
              const data = JSON.parse(String(event.data));
              this.messageHandler(data);
            } catch {
              // Ignore malformed messages
            }
          }
        };

        this.ws.onclose = () => {
          this._connected = false;
          this.scheduleReconnect();
        };

        this.ws.onerror = () => {
          if (!this._connected) {
            reject(new Error(`WebSocket connection failed: ${this.url}`));
          }
        };
      } catch (err) {
        reject(err);
      }
    });
  }

  private scheduleReconnect(): void {
    if (!this.shouldReconnect) return;
    this.reconnectTimer = setTimeout(() => {
      this.doConnect().catch(() => {
        // Will schedule another reconnect via onclose
      });
      this.reconnectDelay = Math.min(this.reconnectDelay * 2, WsTransport.MAX_RECONNECT_DELAY);
    }, this.reconnectDelay);
  }

  async send(entries: LogEntry[]): Promise<void> {
    if (!this.ws || !this._connected) {
      throw new Error('WebSocket not connected');
    }
    this.ws.send(JSON.stringify(entries));
  }

  onMessage(handler: (data: unknown) => void): void {
    this.messageHandler = handler;
  }

  async close(): Promise<void> {
    this.shouldReconnect = false;
    if (this.reconnectTimer) {
      clearTimeout(this.reconnectTimer);
      this.reconnectTimer = null;
    }
    if (this.ws) {
      this.ws.close();
      this.ws = null;
    }
    this._connected = false;
  }
}
