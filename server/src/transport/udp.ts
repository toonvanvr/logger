import { ingestEntry, processEntry } from './ingest';
import type { ServerDeps } from './types';

// ─── UDP Transport ───────────────────────────────────────────────────

export async function setupUdp(deps: ServerDeps): Promise<void> {
  const { config } = deps;

  // Bun.udpSocket may not be available in all versions
  const udpSocket = (Bun as any).udpSocket;
  if (typeof udpSocket !== 'function') {
    console.warn('[UDP] Bun.udpSocket not available, skipping UDP transport');
    return;
  }

  await udpSocket({
    port: config.udpPort,
    hostname: config.host,
    socket: {
      data(_socket: any, buf: Buffer, _port: number, _addr: string) {
        let parsed: unknown;
        try {
          parsed = JSON.parse(buf.toString());
        } catch {
          return; // silent drop — fire-and-forget, no response channel
        }

        // No rate limiting for UDP (best-effort)
        const result = processEntry(parsed, deps);
        if (!result.ok) return;

        ingestEntry(result.entry, deps);
      },
    },
  });

  console.log(`UDP socket listening on ${config.host}:${config.udpPort}`);
}
