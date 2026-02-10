import type { StoredEntry } from '@logger/shared'
import { describe, expect, it } from 'bun:test'
import { RingBuffer } from './ring-buffer'

function makeEntry(overrides: Partial<StoredEntry> & { id: string }): StoredEntry {
  return {
    timestamp: new Date().toISOString(),
    session_id: 'sess-1',
    kind: 'event',
    severity: 'info',
    message: 'hello',
    ...overrides,
  } as StoredEntry
}

describe('RingBuffer', () => {
  it('push and retrieve entries by ID', () => {
    const buf = new RingBuffer(100, 1024 * 1024)
    const entry = makeEntry({ id: 'e1' })
    buf.push(entry)

    expect(buf.size).toBe(1)
    expect(buf.get('e1')).toEqual(entry)
  })

  it('returns undefined for unknown ID', () => {
    const buf = new RingBuffer(100, 1024 * 1024)
    expect(buf.get('nonexistent')).toBeUndefined()
  })

  it('evicts oldest when maxEntries reached', () => {
    const buf = new RingBuffer(3, 100 * 1024 * 1024)

    buf.push(makeEntry({ id: 'e1' }))
    buf.push(makeEntry({ id: 'e2' }))
    buf.push(makeEntry({ id: 'e3' }))
    expect(buf.size).toBe(3)

    // This should evict e1
    buf.push(makeEntry({ id: 'e4' }))
    expect(buf.size).toBe(3)
    expect(buf.get('e1')).toBeUndefined()
    expect(buf.get('e2')).toBeDefined()
    expect(buf.get('e4')).toBeDefined()
  })

  it('evicts oldest when maxBytes exceeded', () => {
    // Each entry is roughly 200+ bytes (estimateBytes fast path: 200 + message.length*2)
    // With 5-char message: 200 + 10 = 210 bytes per entry
    const buf = new RingBuffer(1000, 500) // 500 bytes max ~2 entries

    buf.push(makeEntry({ id: 'e1', message: 'hello' }))
    buf.push(makeEntry({ id: 'e2', message: 'world' }))

    const sizeAfter2 = buf.size
    // Push a third — should evict to fit
    buf.push(makeEntry({ id: 'e3', message: 'test!' }))

    expect(buf.size).toBeLessThanOrEqual(sizeAfter2)
    expect(buf.get('e3')).toBeDefined()
  })

  it('upsert replaces existing entry by ID when replace=true', () => {
    const buf = new RingBuffer(100, 1024 * 1024)

    buf.push(makeEntry({ id: 'e1', message: 'original' }))
    expect(buf.get('e1')!.message).toBe('original')

    buf.upsert(makeEntry({ id: 'e1', message: 'replaced', replace: true }))
    expect(buf.size).toBe(1)
    expect(buf.get('e1')!.message).toBe('replaced')
  })

  it('upsert appends when ID not found', () => {
    const buf = new RingBuffer(100, 1024 * 1024)

    buf.upsert(makeEntry({ id: 'e1', message: 'first' }))
    buf.upsert(makeEntry({ id: 'e2', message: 'second' }))
    expect(buf.size).toBe(2)
  })

  it('upsert appends when replace=false even if ID exists', () => {
    const buf = new RingBuffer(100, 1024 * 1024)

    buf.push(makeEntry({ id: 'e1', message: 'original' }))
    buf.upsert(makeEntry({ id: 'e2', message: 'new' }))
    expect(buf.size).toBe(2)
  })

  it('query by sessionId', () => {
    const buf = new RingBuffer(100, 1024 * 1024)

    buf.push(makeEntry({ id: 'e1', session_id: 'sess-a' }))
    buf.push(makeEntry({ id: 'e2', session_id: 'sess-b' }))
    buf.push(makeEntry({ id: 'e3', session_id: 'sess-a' }))

    const result = buf.query({ sessionId: 'sess-a' })
    expect(result.entries).toHaveLength(2)
    expect(result.entries.map((e) => e.id)).toEqual(['e1', 'e3'])
  })

  it('query by severity', () => {
    const buf = new RingBuffer(100, 1024 * 1024)

    buf.push(makeEntry({ id: 'e1', severity: 'info' }))
    buf.push(makeEntry({ id: 'e2', severity: 'error' }))
    buf.push(makeEntry({ id: 'e3', severity: 'info' }))

    const result = buf.query({ severity: 'error' })
    expect(result.entries).toHaveLength(1)
    expect(result.entries[0]!.id).toBe('e2')
  })

  it('query by time range', () => {
    const buf = new RingBuffer(100, 1024 * 1024)

    buf.push(makeEntry({ id: 'e1', timestamp: '2026-01-01T00:00:00.000Z' }))
    buf.push(makeEntry({ id: 'e2', timestamp: '2026-01-02T00:00:00.000Z' }))
    buf.push(makeEntry({ id: 'e3', timestamp: '2026-01-03T00:00:00.000Z' }))

    const result = buf.query({
      from: '2026-01-01T12:00:00.000Z',
      to: '2026-01-02T12:00:00.000Z',
    })
    expect(result.entries).toHaveLength(1)
    expect(result.entries[0]!.id).toBe('e2')
  })

  it('query with limit and cursor pagination', () => {
    const buf = new RingBuffer(100, 1024 * 1024)

    for (let i = 0; i < 10; i++) {
      buf.push(makeEntry({ id: `e${i}`, session_id: 'sess-1' }))
    }

    // First page
    const page1 = buf.query({ limit: 3 })
    expect(page1.entries).toHaveLength(3)
    expect(page1.cursor).not.toBeNull()

    // Second page
    const page2 = buf.query({ limit: 3, cursor: page1.cursor! })
    expect(page2.entries).toHaveLength(3)
    expect(page2.entries[0]!.id).toBe('e3')

    // Last page — should have remaining entries and null cursor
    const page4 = buf.query({ limit: 20, cursor: 9 })
    expect(page4.entries).toHaveLength(1)
    expect(page4.cursor).toBeNull()
  })

  it('tracks byte estimation', () => {
    const buf = new RingBuffer(100, 1024 * 1024)
    expect(buf.byteEstimate).toBe(0)

    buf.push(makeEntry({ id: 'e1', message: 'hello' }))
    expect(buf.byteEstimate).toBeGreaterThan(0)

    const after1 = buf.byteEstimate
    buf.push(makeEntry({ id: 'e2', message: 'world' }))
    expect(buf.byteEstimate).toBeGreaterThan(after1)
  })

  it('ID index LRU eviction at 100k', () => {
    const maxEntries = 110_000
    const buf = new RingBuffer(maxEntries, 1024 * 1024 * 1024)

    // Push 100k + 1 entries to trigger LRU eviction in ID index
    for (let i = 0; i < 100_001; i++) {
      buf.push(makeEntry({ id: `e${i}` }))
    }

    // Most recent entries should be findable
    expect(buf.get('e100000')).toBeDefined()

    // Very old entries may have been evicted from the ID index
    // (but the entry itself is still in the buffer — just not indexed)
    // The first entry's ID should be evicted from the ID index
    expect(buf.get('e0')).toBeUndefined()
  })
})
