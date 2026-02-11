import { parseAndIngest } from './ingest'
import type { ServerDeps } from './types'

// ─── UDP Transport ───────────────────────────────────────────────────

export async function setupUdp(deps: ServerDeps): Promise<void> {
  const { config } = deps

  // Bun.udpSocket may not be available in all versions
  const udpSocket = (Bun as any).udpSocket
  if (typeof udpSocket !== 'function') {
    try { deps.selfLogger.warn('[UDP] Bun.udpSocket not available, skipping UDP transport') } catch { console.warn('[UDP] Bun.udpSocket not available, skipping UDP transport') }
    return
  }

  await udpSocket({
    port: config.udpPort,
    hostname: config.host,
    socket: {
      data(_socket: any, buf: Buffer, _port: number, _addr: string) {
        let parsed: any
        try {
          parsed = JSON.parse(buf.toString())
        } catch {
          return // silent drop — fire-and-forget, no response channel
        }

        parseAndIngest(parsed, deps)
      },
    },
  })

  try { deps.selfLogger.info(`UDP socket listening on ${config.host}:${config.udpPort}`) } catch { console.log(`UDP socket listening on ${config.host}:${config.udpPort}`) }
}
