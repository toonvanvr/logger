import { Logger } from '@logger/client'

const delay = (ms: number) => new Promise(r => setTimeout(r, ms))

export async function runStateTracking() {
  const logger = new Logger({ app: 'demo-state', transport: 'http' })

  try {
    // Initial server state
    logger.info('Server initialized — publishing initial state')
    logger.state('server.port', 8080)
    logger.state('server.uptime', '0s')
    logger.state('server.memory.used', '45 MB')
    logger.state('server.memory.total', '512 MB')
    logger.state('server.connections.active', 0)
    logger.state('server.connections.total', 0)
    logger.state('server.status', 'starting')
    await delay(500)

    // Server is ready
    logger.state('server.status', 'running')
    logger.info('Server is ready to accept connections')
    await delay(300)

    // Simulate metrics updates over time
    const metrics = [
      { active: 3, total: 3, memory: '52 MB', uptime: '5s' },
      { active: 7, total: 10, memory: '61 MB', uptime: '10s' },
      { active: 12, total: 22, memory: '78 MB', uptime: '15s' },
      { active: 18, total: 40, memory: '95 MB', uptime: '20s' },
      { active: 15, total: 55, memory: '88 MB', uptime: '25s' },
      { active: 8, total: 63, memory: '72 MB', uptime: '30s' },
    ]

    for (const m of metrics) {
      logger.state('server.connections.active', m.active)
      logger.state('server.connections.total', m.total)
      logger.state('server.memory.used', m.memory)
      logger.state('server.uptime', m.uptime)
      logger.info(`Connections: ${m.active} active / ${m.total} total — memory: ${m.memory}`)
      await delay(400)
    }

    // Simulate a high-memory event
    logger.state('server.memory.used', '480 MB')
    logger.warn('Memory usage critical: 480 MB / 512 MB (93.75%)')
    await delay(300)

    // GC kicks in
    logger.state('server.memory.used', '120 MB')
    logger.info('Garbage collection completed — freed 360 MB')
    logger.state('server.status', 'healthy')

    await logger.flush()
  } finally {
    await logger.close()
  }
}
