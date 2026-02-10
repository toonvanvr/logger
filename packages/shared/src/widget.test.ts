import { describe, expect, it } from 'bun:test'
import { WidgetPayload } from './widget'

// ─── Tests ───────────────────────────────────────────────────────────

describe('WidgetPayload', () => {
  // ── Content Widgets ──

  describe('json', () => {
    it('parses valid json widget', () => {
      const w = { type: 'json', data: { key: 'value' } }
      expect(WidgetPayload.parse(w)).toMatchObject(w)
    })

    it('accepts null data', () => {
      expect(WidgetPayload.parse({ type: 'json', data: null })).toMatchObject({ type: 'json' })
    })
  })

  describe('html', () => {
    it('parses valid html widget', () => {
      const w = { type: 'html', content: '<b>bold</b>' }
      expect(WidgetPayload.parse(w)).toMatchObject(w)
    })

    it('rejects missing content', () => {
      expect(() => WidgetPayload.parse({ type: 'html' })).toThrow()
    })
  })

  describe('binary', () => {
    it('parses valid binary widget', () => {
      const w = { type: 'binary', data: 'AQID', encoding: 'base64' }
      expect(WidgetPayload.parse(w)).toMatchObject(w)
    })

    it('rejects missing encoding', () => {
      expect(() => WidgetPayload.parse({ type: 'binary', data: 'AQID' })).toThrow()
    })
  })

  describe('image', () => {
    it('parses image with data', () => {
      const w = { type: 'image', data: 'iVBOR...', mime_type: 'image/png' }
      expect(WidgetPayload.parse(w)).toMatchObject(w)
    })

    it('parses image with ref', () => {
      const w = { type: 'image', ref: 'upload-123' }
      expect(WidgetPayload.parse(w)).toMatchObject(w)
    })
  })

  // ── Rich Widgets ──

  describe('table', () => {
    it('parses valid table', () => {
      const w = {
        type: 'table',
        columns: ['Name', 'Age'],
        rows: [['Alice', 30], ['Bob', 25]],
        sortable: true,
      }
      expect(WidgetPayload.parse(w)).toMatchObject(w)
    })

    it('rejects empty columns', () => {
      expect(() =>
        WidgetPayload.parse({ type: 'table', columns: [], rows: [] }),
      ).toThrow()
    })
  })

  describe('progress', () => {
    it('parses valid progress', () => {
      const w = { type: 'progress', value: 73, max: 100, color: '#A8CC7E', style: 'bar' }
      expect(WidgetPayload.parse(w)).toMatchObject(w)
    })

    it('parses minimal progress', () => {
      expect(WidgetPayload.parse({ type: 'progress', value: 50 })).toMatchObject({ type: 'progress' })
    })

    it('rejects progress without value', () => {
      expect(() => WidgetPayload.parse({ type: 'progress' })).toThrow()
    })
  })

  describe('kv', () => {
    it('parses valid kv', () => {
      const w = { type: 'kv', entries: [{ key: 'status', value: 'ok' }] }
      expect(WidgetPayload.parse(w)).toMatchObject(w)
    })

    it('rejects empty entries', () => {
      expect(() => WidgetPayload.parse({ type: 'kv', entries: [] })).toThrow()
    })
  })

  describe('chart', () => {
    it('parses chart with values', () => {
      const w = { type: 'chart', chart_type: 'sparkline', values: [1, 2, 3] }
      expect(WidgetPayload.parse(w)).toMatchObject(w)
    })

    it('parses chart without values (data push mode)', () => {
      const w = { type: 'chart', chart_type: 'bar' }
      expect(WidgetPayload.parse(w)).toMatchObject(w)
    })

    it('rejects chart without chart_type', () => {
      expect(() => WidgetPayload.parse({ type: 'chart' })).toThrow()
    })

    it('rejects invalid chart_type', () => {
      expect(() =>
        WidgetPayload.parse({ type: 'chart', chart_type: 'pie' }),
      ).toThrow()
    })
  })

  describe('diff', () => {
    it('parses valid diff', () => {
      const w = { type: 'diff', before: 'old', after: 'new', language: 'json' }
      expect(WidgetPayload.parse(w)).toMatchObject(w)
    })

    it('rejects missing before', () => {
      expect(() => WidgetPayload.parse({ type: 'diff', after: 'new' })).toThrow()
    })
  })

  describe('tree', () => {
    it('parses valid tree', () => {
      const w = {
        type: 'tree',
        root: { label: 'root', children: [{ label: 'child' }] },
      }
      expect(WidgetPayload.parse(w)).toMatchObject(w)
    })
  })

  describe('timeline', () => {
    it('parses valid timeline', () => {
      const w = {
        type: 'timeline',
        events: [{ label: 'Start', time: '2026-02-09T10:00:00Z' }],
      }
      expect(WidgetPayload.parse(w)).toMatchObject(w)
    })

    it('rejects empty events', () => {
      expect(() => WidgetPayload.parse({ type: 'timeline', events: [] })).toThrow()
    })
  })

  describe('http_request', () => {
    it('parses valid http_request', () => {
      const w = { type: 'http_request', method: 'GET', url: '/api/health' }
      expect(WidgetPayload.parse(w)).toMatchObject(w)
    })

    it('rejects missing method', () => {
      expect(() => WidgetPayload.parse({ type: 'http_request', url: '/' })).toThrow()
    })
  })

  // ── Passthrough ──

  it('passes through extra fields', () => {
    const w = { type: 'json', data: {}, extra_field: 'kept' }
    const result = WidgetPayload.parse(w)
    expect((result as Record<string, unknown>).extra_field).toBe('kept')
  })

  // ── Invalid ──

  it('rejects unknown widget type', () => {
    expect(() => WidgetPayload.parse({ type: 'unknown_widget' })).toThrow()
  })
})
