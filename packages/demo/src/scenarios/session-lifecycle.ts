import { Logger } from '@logger/client'

const delay = (ms: number) => new Promise(r => setTimeout(r, ms))

export async function runSessionLifecycle() {
  // First session
  const logger1 = new Logger({ app: 'demo-session', transport: 'http' })

  try {
    logger1.session.start({
      version: '2.1.0',
      environment: 'staging',
      hostname: 'app-server-01',
    })
    logger1.info(`Session started: ${logger1.session.id}`)
    await delay(300)

    logger1.info('Processing some work in session 1...')
    await delay(200)
    logger1.debug('Task A completed')
    await delay(200)
    logger1.debug('Task B completed')
    await delay(200)

    logger1.info('Ending first session')
    logger1.session.end()
    await logger1.flush()
  } finally {
    await logger1.close()
  }

  await delay(500)

  // Second session (simulating app restart)
  const logger2 = new Logger({ app: 'demo-session', transport: 'http' })

  try {
    logger2.session.start({
      version: '2.1.0',
      environment: 'staging',
      hostname: 'app-server-01',
      restartReason: 'config-change',
    })
    logger2.info(`New session started after restart: ${logger2.session.id}`)
    await delay(300)

    logger2.info('Processing work in session 2...')
    await delay(200)
    logger2.info('Configuration reloaded successfully')
    await delay(200)

    // Demonstrate that heartbeat is automatic (session stays alive)
    logger2.info('Session remains active — heartbeat is automatic via transport')
    await delay(300)

    logger2.info('Ending second session')
    logger2.session.end()
    await logger2.flush()
  } finally {
    await logger2.close()
  }
}
