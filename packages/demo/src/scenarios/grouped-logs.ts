import { Logger } from '@logger/client'

const delay = (ms: number) => new Promise(r => setTimeout(r, ms))

export async function runGroupedLogs() {
  const logger = new Logger({ app: 'demo-groups', transport: 'http' })

  try {
    // Manual group open/close
    logger.group('Database migration')
    logger.info('Running migration 001_create_users.sql')
    await delay(100)
    logger.info('Created table: users (id, email, name, created_at)')
    await delay(100)
    logger.info('Running migration 002_create_posts.sql')
    await delay(100)
    logger.info('Created table: posts (id, user_id, title, body, published_at)')
    await delay(100)
    logger.info('Running migration 003_add_indexes.sql')
    await delay(100)
    logger.info('Created index: idx_users_email on users(email)')
    logger.info('Created index: idx_posts_user_id on posts(user_id)')
    logger.info('All migrations completed successfully')
    logger.groupEnd()
    await delay(300)

    // Nested groups
    logger.group('Application startup')
    logger.info('Loading configuration from environment')
    await delay(100)

    logger.group('Initialize services')
    logger.info('Database pool: 10 connections established')
    logger.info('Redis cache: connected to localhost:6379')
    logger.info('Message queue: subscribed to 3 topics')
    logger.groupEnd()
    await delay(200)

    logger.group('Register routes')
    logger.info('GET  /api/users — UserController.list')
    logger.info('POST /api/users — UserController.create')
    logger.info('GET  /api/posts — PostController.list')
    logger.info('POST /api/posts — PostController.create')
    logger.info('Registered 4 route handlers')
    logger.groupEnd()
    await delay(100)

    logger.info('Application startup complete (1.2s)')
    logger.groupEnd()
    await delay(300)

    // Group with callback — auto-closes on completion
    await logger.group('Auth flow', async () => {
      logger.info('Received login request for user@example.com')
      await delay(100)
      logger.info('Password hash verified')
      await delay(100)
      logger.info('JWT token generated (expires in 3600s)')
      await delay(100)
      logger.info('Session created: sess_abc123')
    })

    await logger.flush()
  } finally {
    await logger.close()
  }
}
