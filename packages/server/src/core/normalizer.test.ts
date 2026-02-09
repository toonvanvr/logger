import { describe, expect, it } from 'bun:test'
import { normalizeData, normalizeEvent, normalizeSession, normalizeV1 } from './normalizer'

// ─── Tests ───────────────────────────────────────────────────────────

describe('normalizeSession', () => {
  it('normalizes a start session message', () => {
    const entry = normalizeSession({
      session_id: '550e8400-e29b-41d4-a716-446655440000',
      action: 'start',
      application: { name: 'my-app', version: '1.0' },
    })

    expect(entry.kind).toBe('session')
    expect(entry.session_id).toBe('550e8400-e29b-41d4-a716-446655440000')
    expect(entry.session_action).toBe('start')
    expect(entry.application?.name).toBe('my-app')
    expect(entry.severity).toBe('info')
    expect(entry.id).toBeTruthy()
    expect(entry.timestamp).toBeTruthy()
    expect(entry.received_at).toBeTruthy()
    expect(entry.message).toBeNull()
    expect(entry.key).toBeNull()
  })

  it('normalizes an end session message', () => {
    const entry = normalizeSession({
      session_id: '550e8400-e29b-41d4-a716-446655440000',
      action: 'end',
    })

    expect(entry.session_action).toBe('end')
    expect(entry.application).toBeNull()
  })

  it('preserves metadata if provided', () => {
    const entry = normalizeSession({
      session_id: '550e8400-e29b-41d4-a716-446655440000',
      action: 'start',
      application: { name: 'test' },
      metadata: { host: 'localhost' },
    })

    expect(entry.metadata).toEqual({ host: 'localhost' })
  })
})

describe('normalizeEvent', () => {
  it('normalizes a simple event message', () => {
    const entry = normalizeEvent({
      session_id: 'sess-1',
      message: 'hello v2',
      severity: 'info',
    })

    expect(entry.kind).toBe('event')
    expect(entry.message).toBe('hello v2')
    expect(entry.severity).toBe('info')
    expect(entry.id).toBeTruthy()
    expect(entry.session_id).toBe('sess-1')
    expect(entry.key).toBeNull()
    expect(entry.session_action).toBeNull()
  })

  it('preserves client-provided id', () => {
    const entry = normalizeEvent({
      session_id: 'sess-1',
      id: 'my-custom-id',
      message: 'test',
    })

    expect(entry.id).toBe('my-custom-id')
  })

  it('auto-generates id when not provided', () => {
    const entry = normalizeEvent({ session_id: 'sess-1' })
    expect(entry.id).toBeTruthy()
    expect(entry.id.length).toBeGreaterThan(0)
  })

  it('normalizes event with widget', () => {
    const entry = normalizeEvent({
      session_id: 'sess-1',
      message: 'progress update',
      widget: { type: 'progress', value: 50, max: 100 },
      replace: true,
    })

    expect(entry.widget).toEqual({ type: 'progress', value: 50, max: 100 })
    expect(entry.replace).toBe(true)
  })

  it('normalizes all optional fields', () => {
    const entry = normalizeEvent({
      session_id: 'sess-1',
      tag: 'http',
      parent_id: 'parent-1',
      icon: { icon: 'check', color: '#00ff00' },
      labels: { env: 'dev' },
      generated_at: '2026-01-01T00:00:00.000Z',
      sent_at: '2026-01-01T00:00:00.001Z',
    })

    expect(entry.tag).toBe('http')
    expect(entry.parent_id).toBe('parent-1')
    expect(entry.icon).toEqual({ icon: 'check', color: '#00ff00' })
    expect(entry.labels).toEqual({ env: 'dev' })
    expect(entry.generated_at).toBe('2026-01-01T00:00:00.000Z')
    expect(entry.sent_at).toBe('2026-01-01T00:00:00.001Z')
  })
})

describe('normalizeData', () => {
  it('normalizes a simple data message', () => {
    const entry = normalizeData({
      session_id: 'sess-1',
      key: 'cpu',
      value: 72.5,
    })

    expect(entry.kind).toBe('data')
    expect(entry.key).toBe('cpu')
    expect(entry.value).toBe(72.5)
    expect(entry.override).toBe(true)
    expect(entry.display).toBe('default')
    expect(entry.message).toBeNull()
    expect(entry.session_action).toBeNull()
  })

  it('normalizes data with display and widget config', () => {
    const entry = normalizeData({
      session_id: 'sess-1',
      key: 'cpu',
      value: 72.5,
      override: false,
      display: 'shelf',
      widget: { type: 'chart', chart_type: 'sparkline' },
    })

    expect(entry.display).toBe('shelf')
    expect(entry.override).toBe(false)
    expect(entry.widget).toEqual({ type: 'chart', chart_type: 'sparkline' })
  })
})

describe('normalizeV1', () => {
  it('normalizes a v1 text entry', () => {
    const entry = normalizeV1({
      id: 'v1-id',
      timestamp: '2026-01-01T00:00:00.000Z',
      session_id: 'sess-1',
      severity: 'warning',
      type: 'text',
      text: 'hello from v1',
      section: 'network',
    } as any)

    expect(entry.kind).toBe('event')
    expect(entry.id).toBe('v1-id')
    expect(entry.message).toBe('hello from v1')
    expect(entry.tag).toBe('network')
    expect(entry.severity).toBe('warning')
    expect(entry.timestamp).toBe('2026-01-01T00:00:00.000Z')
  })

  it('normalizes a v1 session entry', () => {
    const entry = normalizeV1({
      id: 'v1-sess',
      timestamp: '2026-01-01T00:00:00.000Z',
      session_id: 'sess-1',
      severity: 'info',
      type: 'session',
      session_action: 'start',
      application: { name: 'test-app' },
    } as any)

    expect(entry.kind).toBe('session')
    expect(entry.session_action).toBe('start')
    expect(entry.application?.name).toBe('test-app')
  })

  it('maps v1 tags to labels', () => {
    const entry = normalizeV1({
      id: 'v1-tags',
      timestamp: '2026-01-01T00:00:00.000Z',
      session_id: 'sess-1',
      severity: 'info',
      type: 'text',
      tags: { env: 'prod', region: 'us-east' },
    } as any)

    expect(entry.labels).toEqual({ env: 'prod', region: 'us-east' })
  })
})
