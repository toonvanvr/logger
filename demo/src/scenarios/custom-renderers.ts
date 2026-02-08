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
    await delay(300)

    // KV with stacked layout
    logger.info('Database connection pool status:')
    logger.custom('kv', {
      entries: [
        { key: 'Active Connections', value: 8, color: '#A8CC7E' },
        { key: 'Idle Connections', value: 2, color: '#7EB8D0' },
        { key: 'Wait Queue', value: 0, color: '#636D83' },
        { key: 'Max Pool Size', value: 10 },
        { key: 'Avg Checkout Time', value: '2.3ms' },
      ],
      layout: 'stacked',
    }, { id: 'pool-status' })
    await delay(300)

    // Sparkline chart — CPU usage over time
    logger.info('CPU usage trend (last 60s):')
    logger.custom('chart', {
      variant: 'sparkline',
      title: 'CPU Usage %',
      data: [
        { label: '0s', value: 23 },
        { label: '10s', value: 45 },
        { label: '20s', value: 38 },
        { label: '30s', value: 72 },
        { label: '40s', value: 56 },
        { label: '50s', value: 41 },
        { label: '60s', value: 33 },
      ],
    })
    await delay(300)

    // Area chart — memory allocation
    logger.info('Memory allocation by region:')
    logger.custom('chart', {
      variant: 'area',
      title: 'Heap allocation (MB) over time',
      data: [
        { label: 'T0', value: 128 },
        { label: 'T1', value: 256 },
        { label: 'T2', value: 220 },
        { label: 'T3', value: 380 },
        { label: 'T4', value: 310 },
        { label: 'T5', value: 290 },
      ],
    })
    await delay(300)

    // Progress with ring style
    logger.info('Memory usage monitoring:')
    logger.custom('progress', {
      value: 1234,
      max: 2048,
      label: 'Heap Memory',
      sublabel: '1.2 GB / 2.0 GB',
      style: 'ring',
      color: '#E6B455',
    }, { id: 'memory-usage' })
    await delay(300)

    await logger.flush()
  } finally {
    await logger.close()
  }
}
