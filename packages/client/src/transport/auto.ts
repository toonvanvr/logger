import { HttpTransport } from './http';
import { TcpTransport } from './tcp';
import type { TransportAdapter } from './types';
import { UdpTransport } from './udp';
import { WsTransport } from './ws';

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
    case 'ws': {
      const ws = new WsTransport({ url: options?.url });
      await ws.connect();
      return ws;
    }
    case 'http': {
      const http = new HttpTransport({ url: options?.url });
      await http.connect();
      return http;
    }
    case 'udp': {
      const udp = new UdpTransport({ host: options?.host, port: options?.port });
      await udp.connect();
      return udp;
    }
    case 'tcp': {
      const tcp = new TcpTransport({ host: options?.host, port: options?.port });
      await tcp.connect();
      return tcp;
    }
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
