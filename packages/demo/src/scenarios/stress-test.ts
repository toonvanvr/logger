import { Logger } from '@logger/client'

const delay = (ms: number) => new Promise(r => setTimeout(r, ms))

export async function runStressTest() {
  const logger = new Logger({ app: 'demo-stress', transport: 'http' })

  try {
    const total = 1000
    const severities = ['debug', 'info', 'warning', 'error', 'critical'] as const
    const messages = [
      'Processing request from client',
      'Cache lookup completed',
      'Database query executed',
      'Response serialized',
      'Middleware chain processed',
      'Authentication token validated',
      'Rate limit check passed',
      'Request routed to handler',
      'Compression applied to response',
      'Metrics recorded for endpoint',
    ]

    logger.info(`Starting stress test: ${total} logs in rapid succession`)
    const startTime = Date.now()

    for (let i = 0; i < total; i++) {
      const severity = severities[i % severities.length]!
      const message = messages[i % messages.length]!
      const method = severity === 'warning' ? 'warn' : severity

      if (method === 'debug') logger.debug(`[${i + 1}/${total}] ${message}`)
      else if (method === 'info') logger.info(`[${i + 1}/${total}] ${message}`)
      else if (method === 'warn') logger.warn(`[${i + 1}/${total}] ${message}`)
      else if (method === 'error') logger.error(`[${i + 1}/${total}] ${message}`)
      else if (method === 'critical') logger.critical(`[${i + 1}/${total}] ${message}`)
    }

    const elapsed = Date.now() - startTime
    logger.info(`Stress test complete: ${total} logs enqueued in ${elapsed}ms (${Math.round(total / (elapsed / 1000))} logs/sec)`)

    // Allow time for queue to drain
    await delay(2000)
    await logger.flush()
  } finally {
    await logger.close()
  }
}
