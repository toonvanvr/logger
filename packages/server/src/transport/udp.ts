import { DataMessage, EventMessage, SessionMessage } from '@logger/shared'
import { normalizeData, normalizeEvent, normalizeSession } from '../core/normalizer'
import { ingest } from './ingest'
import type { ServerDeps } from './types'

// ─── UDP Transport ───────────────────────────────────────────────────

export async function setupUdp(deps: ServerDeps): Promise<void> {
  const { config } = deps

  // Bun.udpSocket may not be available in all versions
  const udpSocket = (Bun as any).udpSocket
  if (typeof udpSocket !== 'function') {
    console.warn('[UDP] Bun.udpSocket not available, skipping UDP transport')
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

        if (parsed.type === 'session') {
          const result = SessionMessage.safeParse(parsed)
          if (!result.success) return
          ingest(normalizeSession(result.data), deps)
        } else if (parsed.type === 'data') {
          const result = DataMessage.safeParse(parsed)
          if (!result.success) return
          ingest(normalizeData(result.data), deps)
        } else {
          const result = EventMessage.safeParse(parsed)
          if (!result.success) return
          ingest(normalizeEvent(result.data), deps)
        }
      },
    },
  })

  console.log(`UDP socket listening on ${config.host}:${config.udpPort}`)
}
