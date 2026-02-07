import { HttpTransport } from './http.js';
import { TcpTransport } from './tcp.js';
import type { TransportAdapter } from './types.js';
import { UdpTransport } from './udp.js';
import { WsTransport } from './ws.js';

export type TransportType = 'ws' | 'http' | 'udp' | 'tcp' | 'auto';

export interface AutoTransportOptions {
  type?: TransportType;
  url?: string;
  host?: string;
  port?: number;
}

/**
 * Factory: create a TransportAdapter based on the requested type.
 *
 * `auto` (default) tries WebSocket first, falls back to HTTP.
 */
export async function createTransport(options?: AutoTransportOptions): Promise<TransportAdapter> {
  const type = options?.type ?? 'auto';

  switch (type) {
    case 'ws':
      return new WsTransport({ url: options?.url });
    case 'http':
      return new HttpTransport({ url: options?.url });
    case 'udp':
      return new UdpTransport({ host: options?.host, port: options?.port });
    case 'tcp':
      return new TcpTransport({ host: options?.host, port: options?.port });
    case 'auto': {
      const ws = new WsTransport({ url: options?.url });
      try {
        await ws.connect();
        return ws;
      } catch {
        // WS failed — fall back to HTTP.
        const httpUrl = options?.url
          ? options.url.replace(/^ws/, 'http')
          : undefined;
        const http = new HttpTransport({ url: httpUrl });
        await http.connect();
        return http;
      }
    }
    default:
      throw new Error(`Unknown transport type: ${type}`);
  }
}
