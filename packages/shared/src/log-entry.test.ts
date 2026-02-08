import { describe, expect, it } from 'bun:test';
import { ExceptionData, ImageData, LogBatch, LogEntry } from './log-entry';

// ─── Helpers ─────────────────────────────────────────────────────────

const base = {
  id: 'abc-123',
  timestamp: '2026-02-07T10:30:00.000Z',
  session_id: 'session-1',
  severity: 'info' as const,
};

// ─── Valid LogEntry for each type ────────────────────────────────────

describe('LogEntry', () => {
  it('parses valid text entry', () => {
    const entry = { ...base, type: 'text', text: 'Hello world' };
    expect(LogEntry.parse(entry)).toMatchObject(entry);
  });

  it('parses valid json entry', () => {
    const entry = { ...base, type: 'json', json: { key: 'value' } };
    expect(LogEntry.parse(entry)).toMatchObject(entry);
  });

  it('parses valid html entry', () => {
    const entry = { ...base, type: 'html', html: '<b>bold</b>' };
    expect(LogEntry.parse(entry)).toMatchObject(entry);
  });

  it('parses valid binary entry', () => {
    const entry = { ...base, type: 'binary', binary: 'AQID' };
    expect(LogEntry.parse(entry)).toMatchObject(entry);
  });

  it('parses valid image entry', () => {
    const entry = {
      ...base,
      type: 'image',
      image: { data: 'iVBOR...', mimeType: 'image/png' },
    };
    expect(LogEntry.parse(entry)).toMatchObject(entry);
  });

  it('parses valid state entry', () => {
    const entry = {
      ...base,
      type: 'state',
      state_key: 'counter',
      state_value: 42,
    };
    expect(LogEntry.parse(entry)).toMatchObject(entry);
  });

  it('parses valid group entry', () => {
    const entry = {
      ...base,
      type: 'group',
      group_id: 'grp-1',
      group_action: 'open',
      group_label: 'Request Handling',
      group_collapsed: false,
    };
    expect(LogEntry.parse(entry)).toMatchObject(entry);
  });

  it('parses valid rpc entry', () => {
    const entry = {
      ...base,
      type: 'rpc',
      rpc_id: '550e8400-e29b-41d4-a716-446655440000',
      rpc_direction: 'request',
      rpc_method: 'getUser',
      rpc_args: { userId: 1 },
    };
    expect(LogEntry.parse(entry)).toMatchObject(entry);
  });

  it('parses valid session entry', () => {
    const entry = {
      ...base,
      type: 'session',
      session_action: 'start',
      application: { name: 'my-app', version: '1.0.0' },
    };
    expect(LogEntry.parse(entry)).toMatchObject(entry);
  });

  it('parses valid custom entry', () => {
    const entry = {
      ...base,
      type: 'custom',
      custom_type: 'table',
      custom_data: { columns: ['A'], rows: [['a']] },
    };
    expect(LogEntry.parse(entry)).toMatchObject(entry);
  });

  // ── Required field validation ──

  it('rejects missing id', () => {
    const { id, ...rest } = { ...base, type: 'text', text: 'hi' };
    expect(() => LogEntry.parse(rest)).toThrow();
  });

  it('rejects missing timestamp', () => {
    const { timestamp, ...rest } = { ...base, type: 'text', text: 'hi' };
    expect(() => LogEntry.parse(rest)).toThrow();
  });

  it('rejects missing session_id', () => {
    const { session_id, ...rest } = { ...base, type: 'text', text: 'hi' };
    expect(() => LogEntry.parse(rest)).toThrow();
  });

  it('rejects missing severity', () => {
    const { severity, ...rest } = { ...base, type: 'text', text: 'hi' };
    expect(() => LogEntry.parse(rest)).toThrow();
  });

  it('rejects missing type', () => {
    expect(() => LogEntry.parse(base)).toThrow();
  });

  it('rejects invalid severity', () => {
    expect(() =>
      LogEntry.parse({ ...base, type: 'text', severity: 'fatal' }),
    ).toThrow();
  });

  it('rejects invalid type', () => {
    expect(() =>
      LogEntry.parse({ ...base, type: 'unknown_type' }),
    ).toThrow();
  });

  it('rejects invalid timestamp format', () => {
    expect(() =>
      LogEntry.parse({ ...base, type: 'text', timestamp: 'not-a-date' }),
    ).toThrow();
  });

  // ── Patch 3: replace / upsert fields ──

  it('parses entry with replace=true', () => {
    const entry = {
      ...base,
      type: 'text',
      text: 'updated',
      replace: true,
    };
    const parsed = LogEntry.parse(entry);
    expect(parsed.replace).toBe(true);
  });

  it('parses entry with replace=false (default append)', () => {
    const entry = { ...base, type: 'text', text: 'append' };
    const parsed = LogEntry.parse(entry);
    expect(parsed.replace).toBeUndefined();
  });

  // ── Custom type fields ──

  it('parses custom_type and custom_data', () => {
    const entry = {
      ...base,
      type: 'custom',
      custom_type: 'progress',
      custom_data: { value: 50, max: 100, label: 'Loading' },
    };
    const parsed = LogEntry.parse(entry);
    expect(parsed.custom_type).toBe('progress');
    expect(parsed.custom_data).toEqual({ value: 50, max: 100, label: 'Loading' });
  });

  // ── Optional fields ──

  it('parses entry with all optional fields', () => {
    const entry = {
      ...base,
      type: 'text',
      text: 'full entry',
      application: { name: 'app', version: '1.0.0', environment: 'dev' },
      section: 'events',
      icon: { icon: 'mdi:home', color: '#FF0000', size: 16 },
      tags: { env: 'test', region: 'eu' },
      generated_at: '2026-02-07T10:29:59.000Z',
      sent_at: '2026-02-07T10:30:00.500Z',
      after_id: 'prev-id',
      before_id: 'next-id',
    };
    const parsed = LogEntry.parse(entry);
    expect(parsed.application?.name).toBe('app');
    expect(parsed.tags?.env).toBe('test');
  });
});

