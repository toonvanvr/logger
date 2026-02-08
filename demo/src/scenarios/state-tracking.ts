import { Logger } from '@logger/client'

const delay = (ms: number) => new Promise(r => setTimeout(r, ms))

export async function runStateTracking() {
  const logger = new Logger({ app: 'demo-state', transport: 'http' })
  const isStandalone = process.argv.includes('state')
  const maxTicks = isStandalone ? Infinity : 10

  // Sliding windows for chart data
  const heapWindow: number[] = []
  const cpuWindow: number[] = []
  const requestBins: number[] = []

  let heap = 80 // MB
  let totalConnections = 0

  try {
    // Initial server state
    logger.info('Server initialized — publishing initial state')
    logger.state('server.port', 8080)
    logger.state('server.uptime', '0s')
    logger.state('server.memory.used', '80 MB')
    logger.state('server.memory.total', '512 MB')
    logger.state('server.connections.active', 0)
    logger.state('server.connections.total', 0)
    logger.state('server.status', 'running')
    await delay(300)

    // Graceful shutdown for standalone mode
    if (isStandalone) {
      process.on('SIGINT', async () => {
        await logger.flush()
        await logger.close()
        process.exit(0)
      })
    }

    for (let tick = 1; tick <= maxTicks; tick++) {
      // Simulate metrics
      const activeConnections = Math.max(
        0,
        Math.round(8 + Math.sin(tick / 15) * 12 + (Math.random() - 0.5) * 6),
      )
      totalConnections += Math.floor(Math.random() * 3)

      // Heap: sawtooth (grow 2-5 MB/tick, GC drop every ~20 ticks)
      heap += 2 + Math.random() * 3
      if (tick % 20 === 0) heap = Math.max(80, heap * 0.5)

      // CPU: baseline + sine variation + random noise
      const cpu = Math.min(
        85,
        Math.max(
          5,
          15 + Math.sin(tick / 10) * 10 + (Math.random() - 0.5) * 10 + (activeConnections > 30 ? 20 : 0),
        ),
      )

      const uptimeSeconds = tick * 2
      const uptime =
        uptimeSeconds >= 60
          ? `${Math.floor(uptimeSeconds / 60)}m${uptimeSeconds % 60}s`
          : `${uptimeSeconds}s`

      // Update scalar state
      logger.state('server.connections.active', activeConnections)
      logger.state('server.connections.total', totalConnections)
      logger.state('server.memory.used', `${Math.round(heap)} MB`)
      logger.state('server.uptime', uptime)

      // Update sliding windows
      heapWindow.push(Math.round(heap))
      if (heapWindow.length > 60) heapWindow.shift()

      cpuWindow.push(Math.round(cpu * 10) / 10)
      if (cpuWindow.length > 60) cpuWindow.shift()

      // Emit chart states
      logger.state('_chart.heap', {
        type: 'area',
        values: [...heapWindow],
        title: 'Heap (MB)',
        color: '#E6B455',
      })

      logger.state('_chart.cpu', {
        type: 'sparkline',
        values: [...cpuWindow],
        title: 'CPU %',
        color: '#F07668',
      })

      // Request bins: update every 5th tick
      if (tick % 5 === 0) {
        const bin = Math.max(
          10,
          Math.round(80 + Math.sin(tick / 8) * 50 + (Math.random() - 0.5) * 40),
        )
        requestBins.push(bin)
        if (requestBins.length > 30) requestBins.shift()

        logger.state('_chart.requests', {
          type: 'dense_bar',
          values: [...requestBins],
          title: 'Req/10s',
        })
      }

      // Info log per tick
      logger.info(`Tick ${tick}: ${activeConnections} conn, ${Math.round(heap)} MB heap, ${cpu.toFixed(1)}% CPU`)

      await delay(2000)
    }

    // High memory event at end (for finite mode)
    if (!isStandalone) {
      logger.state('server.memory.used', '480 MB')
      logger.warn('Memory usage critical: 480 MB / 512 MB')
      await delay(300)
      logger.state('server.memory.used', '120 MB')
      logger.info('Garbage collection completed — freed 360 MB')
      logger.state('server.status', 'healthy')
    }

    await logger.flush()
  } finally {
    await logger.close()
  }
}
