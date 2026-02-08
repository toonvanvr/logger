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

    // Sparkline chart — CPU usage over time (bursty pattern)
    logger.info('CPU usage trend (last 5 min):')
    {
      const cpuData: Array<{ label: string; value: number }> = []
      for (let i = 0; i < 60; i++) {
        const t = i / 60
        // Baseline ~15%, with bursty spikes to 60-80%
        let cpu = 15 + 5 * Math.sin(t * Math.PI * 8)
        // Add random spikes
        if (i % 12 === 3) cpu += 45 + Math.random() * 20  // spike
        if (i % 12 === 4) cpu += 30 + Math.random() * 15  // spike tail
        if (i % 20 === 10) cpu += 55 + Math.random() * 10 // big spike
        cpu += (Math.random() - 0.5) * 6 // noise
        cpu = Math.max(2, Math.min(95, cpu))
        cpuData.push({ label: `${i * 5}s`, value: Math.round(cpu * 10) / 10 })
      }
      logger.custom('chart', {
        variant: 'sparkline',
        title: 'CPU Usage %',
        data: cpuData,
      })
    }
    await delay(300)

    // Area chart — memory allocation (sawtooth + GC pattern)
    logger.info('Memory allocation over time:')
    {
      const memData: Array<{ label: string; value: number }> = []
      let mem = 200
      for (let i = 0; i < 80; i++) {
        const t = i / 80
        // Gradual growth with allocation pressure
        mem += 3 + Math.random() * 4
        // Sine wave noise
        mem += 8 * Math.sin(t * Math.PI * 6)
        // GC drops every ~15 points
        if (i > 0 && i % 15 === 0) {
          mem -= 100 + Math.random() * 100 // GC reclaims 100-200MB
        }
        // Request burst spike at ~25% and ~70% through
        if (i === 20) mem += 150
        if (i === 21) mem -= 80
        if (i === 56) mem += 130
        if (i === 57) mem -= 70
        mem = Math.max(100, Math.min(800, mem))
        memData.push({
          label: `T+${i}`,
          value: Math.round(mem),
        })
      }
      logger.custom('chart', {
        variant: 'area',
        title: 'Heap allocation (MB) over time',
        data: memData,
      })
    }
    await delay(300)

    // Sparkline chart — request rate (diurnal pattern)
    logger.info('Request rate (last 24h):')
    {
      const reqData: Array<{ label: string; value: number }> = []
      for (let i = 0; i < 72; i++) {
        const hour = (i / 3) // 0-24 hours
        // Diurnal sinusoidal pattern: peak at midday, trough at 4am
        const diurnal = Math.sin((hour - 4) / 24 * Math.PI * 2) * 0.5 + 0.5
        let rate = 200 + diurnal * 1800
        // Add noise
        rate += (Math.random() - 0.5) * 120
        rate = Math.max(50, rate)
        const h = Math.floor(hour)
        const m = Math.round((hour - h) * 60)
        reqData.push({
          label: `${String(h).padStart(2, '0')}:${String(m).padStart(2, '0')}`,
          value: Math.round(rate),
        })
      }
      logger.custom('chart', {
        variant: 'sparkline',
        title: 'Requests/min (24h)',
        data: reqData,
      })
    }
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
