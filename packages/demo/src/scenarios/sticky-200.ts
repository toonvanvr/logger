import { Logger } from '@logger/client'

const delay = (ms: number) => new Promise(r => setTimeout(r, ms))

const fillerMessages = [
  'Processing request from client',
  'Cache hit ratio: {n}%',
  'Heartbeat received',
  'Background job completed in {n}ms',
  'WebSocket ping: {n}ms',
  'Scheduled cleanup done',
  'Connection pool: {n}/100 active',
  'Queue depth: {n} items',
  'Memory: {n}MB used',
  'Disk I/O: {n} ops/sec',
]

async function filler(logger: Logger, count: number) {
  for (let i = 0; i < count; i++) {
    const msg = fillerMessages[i % fillerMessages.length]!
      .replace('{n}', String(Math.floor(Math.random() * 100)))
    if (i % 5 === 0) logger.debug(msg)
    else logger.info(msg)
    await delay(20 + Math.random() * 20)
  }
}

export async function runSticky200() {
  const logger = new Logger({ app: 'demo-sticky-200', transport: 'http' })

  try {
    logger.info('=== Sticky Scroll Test (200 entries) ===')

    const stickyIds: { id: string; label: string }[] = []
    const services = [
      'auth', 'api', 'db', 'cache', 'worker', 'scheduler',
      'gateway', 'monitor', 'indexer', 'mailer', 'storage', 'billing',
    ]

    // Phase 1: Gradual pinning with fillers (~157 entries)
    for (let i = 0; i < services.length; i++) {
      const id = crypto.randomUUID()
      const label = services[i]!
      stickyIds.push({ id, label })
      logger.withId(id).sticky().info(`[${label}] Status: online ✓`)
      await delay(100 + Math.random() * 100)
      await filler(logger, 8 + Math.floor(Math.random() * 8))
    }

    // Phase 2: Gradual unpinning with fillers (~45 entries)
    for (let i = 0; i < stickyIds.length; i++) {
      const { id, label } = stickyIds[i]!
      logger.info(`[${label}] health check passed — unpinning`)
      logger.unsticky('', id)
      await delay(100 + Math.random() * 100)
      if (i < stickyIds.length - 1) {
        await filler(logger, 3 + Math.floor(Math.random() * 4))
      }
    }

    logger.info('=== Sticky Scroll Test Complete ===')
    await logger.flush()
  } finally {
    await logger.close()
  }
}
