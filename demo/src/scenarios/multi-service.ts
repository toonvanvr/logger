import { Logger } from '@logger/client'

const delay = (ms: number) => new Promise(r => setTimeout(r, ms))

export async function runMultiService() {
  const api = new Logger({ app: 'api-server', transport: 'http' })
  const web = new Logger({ app: 'web-frontend', transport: 'http' })
  const worker = new Logger({ app: 'worker', transport: 'http' })

  // Set sections so the viewer's section tabs become meaningful
  api.section('HTTP')
  web.section('Frontend')
  worker.section('Jobs')

  try {
    // Interleaved startup
    api.info('API server starting on port 8080')
    await delay(100)
    web.info('Frontend dev server starting on port 3000')
    await delay(100)
    worker.info('Background worker connecting to job queue')
    await delay(100)

    api.info('Loaded 42 route handlers')
    web.debug('Compiled 128 TypeScript modules in 2.3s')
    worker.info('Subscribed to queues: emails, notifications, reports')
    await delay(200)

    // Simulated request flow across services
    api.info('POST /api/users — received registration request')
    await delay(50)
    api.debug('Validating request body: { email: "alice@example.com" }')
    await delay(50)
    worker.info('Job enqueued: send-welcome-email (job_id: j_abc123)')
    await delay(100)
    web.info('WebSocket push: user_created event sent to 3 connected clients')
    await delay(50)
    worker.info('Processing job: send-welcome-email')
    await delay(200)
    worker.info('Email sent to alice@example.com via SendGrid')
    await delay(50)
    api.info('POST /api/users — 201 Created (145ms)')

    // Warnings and errors from different services
    await delay(300)
    api.warn('Rate limit approaching: 980/1000 requests in current window')
    web.warn('Bundle size exceeds 500KB threshold: 547KB')
    worker.error('Failed to process job: generate-report (timeout after 30s)')
    await delay(100)
    api.info('Rate limit window reset')
    worker.info('Retrying job: generate-report (attempt 2/3)')
    await delay(200)
    worker.info('Job completed: generate-report (42.1s)')

    await api.flush()
    await web.flush()
    await worker.flush()
  } finally {
    await api.close()
    await web.close()
    await worker.close()
  }
}