// ─── ExceptionData with chained causes ───────────────────────────────

describe('ExceptionData', () => {
  it('parses simple exception', () => {
    const exc = { message: 'something broke' };
    expect(ExceptionData.parse(exc)).toMatchObject(exc);
  });

  it('parses exception with type and stackTrace', () => {
    const exc = {
      type: 'TypeError',
      message: 'Cannot read property x',
      stackTrace: [
        {
          location: { uri: 'src/main.ts', line: 42, column: 10, symbol: 'run' },
          isVendor: false,
          raw: 'at run (src/main.ts:42:10)',
        },
      ],
    };
    expect(ExceptionData.parse(exc)).toMatchObject(exc);
  });

  it('parses chained causes (2 levels)', () => {
    const exc = {
      type: 'HttpError',
      message: 'Request failed',
      cause: {
        type: 'ConnectionError',
        message: 'ECONNREFUSED',
        cause: {
          message: 'DNS resolution failed',
        },
      },
    };
    const parsed = ExceptionData.parse(exc);
    expect(parsed.message).toBe('Request failed');
    expect((parsed as any).cause.message).toBe('ECONNREFUSED');
    expect((parsed as any).cause.cause.message).toBe('DNS resolution failed');
  });

  it('rejects missing message', () => {
    expect(() => ExceptionData.parse({ type: 'Error' })).toThrow();
  });
});

// ─── ImageData refinement ────────────────────────────────────────────

describe('ImageData', () => {
  it('accepts image with data', () => {
    const img = { data: 'base64data', mimeType: 'image/png' };
    expect(ImageData.parse(img)).toMatchObject(img);
  });

  it('accepts image with ref', () => {
    const img = { ref: 'upload-123', mimeType: 'image/jpeg' };
    expect(ImageData.parse(img)).toMatchObject(img);
  });

  it('accepts image with both data and ref', () => {
    const img = { data: 'base64', ref: 'ref-1' };
    expect(ImageData.parse(img)).toMatchObject(img);
  });

  it('rejects image with neither data nor ref', () => {
    expect(() => ImageData.parse({ mimeType: 'image/png' })).toThrow();
  });

  it('rejects empty object', () => {
    expect(() => ImageData.parse({})).toThrow();
  });
});

// ─── LogBatch ────────────────────────────────────────────────────────

describe('LogBatch', () => {
  it('parses valid batch', () => {
    const batch = {
      entries: [{ ...base, type: 'text', text: 'entry 1' }],
    };
    expect(LogBatch.parse(batch)).toMatchObject(batch);
  });

  it('rejects empty batch', () => {
    expect(() => LogBatch.parse({ entries: [] })).toThrow();
  });
});
