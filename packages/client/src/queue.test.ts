import { describe, expect, test } from 'bun:test'
import type { QueuedMessage } from './logger-types.js'
import { LogQueue } from './queue.js'

function makeEntry(overrides?: Record<string, unknown>): QueuedMessage {
  return {
    kind: 'event',
    id: crypto.randomUUID(),
    session_id: 'test-session',
    severity: 'info',
    message: 'hello',
    generated_at: new Date().toISOString(),
    ...overrides,
  } as QueuedMessage
}

describe('LogQueue', () => {
  test('push and drain entries', () => {
    const q = new LogQueue()
    const e1 = makeEntry({ message: 'one' })
    const e2 = makeEntry({ message: 'two' })

    expect(q.push(e1)).toBe(true)
    expect(q.push(e2)).toBe(true)
    expect(q.size).toBe(2)

    const drained = q.drain()
    expect(drained).toHaveLength(2)
    expect(drained[0].message).toBe('one')
    expect(drained[1].message).toBe('two')
    expect(q.size).toBe(0)
  })

  test('drain with maxCount', () => {
    const q = new LogQueue()
    q.push(makeEntry({ message: 'a' }))
    q.push(makeEntry({ message: 'b' }))
    q.push(makeEntry({ message: 'c' }))

    const drained = q.drain(2)
    expect(drained).toHaveLength(2)
    expect(q.size).toBe(1)
  })

  test('respects byte limit', () => {
    // Estimate the size of one entry to calibrate the limit.
    const e1 = makeEntry({ message: 'x'.repeat(200) })
    const oneEntrySize = JSON.stringify(e1).length * 2
    // Allow room for one entry but not two.
    const q = new LogQueue(oneEntrySize + 10)

    const first = q.push(e1)
    expect(first).toBe(true)

    // Second push should fail — we've already used most of the budget.
    const second = q.push(makeEntry({ message: 'y'.repeat(200) }))
    expect(second).toBe(false)
  })

  test('returns false when full', () => {
    const q = new LogQueue(1) // 1 byte — essentially full immediately.
    expect(q.push(makeEntry())).toBe(false)
  })

  test('byteEstimate tracks usage', () => {
    const q = new LogQueue()
    expect(q.byteEstimate).toBe(0)

    q.push(makeEntry({ message: 'hello' }))
    expect(q.byteEstimate).toBeGreaterThan(0)

    q.drain()
    expect(q.byteEstimate).toBe(0)
  })

  test('clear empties queue', () => {
    const q = new LogQueue()
    q.push(makeEntry())
    q.push(makeEntry())
    expect(q.size).toBe(2)

    q.clear()
    expect(q.size).toBe(0)
    expect(q.byteEstimate).toBe(0)
    expect(q.drain()).toHaveLength(0)
  })
})
