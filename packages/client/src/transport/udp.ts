import type { LogEntry } from '@logger/shared';
import { DEFAULT_HOST, DEFAULT_UDP_PORT } from '@logger/shared';
import type { TransportAdapter } from './types.js';

export interface UdpTransportOptions {
  host?: string;
  port?: number;
}

/**
 * UDP transport — fire-and-forget.
 *
 * Each entry is sent as a single JSON datagram.
 * Uses Bun.udpSocket when available.
 */
export class UdpTransport implements TransportAdapter {
  private _connected = false;
  private socket: any = null;
  private readonly host: string;
  private readonly port: number;

  constructor(options?: UdpTransportOptions) {
    this.host = options?.host ?? DEFAULT_HOST;
    this.port = options?.port ?? DEFAULT_UDP_PORT;
  }

  get connected(): boolean {
    return this._connected;
  }

  async connect(): Promise<void> {
    if (typeof Bun !== 'undefined' && typeof Bun.udpSocket === 'function') {
      this.socket = await Bun.udpSocket({
        connect: { hostname: this.host, port: this.port },
      });
      this._connected = true;
    } else {
      throw new Error('UDP transport requires Bun runtime with Bun.udpSocket');
    }
  }

  async send(entries: LogEntry[]): Promise<void> {
    if (!this.socket || !this._connected) {
      throw new Error('UDP socket not connected');
    }
    for (const entry of entries) {
      const data = JSON.stringify(entry);
      this.socket.send(data);
    }
  }

  async close(): Promise<void> {
    if (this.socket) {
      this.socket.close();
      this.socket = null;
    }
    this._connected = false;
  }
}
