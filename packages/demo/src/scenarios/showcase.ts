import { Logger } from '@logger/client'

const delay = (ms: number) => new Promise(r => setTimeout(r, ms))

export async function runShowcase() {
  const logger = new Logger({ app: 'showcase', transport: 'http' })

  try {
    // 1. All severity levels
    logger.debug('Initializing showcase demo')
    logger.info('Application started successfully')
    logger.warn('Cache warming is slow — consider preloading')
    await delay(200)

    // 2. URI protocols with syntax highlighting
    logger.info('Services connected:')
    logger.info('  Database: postgres://db.prod:5432/app')
    logger.info('  Cache: redis://cache.prod:6379')
    logger.info('  API: https://api.example.com/v2')
    logger.info('  Stream: wss://events.example.com/live')
    await delay(300)

    // 3. Groups with nested entries
    logger.group('Deploy Pipeline')
    logger.info('Starting deployment v2.4.1...')

    logger.group('Build Phase')
    logger.info('Compiling TypeScript...')
    await delay(100)
    logger.info('Bundle size: 2.4 MB (gzipped: 680 KB)')
    logger.info('Build completed in 12.3s')
    logger.groupEnd()
    await delay(200)

    logger.group('Test Phase')
    logger.info('Running 342 unit tests...')
    // Progress bar that updates
    for (let i = 0; i <= 342; i += 34) {
      logger.progress('Test suite', Math.min(i, 342), 342, { id: 'test-progress' })
      await delay(100)
    }
    logger.info('All 342 tests passed')
    logger.groupEnd()
    await delay(200)

    logger.group('Deploy Phase')
    logger.info('Pushing to container registry...')
    logger.progress('Image push', 0, 100, { id: 'push-progress' })
    for (let i = 10; i <= 100; i += 10) {
      logger.progress('Image push', i, 100, { id: 'push-progress' })
      await delay(80)
    }
    logger.info('Rolling update: 3/3 replicas healthy')
    logger.groupEnd()

    logger.info('Deployment v2.4.1 complete ✓')
    logger.groupEnd()
    await delay(300)

    // 4. Error with stack trace
    try {
      throw new Error('Query timeout after 30000ms on postgres://db.prod:5432/app')
    } catch (err) {
      logger.error(err as Error, { query: 'SELECT * FROM logs WHERE ts > $1', duration: '30000ms' })
    }
    await delay(300)

    // 5. Table
    logger.info('Top 5 slowest endpoints:')
    logger.table(
      ['Endpoint', 'p50', 'p95', 'p99', 'Calls'],
      [
        ['GET /api/search', '45ms', '230ms', '890ms', '12,340'],
        ['POST /api/upload', '120ms', '450ms', '1.2s', '3,210'],
        ['GET /api/users/:id', '8ms', '25ms', '110ms', '45,600'],
        ['PUT /api/settings', '15ms', '40ms', '85ms', '890'],
        ['GET /api/feed', '35ms', '120ms', '340ms', '28,100'],
      ],
    )
    await delay(300)

    // 6. KV pairs
    logger.info('Server metrics:')
    logger.kv({
      'CPU Usage': '42%',
      'Memory': '1.3 GB / 4 GB',
      'Disk I/O': '23 MB/s',
      'Network In': '120 Mbps',
      'Network Out': '85 Mbps',
      'Active Connections': 847,
      'Uptime': '14d 6h 23m',
    })
    await delay(300)

    // 7. State tracking
    logger.state('deployment_version', 'v2.4.1')
    logger.state('healthy_replicas', 3)
    logger.state('last_deploy', new Date().toISOString())
    await delay(200)

    logger.info('Showcase demo complete — all features demonstrated')

    await logger.flush()
  } finally {
    await logger.close()
  }
}
