import type { LogEntry } from '@logger/shared';
import { describe, expect, test } from 'bun:test';
import { LogQueue } from './queue.js';

function makeEntry(overrides?: Partial<LogEntry>): LogEntry {
  return {
    id: crypto.randomUUID(),
    timestamp: new Date().toISOString(),
    session_id: 'test-session',
    severity: 'info',
    type: 'text',
    text: 'hello',
    ...overrides,
  } as LogEntry;
}

describe('LogQueue', () => {
  test('push and drain entries', () => {
    const q = new LogQueue();
    const e1 = makeEntry({ text: 'one' });
    const e2 = makeEntry({ text: 'two' });

    expect(q.push(e1)).toBe(true);
    expect(q.push(e2)).toBe(true);
    expect(q.size).toBe(2);

    const drained = q.drain();
    expect(drained).toHaveLength(2);
    expect(drained[0].text).toBe('one');
    expect(drained[1].text).toBe('two');
    expect(q.size).toBe(0);
  });

  test('drain with maxCount', () => {
    const q = new LogQueue();
    q.push(makeEntry({ text: 'a' }));
    q.push(makeEntry({ text: 'b' }));
    q.push(makeEntry({ text: 'c' }));

    const drained = q.drain(2);
    expect(drained).toHaveLength(2);
    expect(q.size).toBe(1);
  });

  test('respects byte limit', () => {
    // Estimate the size of one entry to calibrate the limit.
    const e1 = makeEntry({ text: 'x'.repeat(200) });
    const oneEntrySize = JSON.stringify(e1).length * 2;
    // Allow room for one entry but not two.
    const q = new LogQueue(oneEntrySize + 10);

    const first = q.push(e1);
    expect(first).toBe(true);

    // Second push should fail — we've already used most of the budget.
    const second = q.push(makeEntry({ text: 'y'.repeat(200) }));
    expect(second).toBe(false);
  });

  test('returns false when full', () => {
    const q = new LogQueue(1); // 1 byte — essentially full immediately.
    expect(q.push(makeEntry())).toBe(false);
  });

  test('byteEstimate tracks usage', () => {
    const q = new LogQueue();
    expect(q.byteEstimate).toBe(0);

    q.push(makeEntry({ text: 'hello' }));
    expect(q.byteEstimate).toBeGreaterThan(0);

    q.drain();
    expect(q.byteEstimate).toBe(0);
  });

  test('clear empties queue', () => {
    const q = new LogQueue();
    q.push(makeEntry());
    q.push(makeEntry());
    expect(q.size).toBe(2);

    q.clear();
    expect(q.size).toBe(0);
    expect(q.byteEstimate).toBe(0);
    expect(q.drain()).toHaveLength(0);
  });
});
