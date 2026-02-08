import { Logger } from '@logger/client'

const delay = (ms: number) => new Promise(r => setTimeout(r, ms))

export async function runStickyDemo() {
  const logger = new Logger({ app: 'demo-sticky', transport: 'http' })

  try {
    logger.info('=== Sticky Entries Demo ===')
    await delay(200)

    // ─── 1. Sticky group: entire group is pinned ─────────────────────
    logger.group('Build Output', { sticky: true })
    logger.info('Compiling TypeScript...')
    await delay(100)
    logger.info('Bundling with esbuild...')
    await delay(100)
    logger.info('Build complete: 12 files, 245KB')
    logger.groupEnd()
    await delay(300)

    // ─── 2. Large group with individually-sticky children ────────────
    logger.group('API Request Pipeline')
    logger.info('Incoming POST /api/users')
    await delay(80)
    logger.info('Parsing request body...')
    await delay(80)
    logger.info('Validating schema...')
    await delay(80)
    logger.sticky().info('Auth: JWT verified for user admin@example.com')
    await delay(80)
    logger.info('Rate limiter: 42/100 requests remaining')
    await delay(80)
    logger.info('Database query: INSERT INTO users VALUES (...)')
    await delay(80)
    logger.info('Query took 23ms, 1 row affected')
    await delay(80)
    logger.sticky().info('Response: 201 Created — user_id=u_abc123')
    await delay(80)
    logger.info('Request completed in 156ms')
    logger.groupEnd()
    await delay(300)

    // ─── 3. Multiple concurrent sticky items ─────────────────────────
    logger.sticky().info('Server running on http://localhost:3000')
    await delay(100)
    logger.sticky().warn('Memory usage: 87% (threshold: 90%)')
    await delay(100)

    // ─── 4. Normal (non-sticky) logs flowing underneath ──────────────
    logger.info('Client connected: 192.168.1.42')
    await delay(100)
    logger.debug('Heartbeat received from worker-3')
    await delay(100)
    logger.info('Cache hit ratio: 94.2%')
    await delay(100)
    logger.info('Scheduled job "cleanup" completed in 340ms')
    await delay(100)
    logger.debug('WebSocket ping/pong: 12ms')
    await delay(100)
    logger.info('Client disconnected: 192.168.1.42')
    await delay(100)

    // ─── 5. Nested sticky within nested groups ───────────────────────
    logger.group('Deploy Pipeline')
    logger.info('Starting deployment to production...')
    await delay(100)

    logger.group('Pre-flight Checks')
    logger.info('Checking disk space...')
    await delay(80)
    logger.sticky().info('Health check: all 3 replicas healthy')
    await delay(80)
    logger.info('DNS resolution OK')
    logger.groupEnd()
    await delay(100)

    logger.info('Uploading artifacts...')
    await delay(100)
    logger.info('Swapping blue/green targets...')
    await delay(100)
    logger.sticky().info('Deploy complete: v2.4.1 → production')
    logger.groupEnd()
    await delay(200)

    // ─── 6. More scrolling content ───────────────────────────────────
    for (let i = 0; i < 15; i++) {
      logger.debug(`Background task ${i + 1}/15: processing batch`)
      await delay(50)
    }

    logger.info('=== Sticky Demo Complete ===')
    await logger.flush()
  } finally {
    await logger.close()
  }
}
