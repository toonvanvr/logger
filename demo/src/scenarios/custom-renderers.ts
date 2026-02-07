import { Logger } from '@logger/client'

const delay = (ms: number) => new Promise(r => setTimeout(r, ms))

export async function runCustomRenderers() {
  const logger = new Logger({ app: 'demo-custom', transport: 'http' })

  try {
    // Table — tabular data
    logger.info('Displaying user activity report')
    logger.table(
      ['User', 'Requests', 'Avg Latency', 'Errors', 'Status'],
      [
        ['alice@example.com', '1,234', '45ms', '2', 'Active'],
        ['bob@example.com', '856', '62ms', '0', 'Active'],
        ['charlie@example.com', '2,103', '38ms', '15', 'Warning'],
        ['diana@example.com', '421', '120ms', '8', 'Degraded'],
        ['eve@example.com', '3,500', '22ms', '1', 'Active'],
      ],
    )
    await delay(500)

    // Progress — updating values
    logger.info('Starting data import...')
    const totalItems = 500
    for (let i = 0; i <= totalItems; i += 50) {
      logger.progress('Data import', i, totalItems, { id: 'import-progress' })
      await delay(200)
    }
    logger.info('Data import complete')
    await delay(300)

    // Key-value pairs
    logger.info('Current system configuration:')
    logger.kv({
      'Node Version': 'v20.11.0',
      'Runtime': 'Bun 1.3.1',
      'Environment': 'development',
      'Log Level': 'debug',
      'Max Connections': 100,
      'Cache TTL': '300s',
      'Rate Limit': '1000 req/min',
      'Compression': true,
    })
    await delay(300)

    // Custom chart renderer
    logger.info('Request distribution by endpoint:')
    logger.custom('chart', {
      variant: 'bar',
      title: 'Requests per endpoint (last hour)',
      data: [
        { label: 'GET /api/users', value: 1523 },
        { label: 'POST /api/auth', value: 892 },
        { label: 'GET /api/posts', value: 2341 },
        { label: 'PUT /api/settings', value: 156 },
        { label: 'DELETE /api/cache', value: 43 },
      ],
    })
    await delay(300)

    // Another custom type — timeline
    logger.custom('chart', {
      variant: 'bar',
      title: 'Response times (p95) by service',
      data: [
        { label: 'API Gateway', value: 12 },
        { label: 'Auth Service', value: 45 },
        { label: 'User Service', value: 23 },
        { label: 'Database', value: 8 },
        { label: 'Cache', value: 2 },
      ],
    })

    await logger.flush()
  } finally {
    await logger.close()
  }
}
