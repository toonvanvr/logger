import { beforeEach, describe, expect, test } from 'bun:test'
import type { Middleware, QueuedMessage } from './index.js'
import { Logger } from './logger.js'
import type { TransportAdapter } from './transport/types.js'

// ─── Mock Transport ──────────────────────────────────────────────────

class MockTransport implements TransportAdapter {
  entries: QueuedMessage[] = [];
  connected = true;
  async connect() { }
  async send(messages: QueuedMessage[]) {
    this.entries.push(...messages)
  }
  async close() {
    this.connected = false
  }
}

function createLogger(
  opts?: Partial<ConstructorParameters<typeof Logger>[0]>,
): { logger: Logger; transport: MockTransport } {
  const transport = new MockTransport()
  const logger = new Logger({
    app: 'test-app',
    environment: 'test',
    _transport: transport,
    ...opts,
  })
  return { logger, transport }
}

/** Flush the logger and return all sent entries. */
async function collect(
  logger: Logger,
  transport: MockTransport,
): Promise<QueuedMessage[]> {
  await logger.flush()
  return transport.entries
}

describe('Logger', () => {
  let logger: Logger
  let transport: MockTransport

  beforeEach(() => {
    ({ logger, transport } = createLogger())
  })

  // ─── Defaults ──────────────────────────────────────────────────

  test('create logger with defaults', () => {
    expect(logger).toBeDefined()
    expect(logger.session.id).toBeTruthy()
  })

  // ─── Session ───────────────────────────────────────────────────

  test('session auto-start on first log', async () => {
    logger.info('hello')
    const entries = await collect(logger, transport)

    // First entry should be session start, second the log itself.
    const sessionEntry = entries.find(
      (e) => e.kind === 'session' && e.action === 'start',
    )
    expect(sessionEntry).toBeDefined()
  })

  // ─── Severity methods ─────────────────────────────────────────

  test('all severity methods produce correct entries', async () => {
    logger.debug('d')
    logger.info('i')
    logger.warn('w')
    logger.error('e')
    logger.critical('c')

    const entries = await collect(logger, transport)
    // Skip the implicit session-start entry.
    const logs = entries.filter((e) => e.kind === 'event' && e.message !== undefined && e.exception === undefined)

    expect(logs).toHaveLength(5)
    expect(logs[0].severity).toBe('debug')
    expect(logs[1].severity).toBe('info')
    expect(logs[2].severity).toBe('warning')
    expect(logs[3].severity).toBe('error')
    expect(logs[4].severity).toBe('critical')
  })

  // ─── Error with Error object ──────────────────────────────────

  test('error with Error object extracts stack trace', async () => {
    const err = new Error('test error')
    logger.error(err)

    const entries = await collect(logger, transport)
    const errorEntry = entries.find((e) => e.exception !== undefined)

    expect(errorEntry).toBeDefined()
    expect((errorEntry!.exception as any).message).toBe('test error')
    expect((errorEntry!.exception as any).type).toBe('Error')
    expect((errorEntry!.exception as any).stack_trace).toBeDefined()
    expect((errorEntry!.exception as any).stack_trace.length).toBeGreaterThan(0)
  })

  // ─── Group ─────────────────────────────────────────────────────

  test('group open/close lifecycle', async () => {
    const groupId = logger.group('my group')
    logger.info('inside')
    logger.groupEnd()

    const entries = await collect(logger, transport)
    // Group boundaries: open has id===group_id, close has message===''.
    const groups = entries.filter((e) =>
      e.kind === 'event' && e.group_id !== undefined &&
      (e.id === e.group_id || e.message === ''),
    )

    expect(groups).toHaveLength(2)
    expect(groups[0].message).toBe('my group')
    expect(groups[1].message).toBe('')
    expect(groups[0].group_id).toBe(groups[1].group_id)
    expect(groupId).toBe(groups[0].group_id as string)
  })

  test('group with callback auto-closes', async () => {
    const groupId = await logger.group('auto', () => {
      logger.info('inside callback')
    })

    const entries = await collect(logger, transport)
    const groups = entries.filter((e) =>
      e.kind === 'event' && e.group_id !== undefined &&
      (e.id === e.group_id || e.message === ''),
    )

    expect(groups).toHaveLength(2)
    expect(groups[0].message).toBe('auto')
    expect(groups[1].message).toBe('')
    expect(groupId).toBe(groups[0].group_id as string)
  })

  // ─── State ─────────────────────────────────────────────────────

  test('state sets key/value', async () => {
    logger.state('count', 42)

    const entries = await collect(logger, transport)
    const stateEntry = entries.find((e) => e.kind === 'data')

    expect(stateEntry).toBeDefined()
    expect(stateEntry!.key).toBe('count')
    expect(stateEntry!.value).toBe(42)
  })

  // ─── Custom ────────────────────────────────────────────────────

  test('custom with replace flag', async () => {
    logger.custom('widget', { foo: 1 }, { id: 'w1', replace: true })

    const entries = await collect(logger, transport)
    const custom = entries.find((e) => e.kind === 'event' && e.widget !== undefined)

    expect(custom).toBeDefined()
    expect((custom!.widget as any).type).toBe('widget')
    expect((custom!.widget as any).foo).toBe(1)
    expect(custom!.replace).toBe(true)
    expect(custom!.id).toBe('w1')
  })

  test('progress auto-sets replace', async () => {
    logger.progress('Build', 50, 100, { id: 'build-1' })

    const entries = await collect(logger, transport)
    const progress = entries.find(
      (e) => e.kind === 'event' && e.widget !== undefined && (e.widget as any).type === 'progress',
    )

    expect(progress).toBeDefined()
    expect(progress!.replace).toBe(true)
    expect((progress!.widget as any).label).toBe('Build')
    expect((progress!.widget as any).value).toBe(50)
    expect((progress!.widget as any).max).toBe(100)
  })

  // ─── Table / KV ────────────────────────────────────────────────

  test('table convenience method', async () => {
    logger.table(['Name', 'Age'], [['Alice', 30]])

    const entries = await collect(logger, transport)
    const table = entries.find(
      (e) => e.kind === 'event' && e.widget !== undefined && (e.widget as any).type === 'table',
    )

    expect(table).toBeDefined()
    expect((table!.widget as any).columns).toEqual(['Name', 'Age'])
    expect((table!.widget as any).rows).toEqual([['Alice', 30]])
  })

  test('kv convenience method', async () => {
    logger.kv({ host: 'localhost', port: 8080 })

    const entries = await collect(logger, transport)
    const kv = entries.find(
      (e) => e.kind === 'event' && e.widget !== undefined && (e.widget as any).type === 'kv',
    )

    expect(kv).toBeDefined()
    expect(kv!.replace).toBe(true)
    expect((kv!.widget as any).entries).toEqual([
      { key: 'host', value: 'localhost' },
      { key: 'port', value: 8080 },
    ])
  })

  // ─── Middleware ─────────────────────────────────────────────────

  test('middleware chain executes', async () => {
    const calls: string[] = []

    const mw1: Middleware = (entry, next) => {
      calls.push('mw1')
      next()
    }
    const mw2: Middleware = (entry, next) => {
      calls.push('mw2')
      next()
    }

    const { logger: l2, transport: t2 } = createLogger({
      middleware: [mw1, mw2],
    })
    l2.info('test')
    await l2.flush()

    // mw1 → mw2 → enqueue
    expect(calls).toEqual(['mw1', 'mw2'])
    const logs = t2.entries.filter((e) => e.kind === 'event' && e.message !== undefined && e.exception === undefined)
    expect(logs).toHaveLength(1)
  })

  // ─── Section ───────────────────────────────────────────────────

  test('section changes current section', async () => {
    logger.section('metrics')
    logger.info('metric log')

    const entries = await collect(logger, transport)
    const log = entries.find((e) => e.kind === 'event' && e.message !== undefined && e.exception === undefined)

    expect(log).toBeDefined()
    expect(log!.tag).toBe('metrics')
  })

  // ─── Close ─────────────────────────────────────────────────────

  test('close flushes and disconnects transport', async () => {
    logger.info('final')
    await logger.close()

    expect(transport.entries.filter((e) => e.kind === 'event' && e.message !== undefined && e.exception === undefined)).toHaveLength(1)
    expect(transport.connected).toBe(false)
  })
})
