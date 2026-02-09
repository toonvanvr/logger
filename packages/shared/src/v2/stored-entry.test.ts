import { describe, expect, it } from 'bun:test'
import { StoredEntry } from './stored-entry'

// ─── Helpers ─────────────────────────────────────────────────────────

const now = '2026-02-09T10:00:00.000Z'

const baseEvent = {
  id: 'evt-1',
  timestamp: now,
  session_id: 'sess-1',
  kind: 'event' as const,
  received_at: now,
}

const baseData = {
  id: 'dat-1',
  timestamp: now,
  session_id: 'sess-1',
  kind: 'data' as const,
  received_at: now,
}

const baseSession = {
  id: 'ses-1',
  timestamp: now,
  session_id: 'sess-1',
  kind: 'session' as const,
  received_at: now,
}

// ─── Tests ───────────────────────────────────────────────────────────

describe('StoredEntry', () => {
  it('parses minimal event entry with defaults', () => {
    const result = StoredEntry.parse(baseEvent)
    expect(result.kind).toBe('event')
    expect(result.severity).toBe('info')
    expect(result.message).toBeNull()
    expect(result.replace).toBe(false)
    expect(result.key).toBeNull()
    expect(result.session_action).toBeNull()
  })

  it('parses event entry with all event fields', () => {
    const entry = {
      ...baseEvent,
      severity: 'error',
      message: 'Something failed',
      tag: 'http',
      parent_id: 'parent-1',
      replace: true,
      icon: { icon: 'mdi:alert' },
      labels: { env: 'prod' },
      generated_at: now,
      sent_at: now,
      widget: { type: 'json', data: { key: 'val' } },
    }
    const result = StoredEntry.parse(entry)
    expect(result.message).toBe('Something failed')
    expect(result.tag).toBe('http')
    expect(result.icon?.icon).toBe('mdi:alert')
  })

  it('parses data entry with data fields', () => {
    const entry = {
      ...baseData,
      key: 'cpu',
      value: 72.5,
      override: false,
      display: 'shelf',
    }
    const result = StoredEntry.parse(entry)
    expect(result.kind).toBe('data')
    expect(result.key).toBe('cpu')
    expect(result.value).toBe(72.5)
    expect(result.override).toBe(false)
    expect(result.display).toBe('shelf')
  })

  it('parses session entry with session fields', () => {
    const entry = {
      ...baseSession,
      session_action: 'start',
      application: { name: 'my-app', version: '1.0.0' },
      metadata: { region: 'us-east' },
    }
    const result = StoredEntry.parse(entry)
    expect(result.kind).toBe('session')
    expect(result.session_action).toBe('start')
    expect(result.application?.name).toBe('my-app')
  })

  it('defaults nullable fields to null', () => {
    const result = StoredEntry.parse(baseEvent)
    expect(result.tag).toBeNull()
    expect(result.exception).toBeNull()
    expect(result.parent_id).toBeNull()
    expect(result.group_id).toBeNull()
    expect(result.prev_id).toBeNull()
    expect(result.next_id).toBeNull()
    expect(result.widget).toBeNull()
    expect(result.icon).toBeNull()
    expect(result.labels).toBeNull()
    expect(result.generated_at).toBeNull()
    expect(result.sent_at).toBeNull()
    expect(result.key).toBeNull()
    expect(result.session_action).toBeNull()
    expect(result.application).toBeNull()
    expect(result.metadata).toBeNull()
  })

  it('defaults severity to info', () => {
    expect(StoredEntry.parse(baseEvent).severity).toBe('info')
  })

  it('defaults override to true', () => {
    expect(StoredEntry.parse(baseData).override).toBe(true)
  })

  it('defaults display to default', () => {
    expect(StoredEntry.parse(baseData).display).toBe('default')
  })

  it('rejects missing required fields', () => {
    expect(() => StoredEntry.parse({ id: 'x' })).toThrow()
  })

  it('rejects invalid kind', () => {
    expect(() => StoredEntry.parse({ ...baseEvent, kind: 'log' })).toThrow()
  })

  it('rejects invalid timestamp format', () => {
    expect(() =>
      StoredEntry.parse({ ...baseEvent, timestamp: 'not-a-date' }),
    ).toThrow()
  })

  it('rejects invalid received_at format', () => {
    expect(() =>
      StoredEntry.parse({ ...baseEvent, received_at: 'bad' }),
    ).toThrow()
  })
})
