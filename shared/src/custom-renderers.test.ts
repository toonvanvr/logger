import { describe, expect, it } from 'bun:test';
import { ChartRendererData, CustomRendererData } from './custom-renderers';

describe('CustomRendererData', () => {
  // ── Table ──

  describe('table', () => {
    it('parses valid table', () => {
      const data = {
        custom_type: 'table',
        custom_data: {
          columns: ['Name', 'Age'],
          rows: [
            ['Alice', 30],
            ['Bob', 25],
          ],
          sortable: true,
          caption: 'Users',
        },
      };
      expect(CustomRendererData.parse(data)).toMatchObject(data);
    });

    it('rejects table with empty columns', () => {
      expect(() =>
        CustomRendererData.parse({
          custom_type: 'table',
          custom_data: { columns: [], rows: [] },
        }),
      ).toThrow();
    });

    it('rejects table with missing columns', () => {
      expect(() =>
        CustomRendererData.parse({
          custom_type: 'table',
          custom_data: { rows: [['a']] },
        }),
      ).toThrow();
    });
  });

  // ── Progress ──

  describe('progress', () => {
    it('parses valid progress', () => {
      const data = {
        custom_type: 'progress',
        custom_data: {
          value: 73,
          max: 100,
          label: 'Migrating',
          color: '#A8CC7E',
          style: 'bar',
        },
      };
      expect(CustomRendererData.parse(data)).toMatchObject(data);
    });

    it('parses minimal progress (value only)', () => {
      const data = {
        custom_type: 'progress',
        custom_data: { value: 50 },
      };
      expect(CustomRendererData.parse(data)).toMatchObject(data);
    });

    it('rejects progress without value', () => {
      expect(() =>
        CustomRendererData.parse({
          custom_type: 'progress',
          custom_data: { label: 'no value' },
        }),
      ).toThrow();
    });

    it('rejects progress with invalid color', () => {
      expect(() =>
        CustomRendererData.parse({
          custom_type: 'progress',
          custom_data: { value: 50, color: 'red' },
        }),
      ).toThrow();
    });
  });

  // ── KV ──

  describe('kv', () => {
    it('parses valid kv', () => {
      const data = {
        custom_type: 'kv',
        custom_data: {
          entries: [
            { key: 'Status', value: 'Running', icon: 'mdi:check', color: '#A8CC7E' },
            { key: 'Uptime', value: 3600 },
          ],
          layout: 'inline',
        },
      };
      expect(CustomRendererData.parse(data)).toMatchObject(data);
    });

    it('rejects kv with empty entries', () => {
      expect(() =>
        CustomRendererData.parse({
          custom_type: 'kv',
          custom_data: { entries: [] },
        }),
      ).toThrow();
    });

    it('rejects kv entry with invalid value type', () => {
      expect(() =>
        CustomRendererData.parse({
          custom_type: 'kv',
          custom_data: {
            entries: [{ key: 'k', value: { nested: true } }],
          },
        }),
      ).toThrow();
    });
  });

  // ── Chart ──

  describe('chart', () => {
    it('parses valid sparkline chart', () => {
      const data = {
        custom_type: 'chart',
        custom_data: {
          type: 'sparkline',
          values: [12, 15, 8, 22],
          color: '#7EB8D0',
          height: 48,
          title: 'Req/sec',
        },
      };
      expect(CustomRendererData.parse(data)).toMatchObject(data);
    });

    it('parses valid bar chart', () => {
      const data = {
        custom_type: 'chart',
        custom_data: {
          type: 'bar',
          values: [10, 20, 30],
          labels: ['A', 'B', 'C'],
        },
      };
      expect(CustomRendererData.parse(data)).toMatchObject(data);
    });

    it('rejects chart with less than 2 values', () => {
      expect(() =>
        CustomRendererData.parse({
          custom_type: 'chart',
          custom_data: { type: 'sparkline', values: [1] },
        }),
      ).toThrow();
    });

    it('accepts dense_bar chart type', () => {
      const result = ChartRendererData.safeParse({
        custom_type: 'chart',
        custom_data: {
          type: 'dense_bar',
          values: [12, 45, 23, 67, 34],
          title: 'Req/10s',
        },
      });
      expect(result.success).toBe(true);
    });

    it('rejects chart with invalid type', () => {
      expect(() =>
        CustomRendererData.parse({
          custom_type: 'chart',
          custom_data: { type: 'pie', values: [1, 2] },
        }),
      ).toThrow();
    });

    it('rejects chart with height out of range', () => {
      expect(() =>
        CustomRendererData.parse({
          custom_type: 'chart',
          custom_data: { type: 'bar', values: [1, 2], height: 10 },
        }),
      ).toThrow();
    });
  });

  // ── Diff ──

  describe('diff', () => {
    it('parses valid diff', () => {
      const data = {
        custom_type: 'diff',
        custom_data: {
          before: '{"role": "user"}',
          after: '{"role": "admin"}',
          language: 'json',
          context_lines: 3,
        },
      };
      expect(CustomRendererData.parse(data)).toMatchObject(data);
    });

    it('parses minimal diff', () => {
      const data = {
        custom_type: 'diff',
        custom_data: { before: 'old', after: 'new' },
      };
      expect(CustomRendererData.parse(data)).toMatchObject(data);
    });

    it('rejects diff without before', () => {
      expect(() =>
        CustomRendererData.parse({
          custom_type: 'diff',
          custom_data: { after: 'new' },
        }),
      ).toThrow();
    });

    it('rejects diff with invalid language', () => {
      expect(() =>
        CustomRendererData.parse({
          custom_type: 'diff',
          custom_data: { before: 'a', after: 'b', language: 'python' },
        }),
      ).toThrow();
    });
  });

  // ── Tree ──

  describe('tree', () => {
    it('parses valid tree', () => {
      const data = {
        custom_type: 'tree',
        custom_data: {
          root: {
            label: 'App',
            icon: 'mdi:folder',
            children: [
              { label: 'main.ts', icon: 'mdi:language-typescript', meta: '2.1KB' },
              {
                label: 'src',
                children: [{ label: 'index.ts' }],
              },
            ],
          },
          default_expanded_depth: 2,
        },
      };
      expect(CustomRendererData.parse(data)).toMatchObject(data);
    });

    it('parses minimal tree (leaf only)', () => {
      const data = {
        custom_type: 'tree',
        custom_data: {
          root: { label: 'Root' },
        },
      };
      expect(CustomRendererData.parse(data)).toMatchObject(data);
    });

    it('rejects tree without root', () => {
      expect(() =>
        CustomRendererData.parse({
          custom_type: 'tree',
          custom_data: {},
        }),
      ).toThrow();
    });

    it('rejects tree with invalid color on node', () => {
      expect(() =>
        CustomRendererData.parse({
          custom_type: 'tree',
          custom_data: {
            root: { label: 'bad', color: 'red' },
          },
        }),
      ).toThrow();
    });
  });

  // ── Timeline ──

  describe('timeline', () => {
    it('parses valid timeline', () => {
      const data = {
        custom_type: 'timeline',
        custom_data: {
          events: [
            {
              label: 'Request',
              time: '2026-02-07T10:30:00.000Z',
              color: '#7EB8D0',
            },
            {
              label: 'DB query',
              time: '2026-02-07T10:30:00.017Z',
              duration_ms: 23,
              meta: 'SELECT *',
            },
          ],
          show_duration: true,
          total_label: 'Total: 42ms',
        },
      };
      expect(CustomRendererData.parse(data)).toMatchObject(data);
    });

    it('rejects timeline with empty events', () => {
      expect(() =>
        CustomRendererData.parse({
          custom_type: 'timeline',
          custom_data: { events: [] },
        }),
      ).toThrow();
    });

    it('rejects timeline event with invalid time', () => {
      expect(() =>
        CustomRendererData.parse({
          custom_type: 'timeline',
          custom_data: {
            events: [{ label: 'x', time: 'not-a-date' }],
          },
        }),
      ).toThrow();
    });
  });

  // ── Unknown custom_type ──

  it('rejects unknown custom_type', () => {
    expect(() =>
      CustomRendererData.parse({
        custom_type: 'unknown_renderer',
        custom_data: {},
      }),
    ).toThrow();
  });

  // ── Missing custom_type ──

  it('rejects missing custom_type', () => {
    expect(() =>
      CustomRendererData.parse({ custom_data: {} }),
    ).toThrow();
  });
});
