import { describe, expect, it } from 'bun:test'
import { DataMessage } from './data-message'

// ─── Helpers ─────────────────────────────────────────────────────────

const base = { session_id: 'sess-1', key: 'cpu' }

// ─── Tests ───────────────────────────────────────────────────────────

describe('DataMessage', () => {
  it('parses minimal data message', () => {
    const result = DataMessage.parse(base)
    expect(result.session_id).toBe('sess-1')
    expect(result.key).toBe('cpu')
    expect(result.override).toBe(true)
    expect(result.display).toBe('default')
  })

  it('parses data with value', () => {
    const msg = { ...base, value: 72.5 }
    expect(DataMessage.parse(msg).value).toBe(72.5)
  })

  it('parses data with complex JSON value', () => {
    const msg = { ...base, value: { nested: [1, 2, 3], ok: true } }
    const result = DataMessage.parse(msg)
    expect(result.value).toEqual({ nested: [1, 2, 3], ok: true })
  })

  it('parses data with display=static', () => {
    const msg = { ...base, display: 'static' }
    expect(DataMessage.parse(msg).display).toBe('static')
  })

  it('parses data with display=shelf', () => {
    const msg = { ...base, display: 'shelf' }
    expect(DataMessage.parse(msg).display).toBe('shelf')
  })

  it('parses data with override=false (append mode)', () => {
    const msg = { ...base, override: false }
    expect(DataMessage.parse(msg).override).toBe(false)
  })

  it('parses data with widget config', () => {
    const msg = { ...base, widget: { type: 'chart', chart_type: 'sparkline' } }
    const result = DataMessage.parse(msg)
    expect(result.widget?.type).toBe('chart')
  })

  it('parses data with label and icon', () => {
    const msg = { ...base, label: 'CPU Usage', icon: { icon: 'mdi:cpu' } }
    const result = DataMessage.parse(msg)
    expect(result.label).toBe('CPU Usage')
    expect(result.icon?.icon).toBe('mdi:cpu')
  })

  it('rejects missing session_id', () => {
    expect(() => DataMessage.parse({ key: 'cpu' })).toThrow()
  })

  it('rejects missing key', () => {
    expect(() => DataMessage.parse({ session_id: 'sess-1' })).toThrow()
  })

  it('rejects key exceeding max length', () => {
    expect(() =>
      DataMessage.parse({ session_id: 'sess-1', key: 'x'.repeat(257) }),
    ).toThrow()
  })

  it('rejects invalid display value', () => {
    expect(() =>
      DataMessage.parse({ ...base, display: 'sidebar' }),
    ).toThrow()
  })

  it('rejects label exceeding max length', () => {
    expect(() =>
      DataMessage.parse({ ...base, label: 'x'.repeat(257) }),
    ).toThrow()
  })

  it('defaults override to true', () => {
    expect(DataMessage.parse(base).override).toBe(true)
  })

  it('defaults display to default', () => {
    expect(DataMessage.parse(base).display).toBe('default')
  })
})
