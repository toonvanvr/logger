import type { StoredEntry } from '@logger/shared'
import { describe, expect, it } from 'bun:test'
import { HookManager, createRedactHook } from './hooks'

function makeEntry(overrides: Partial<StoredEntry> = {}): StoredEntry {
  return {
    id: '550e8400-e29b-41d4-a716-446655440000',
    timestamp: new Date().toISOString(),
    session_id: 'sess-1',
    severity: 'info',
    kind: 'event',
    message: 'hello world',
    ...overrides,
  } as StoredEntry
}

describe('HookManager', () => {
  it('registers and runs pre-validate hooks', () => {
    const manager = new HookManager()
    const calls: unknown[] = []

    manager.registerHook('pre-validate', (raw) => {
      calls.push(raw)
      return raw
    })

    const input = { foo: 'bar' }
    const result = manager.runPreValidate(input)
    expect(calls).toHaveLength(1)
    expect(calls[0]).toBe(input)
    expect(result).toBe(input)
  })

  it('registers and runs post-validate hooks', () => {
    const manager = new HookManager()
    const entry = makeEntry({ message: 'original' })

    manager.registerHook('post-validate', (e) => {
      return { ...e, message: 'modified' } as StoredEntry
    })

    const result = manager.runPostValidate(entry)
    expect(result.message).toBe('modified')
  })

  it('registers and runs post-store hooks', () => {
    const manager = new HookManager()
    const stored: StoredEntry[] = []

    manager.registerHook('post-store', (e) => {
      stored.push(e)
    })

    const entry = makeEntry()
    manager.runPostStore(entry)
    expect(stored).toHaveLength(1)
    expect(stored[0]).toBe(entry)
  })

  it('chains multiple hooks in order', () => {
    const manager = new HookManager()
    const order: number[] = []

    manager.registerHook('pre-validate', (raw) => {
      order.push(1)
      return raw
    })
    manager.registerHook('pre-validate', (raw) => {
      order.push(2)
      return raw
    })

    manager.runPreValidate({})
    expect(order).toEqual([1, 2])
  })
})

describe('createRedactHook', () => {
  it('redacts matching patterns in text', () => {
    const hook = createRedactHook(['password=\\S+', 'secret-\\d+'])

    const entry = makeEntry({ message: 'auth password=abc123 and secret-42 here' })
    const result = hook(entry)
    expect(result.message).toBe('auth [REDACTED] and [REDACTED] here')
  })

  it('returns original entry when no patterns match', () => {
    const hook = createRedactHook(['password=\\S+'])

    const entry = makeEntry({ message: 'no sensitive data here' })
    const result = hook(entry)
    expect(result).toBe(entry) // same reference — no copy
  })

  it('handles entries without message', () => {
    const hook = createRedactHook(['password=\\S+'])

    const entry = makeEntry({ kind: 'data', message: null })
    const result = hook(entry)
    expect(result).toBe(entry)
  })

  it('handles multiple occurrences', () => {
    const hook = createRedactHook(['token=\\S+'])

    const entry = makeEntry({ message: 'token=abc token=def token=ghi' })
    const result = hook(entry)
    expect(result.message).toBe('[REDACTED] [REDACTED] [REDACTED]')
  })
})
