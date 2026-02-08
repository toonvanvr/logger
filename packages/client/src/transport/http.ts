import type { LogEntry } from '@logger/shared';
import { DEFAULT_HTTP_URL } from '@logger/shared';
import type { TransportAdapter } from './types.js';

export interface HttpTransportOptions {
  url?: string;
}

/**
 * HTTP transport — fallback, unidirectional.
 *
 * - Single entry: POST /api/v1/log
 * - Batch: POST /api/v1/logs
 */
export class HttpTransport implements TransportAdapter {
  private _connected = false;
  private readonly baseUrl: string;

  constructor(options?: HttpTransportOptions) {
    // Strip trailing path so we can append our own.
    const raw = options?.url ?? DEFAULT_HTTP_URL;
    // Normalise: remove any trailing /api/v1/... path, keep scheme + host + port.
    const url = new URL(raw);
    this.baseUrl = `${url.protocol}//${url.host}`;
  }

  get connected(): boolean {
    return this._connected;
  }

  async connect(): Promise<void> {
    // HTTP is stateless — nothing to "connect". We mark ready immediately.
    this._connected = true;
  }

  async send(entries: LogEntry[]): Promise<void> {
    if (!this._connected) {
      throw new Error('HttpTransport not connected');
    }

    const url =
      entries.length === 1
        ? `${this.baseUrl}/api/v1/log`
        : `${this.baseUrl}/api/v1/logs`;

    const body =
      entries.length === 1
        ? JSON.stringify(entries[0])
        : JSON.stringify({ entries });

    const res = await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body,
    });

    if (!res.ok) {
      throw new Error(`HTTP ${res.status}: ${await res.text()}`);
    }
  }

  async close(): Promise<void> {
    this._connected = false;
  }
}
