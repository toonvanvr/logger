import { Logger } from '@logger/client'

const delay = (ms: number) => new Promise(r => setTimeout(r, ms))

export async function runErrorDebugging() {
  const logger = new Logger({ app: 'demo-errors', transport: 'http' })

  try {
    // Simple error with stack trace
    logger.info('Attempting database connection...')
    await delay(200)

    try {
      throw new Error('ECONNREFUSED: Connection refused to postgres://localhost:5432')
    } catch (err) {
      logger.error(err as Error, { host: 'localhost', port: '5432' })
    }
    await delay(300)

    // Nested try/catch with cause chain
    logger.info('Starting user authentication flow...')
    await delay(200)

    try {
      try {
        throw new TypeError('Cannot read property "token" of undefined')
      } catch (innerErr) {
        throw new Error('Authentication failed: token validation error', {
          cause: innerErr,
        })
      }
    } catch (err) {
      logger.error(err as Error, { userId: 'usr_12345', flow: 'oauth2' })
    }
    await delay(300)

    // Error recovery pattern
    logger.warn('Primary API endpoint unreachable — attempting failover')
    await delay(200)

    for (let attempt = 1; attempt <= 3; attempt++) {
      try {
        if (attempt < 3) {
          throw new Error(`Failover attempt ${attempt} failed: timeout after 5000ms`)
        }
        logger.info(`Failover succeeded on attempt ${attempt}`)
      } catch (err) {
        logger.warn(`Retry ${attempt}/3 failed: ${(err as Error).message}`)
        await delay(200)
      }
    }
    await delay(200)

    // Critical error with deep stack trace and 2-level cause chain
    try {
      processIncomingRequest()
    } catch (err) {
      logger.critical(err as Error, { pipeline: 'data-import', batchId: 'batch_789' })
    }

    await logger.flush()
  } finally {
    await logger.close()
  }
}

// Deep call chain helpers — produce 10+ frames for expand-5 exercising.
function processIncomingRequest() {
  validateRequestPayload()
}
function validateRequestPayload() {
  deserializeMessageBody()
}
function deserializeMessageBody() {
  parseJsonContent()
}
function parseJsonContent() {
  transformDataSchema()
}
function transformDataSchema() {
  applyBusinessRules()
}
function applyBusinessRules() {
  executeDatabaseQuery()
}
function executeDatabaseQuery() {
  buildQueryPlan()
}
function buildQueryPlan() {
  optimizeQueryExecution()
}
function optimizeQueryExecution() {
  resolveTableReferences()
}
function resolveTableReferences(): never {
  const innerCause = new RangeError('Array index 99 out of bounds [0..49]')
  const outerCause = new Error('Failed to resolve foreign key constraint on "user_sessions"', {
    cause: innerCause,
  })
  throw new Error('Batch processing pipeline crashed', { cause: outerCause })
}
