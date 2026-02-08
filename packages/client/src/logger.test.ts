import { beforeEach, describe, expect, test } from 'bun:test';
import type { LogEntry, Middleware } from './index.js';
import { Logger } from './logger.js';
import type { TransportAdapter } from './transport/types.js';

// ─── Mock Transport ──────────────────────────────────────────────────

class MockTransport implements TransportAdapter {
  entries: LogEntry[] = [];
  connected = true;
  async connect() {}
  async send(entries: LogEntry[]) {
    this.entries.push(...entries);
  }
  async close() {
    this.connected = false;
  }
}

function createLogger(
  opts?: Partial<ConstructorParameters<typeof Logger>[0]>,
): { logger: Logger; transport: MockTransport } {
  const transport = new MockTransport();
  const logger = new Logger({
    app: 'test-app',
    environment: 'test',
    _transport: transport,
    ...opts,
  });
  return { logger, transport };
}

/** Flush the logger and return all sent entries. */
async function collect(
  logger: Logger,
  transport: MockTransport,
): Promise<LogEntry[]> {
  await logger.flush();
  return transport.entries;
}

describe('Logger', () => {
  let logger: Logger;
  let transport: MockTransport;

  beforeEach(() => {
    ({ logger, transport } = createLogger());
  });

  // ─── Defaults ──────────────────────────────────────────────────

  test('create logger with defaults', () => {
    expect(logger).toBeDefined();
    expect(logger.session.id).toBeTruthy();
  });

  // ─── Session ───────────────────────────────────────────────────

  test('session auto-start on first log', async () => {
    logger.info('hello');
    const entries = await collect(logger, transport);

    // First entry should be session start, second the log itself.
    const sessionEntry = entries.find(
      (e) => e.type === 'session' && e.session_action === 'start',
    );
    expect(sessionEntry).toBeDefined();
  });

  // ─── Severity methods ─────────────────────────────────────────

  test('all severity methods produce correct entries', async () => {
    logger.debug('d');
    logger.info('i');
    logger.warn('w');
    logger.error('e');
    logger.critical('c');

    const entries = await collect(logger, transport);
    // Skip the implicit session-start entry.
    const logs = entries.filter((e) => e.type === 'text');

    expect(logs).toHaveLength(5);
    expect(logs[0].severity).toBe('debug');
    expect(logs[1].severity).toBe('info');
    expect(logs[2].severity).toBe('warning');
    expect(logs[3].severity).toBe('error');
    expect(logs[4].severity).toBe('critical');
  });

  // ─── Error with Error object ──────────────────────────────────

  test('error with Error object extracts stack trace', async () => {
    const err = new Error('test error');
    logger.error(err);

    const entries = await collect(logger, transport);
    const errorEntry = entries.find((e) => e.exception !== undefined);

    expect(errorEntry).toBeDefined();
    expect(errorEntry!.exception!.message).toBe('test error');
    expect(errorEntry!.exception!.type).toBe('Error');
    expect(errorEntry!.exception!.stackTrace).toBeDefined();
    expect(errorEntry!.exception!.stackTrace!.length).toBeGreaterThan(0);
  });

  // ─── Group ─────────────────────────────────────────────────────

  test('group open/close lifecycle', async () => {
    const groupId = logger.group('my group');
    logger.info('inside');
    logger.groupEnd();

    const entries = await collect(logger, transport);
    const groups = entries.filter((e) => e.type === 'group');

    expect(groups).toHaveLength(2);
    expect(groups[0].group_action).toBe('open');
    expect(groups[0].group_label).toBe('my group');
    expect(groups[1].group_action).toBe('close');
    expect(groups[0].group_id).toBe(groups[1].group_id);
    expect(groupId).toBe(groups[0].group_id);
  });

  test('group with callback auto-closes', async () => {
    const groupId = await logger.group('auto', () => {
      logger.info('inside callback');
    });

    const entries = await collect(logger, transport);
    const groups = entries.filter((e) => e.type === 'group');

    expect(groups).toHaveLength(2);
    expect(groups[0].group_action).toBe('open');
    expect(groups[1].group_action).toBe('close');
    expect(groupId).toBe(groups[0].group_id);
  });

  // ─── State ─────────────────────────────────────────────────────

  test('state sets key/value', async () => {
    logger.state('count', 42);

    const entries = await collect(logger, transport);
    const stateEntry = entries.find((e) => e.type === 'state');

    expect(stateEntry).toBeDefined();
    expect(stateEntry!.state_key).toBe('count');
    expect(stateEntry!.state_value).toBe(42);
  });

  // ─── Custom ────────────────────────────────────────────────────

  test('custom with replace flag', async () => {
    logger.custom('widget', { foo: 1 }, { id: 'w1', replace: true });

    const entries = await collect(logger, transport);
    const custom = entries.find((e) => e.type === 'custom');

    expect(custom).toBeDefined();
    expect(custom!.custom_type).toBe('widget');
    expect(custom!.custom_data).toEqual({ foo: 1 });
    expect(custom!.replace).toBe(true);
    expect(custom!.id).toBe('w1');
  });

  test('progress auto-sets replace', async () => {
    logger.progress('Build', 50, 100, { id: 'build-1' });

    const entries = await collect(logger, transport);
    const progress = entries.find(
      (e) => e.type === 'custom' && e.custom_type === 'progress',
    );

    expect(progress).toBeDefined();
    expect(progress!.replace).toBe(true);
    expect(progress!.custom_data).toEqual({
      label: 'Build',
      value: 50,
      max: 100,
    });
  });

  // ─── Table / KV ────────────────────────────────────────────────

  test('table convenience method', async () => {
    logger.table(['Name', 'Age'], [['Alice', 30]]);

    const entries = await collect(logger, transport);
    const table = entries.find(
      (e) => e.type === 'custom' && e.custom_type === 'table',
    );

    expect(table).toBeDefined();
    expect(table!.custom_data).toEqual({
      columns: ['Name', 'Age'],
      rows: [['Alice', 30]],
    });
  });

  test('kv convenience method', async () => {
    logger.kv({ host: 'localhost', port: 8080 });

    const entries = await collect(logger, transport);
    const kv = entries.find(
      (e) => e.type === 'custom' && e.custom_type === 'kv',
    );

    expect(kv).toBeDefined();
    expect(kv!.replace).toBe(true);
    expect((kv!.custom_data as any).entries).toEqual([
      { key: 'host', value: 'localhost' },
      { key: 'port', value: 8080 },
    ]);
  });

  // ─── Middleware ─────────────────────────────────────────────────

  test('middleware chain executes', async () => {
    const calls: string[] = [];

    const mw1: Middleware = (entry, next) => {
      calls.push('mw1');
      next();
    };
    const mw2: Middleware = (entry, next) => {
      calls.push('mw2');
      next();
    };

    const { logger: l2, transport: t2 } = createLogger({
      middleware: [mw1, mw2],
    });
    l2.info('test');
    await l2.flush();

    // mw1 → mw2 → enqueue
    expect(calls).toEqual(['mw1', 'mw2']);
    const logs = t2.entries.filter((e) => e.type === 'text');
    expect(logs).toHaveLength(1);
  });

  // ─── Section ───────────────────────────────────────────────────

  test('section changes current section', async () => {
    logger.section('metrics');
    logger.info('metric log');

    const entries = await collect(logger, transport);
    const log = entries.find((e) => e.type === 'text');

    expect(log).toBeDefined();
    expect(log!.section).toBe('metrics');
  });

  // ─── Close ─────────────────────────────────────────────────────

  test('close flushes and disconnects transport', async () => {
    logger.info('final');
    await logger.close();

    expect(transport.entries.filter((e) => e.type === 'text')).toHaveLength(1);
    expect(transport.connected).toBe(false);
  });
});
