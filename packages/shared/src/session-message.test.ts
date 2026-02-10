import { describe, expect, it } from 'bun:test'
import { SessionMessage } from './session-message'

// ─── Helpers ─────────────────────────────────────────────────────────

const uuid = '550e8400-e29b-41d4-a716-446655440000'

const validStart = {
  session_id: uuid,
  action: 'start' as const,
  application: { name: 'my-app', version: '1.0.0', environment: 'dev' },
}

// ─── Tests ───────────────────────────────────────────────────────────

describe('SessionMessage', () => {
  it('parses valid start message', () => {
    const result = SessionMessage.parse(validStart)
    expect(result.session_id).toBe(uuid)
    expect(result.action).toBe('start')
    expect(result.application?.name).toBe('my-app')
  })

  it('parses valid end message', () => {
    const msg = { session_id: uuid, action: 'end' }
    expect(SessionMessage.parse(msg)).toMatchObject(msg)
  })

  it('parses valid heartbeat message', () => {
    const msg = { session_id: uuid, action: 'heartbeat' }
    expect(SessionMessage.parse(msg)).toMatchObject(msg)
  })

  it('accepts optional metadata', () => {
    const msg = { ...validStart, metadata: { region: 'us-east', debug: true } }
    const result = SessionMessage.parse(msg)
    expect(result.metadata).toEqual({ region: 'us-east', debug: true })
  })

  it('rejects start without application (refinement)', () => {
    expect(() => SessionMessage.parse({ session_id: uuid, action: 'start' })).toThrow()
  })

  it('rejects invalid session_id (not UUID)', () => {
    expect(() => SessionMessage.parse({ ...validStart, session_id: 'not-a-uuid' })).toThrow()
  })

  it('rejects missing session_id', () => {
    expect(() => SessionMessage.parse({ action: 'start', application: { name: 'x' } })).toThrow()
  })

  it('rejects invalid action', () => {
    expect(() => SessionMessage.parse({ session_id: uuid, action: 'pause' })).toThrow()
  })

  it('rejects application name exceeding max length', () => {
    expect(() =>
      SessionMessage.parse({
        session_id: uuid,
        action: 'start',
        application: { name: 'x'.repeat(129) },
      }),
    ).toThrow()
  })

  it('rejects application with empty name', () => {
    expect(() =>
      SessionMessage.parse({
        session_id: uuid,
        action: 'start',
        application: { name: '' },
      }),
    ).toThrow()
  })

  it('allows end without application', () => {
    const msg = { session_id: uuid, action: 'end' }
    expect(SessionMessage.parse(msg)).toMatchObject(msg)
  })

  it('allows heartbeat without application', () => {
    const msg = { session_id: uuid, action: 'heartbeat' }
    expect(SessionMessage.parse(msg)).toMatchObject(msg)
  })
})
