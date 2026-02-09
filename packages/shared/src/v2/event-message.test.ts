import { describe, expect, it } from 'bun:test'
import { EventMessage } from './event-message'

// ─── Helpers ─────────────────────────────────────────────────────────

const base = { session_id: 'sess-1' }

// ─── Tests ───────────────────────────────────────────────────────────

describe('EventMessage', () => {
  it('parses minimal event (session_id only)', () => {
    const result = EventMessage.parse(base)
    expect(result.session_id).toBe('sess-1')
    expect(result.severity).toBe('info')
    expect(result.replace).toBe(false)
  })

  it('parses event with message', () => {
    const msg = { ...base, message: 'Hello world' }
    expect(EventMessage.parse(msg).message).toBe('Hello world')
  })

  it('parses event with all severity levels', () => {
    for (const sev of ['debug', 'info', 'warning', 'error', 'critical']) {
      expect(EventMessage.parse({ ...base, severity: sev }).severity).toBe(sev)
    }
  })

  it('parses event with widget', () => {
    const msg = { ...base, widget: { type: 'json', data: { key: 'val' } } }
    const result = EventMessage.parse(msg)
    expect(result.widget).toMatchObject({ type: 'json' })
  })

  it('parses event with exception', () => {
    const msg = {
      ...base,
      exception: { type: 'TypeError', message: 'null ref' },
    }
    const result = EventMessage.parse(msg)
    expect(result.exception?.type).toBe('TypeError')
  })

  it('parses event with nested exception (inner)', () => {
    const msg = {
      ...base,
      exception: {
        type: 'AppError',
        message: 'outer',
        inner: { type: 'IOError', message: 'inner' },
      },
    }
    const result = EventMessage.parse(msg)
    expect(result.exception?.inner).toBeDefined()
  })

  it('parses event with labels', () => {
    const msg = { ...base, labels: { env: 'prod', region: 'us' } }
    expect(EventMessage.parse(msg).labels).toEqual({ env: 'prod', region: 'us' })
  })

  it('parses event with icon', () => {
    const msg = { ...base, icon: { icon: 'mdi:home', color: '#FF0000', size: 16 } }
    expect(EventMessage.parse(msg).icon?.icon).toBe('mdi:home')
  })

  it('parses event with timestamps', () => {
    const msg = {
      ...base,
      generated_at: '2026-02-09T10:00:00.000Z',
      sent_at: '2026-02-09T10:00:01.000Z',
    }
    expect(EventMessage.parse(msg).generated_at).toBe('2026-02-09T10:00:00.000Z')
  })

  it('allows parent_id without group_id', () => {
    const msg = { ...base, parent_id: 'parent-1' }
    expect(EventMessage.parse(msg).parent_id).toBe('parent-1')
  })

  it('allows group_id without parent_id', () => {
    const msg = { ...base, group_id: 'group-1' }
    expect(EventMessage.parse(msg).group_id).toBe('group-1')
  })

  it('rejects parent_id and group_id together (refinement)', () => {
    expect(() =>
      EventMessage.parse({ ...base, parent_id: 'p1', group_id: 'g1' }),
    ).toThrow()
  })

  it('rejects missing session_id', () => {
    expect(() => EventMessage.parse({ message: 'no session' })).toThrow()
  })

  it('rejects invalid severity', () => {
    expect(() => EventMessage.parse({ ...base, severity: 'fatal' })).toThrow()
  })

  it('rejects invalid datetime format', () => {
    expect(() =>
      EventMessage.parse({ ...base, generated_at: 'not-a-date' }),
    ).toThrow()
  })

  it('rejects tag exceeding max length', () => {
    expect(() =>
      EventMessage.parse({ ...base, tag: 'x'.repeat(129) }),
    ).toThrow()
  })

  it('defaults severity to info', () => {
    expect(EventMessage.parse(base).severity).toBe('info')
  })

  it('defaults replace to false', () => {
    expect(EventMessage.parse(base).replace).toBe(false)
  })
})
