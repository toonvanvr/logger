import { Logger } from '@logger/client'

const delay = (ms: number) => new Promise(r => setTimeout(r, ms))

export async function runRpcTools() {
  const logger = new Logger({ app: 'demo-rpc', transport: 'http' })

  try {
    // Register RPC tools that the viewer can invoke
    logger.rpc.register('getConfig', {
      description: 'Returns the current application configuration',
      category: 'getter',
      handler: () => ({
        logLevel: 'debug',
        maxConnections: 100,
        cacheTTL: 300,
        features: {
          darkMode: true,
          experimentalApi: false,
          metricsEnabled: true,
        },
      }),
    })

    logger.rpc.register('setDebugLevel', {
      description: 'Sets the application debug level',
      category: 'tool',
      argsSchema: {
        type: 'object',
        properties: {
          level: {
            type: 'string',
            enum: ['debug', 'info', 'warning', 'error'],
            description: 'The new debug level',
          },
        },
        required: ['level'],
      },
      confirm: true,
      handler: (args) => {
        const { level } = args as { level: string }
        logger.info(`Debug level changed to: ${level}`)
        return { success: true, previousLevel: 'info', newLevel: level }
      },
    })

    logger.rpc.register('getMemoryUsage', {
      description: 'Returns current memory usage statistics',
      category: 'getter',
      handler: () => {
        const mem = process.memoryUsage()
        return {
          heapUsed: `${Math.round(mem.heapUsed / 1024 / 1024)} MB`,
          heapTotal: `${Math.round(mem.heapTotal / 1024 / 1024)} MB`,
          rss: `${Math.round(mem.rss / 1024 / 1024)} MB`,
          external: `${Math.round(mem.external / 1024 / 1024)} MB`,
        }
      },
    })

    logger.info('RPC tools registered: getConfig, setDebugLevel, getMemoryUsage')
    logger.info('Waiting 30s for viewer to invoke tools...')

    // Wait for up to 30s, checking every second
    const deadline = Date.now() + 30_000
    while (Date.now() < deadline) {
      await delay(1000)
    }

    logger.info('RPC wait period ended')

    await logger.flush()
  } finally {
    await logger.close()
  }
}
