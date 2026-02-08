import { Logger } from '@logger/client'

const delay = (ms: number) => new Promise(r => setTimeout(r, ms))

export async function runBasicLogging() {
  const logger = new Logger({ app: 'demo-basic', transport: 'http' })

  try {
    logger.debug('Application starting up — loading configuration')
    await delay(100)

    logger.info('Server listening on http://localhost:3000')
    await delay(100)

    logger.info('Connected to database at postgres://db.example.com:5432/myapp')
    await delay(100)

    logger.warn('Cache miss rate is 42% — consider increasing cache size')
    await delay(100)

    logger.error('Failed to connect to Redis at redis://cache.internal:6379')
    await delay(100)

    logger.critical('Out of memory: heap usage at 98.7% (1.58 GB / 1.60 GB)')
    await delay(100)

    // Numbers, URLs, and dates for syntax highlighting
    logger.info('Processed 1,234 requests in 567ms — avg latency 0.46ms')
    logger.info('Next scheduled maintenance: 2026-02-15T03:00:00Z')
    logger.info('API docs available at https://api.example.com/v2/docs')
    logger.debug('Config loaded: retries=3, timeout=30000, batchSize=100')

    // Various URI protocols for syntax highlighting
    logger.info('Connecting to postgres://db.example.com:5432/myapp')
    logger.info('Cache endpoint: redis://cache.internal:6379/0')
    logger.info('Message broker: amqp://mq.example.com:5672/vhost')
    logger.info('WebSocket feed: wss://feeds.example.com/live')
    logger.info('SSH tunnel: ssh://bastion.example.com:22')
    logger.info('File storage: s3://my-bucket/logs/2026-02-07/')

    await logger.flush()
  } finally {
    await logger.close()
  }
}
