import { describe, expect, it } from 'bun:test';
import { processPipeline } from './pipeline';

describe('processPipeline', () => {
  it('valid LogEntry passes through', () => {
    const raw = {
      id: '550e8400-e29b-41d4-a716-446655440000',
      timestamp: '2026-01-01T00:00:00.000Z',
      session_id: 'sess-1',
      severity: 'info',
      type: 'text',
      text: 'Hello world',
    };

    const result = processPipeline(raw);
    expect(result.ok).toBe(true);
    if (result.ok) {
      expect(result.entry.id).toBe(raw.id);
      expect(result.entry.text).toBe('Hello world');
      expect(result.isLegacy).toBe(false);
    }
  });

  it('invalid data rejected with error', () => {
    const raw = {
      // missing required fields
      text: 'orphan text',
    };

    const result = processPipeline(raw);
    expect(result.ok).toBe(false);
    if (!result.ok) {
      expect(result.error).toContain('Validation failed');
    }
  });

  it('completely invalid input rejected', () => {
    const result = processPipeline('not an object');
    expect(result.ok).toBe(false);
  });

  it('legacy LogRequest with string payload converted to text entry', () => {
    const raw = {
      severity: 'info',
      payload: 'Legacy log message',
      application: {
        name: 'my-app',
        version: '1.0.0',
        sessionId: 'legacy-sess',
      },
      request: {
        generatedAt: '2026-01-01T00:00:00.000Z',
        sentAt: '2026-01-01T00:00:01.000Z',
      },
    };

    const result = processPipeline(raw);
    expect(result.ok).toBe(true);
    if (result.ok) {
      expect(result.isLegacy).toBe(true);
      expect(result.entry.type).toBe('text');
      expect(result.entry.text).toBe('Legacy log message');
      expect(result.entry.session_id).toBe('legacy-sess');
      expect(result.entry.application?.name).toBe('my-app');
      expect(result.entry.generated_at).toBe('2026-01-01T00:00:00.000Z');
      expect(result.entry.sent_at).toBe('2026-01-01T00:00:01.000Z');
      // Auto-generated fields
      expect(result.entry.id).toBeDefined();
      expect(result.entry.timestamp).toBeDefined();
    }
  });

  it('legacy LogRequest with object payload converted to json entry', () => {
    const raw = {
      severity: 'debug',
      payload: { key: 'value', count: 42 },
      application: { name: 'my-app' },
    };

    const result = processPipeline(raw);
    expect(result.ok).toBe(true);
    if (result.ok) {
      expect(result.isLegacy).toBe(true);
      expect(result.entry.type).toBe('json');
      expect(result.entry.json).toEqual({ key: 'value', count: 42 });
    }
  });

  it('normalization fills generated_at if missing', () => {
    const raw = {
      id: '550e8400-e29b-41d4-a716-446655440001',
      timestamp: '2026-01-01T00:00:00.000Z',
      session_id: 'sess-1',
      severity: 'info',
      type: 'text',
      text: 'test',
    };

    const result = processPipeline(raw);
    expect(result.ok).toBe(true);
    if (result.ok) {
      expect(result.entry.generated_at).toBeDefined();
    }
  });

  it('normalization defaults section to events', () => {
    const raw = {
      id: '550e8400-e29b-41d4-a716-446655440002',
      timestamp: '2026-01-01T00:00:00.000Z',
      session_id: 'sess-1',
      severity: 'info',
      type: 'text',
      text: 'test',
    };

    const result = processPipeline(raw);
    expect(result.ok).toBe(true);
    if (result.ok) {
      expect(result.entry.section).toBe('events');
    }
  });

  it('preserves existing section and generated_at', () => {
    const raw = {
      id: '550e8400-e29b-41d4-a716-446655440003',
      timestamp: '2026-01-01T00:00:00.000Z',
      session_id: 'sess-1',
      severity: 'warning',
      type: 'text',
      text: 'important',
      section: 'network',
      generated_at: '2026-01-01T00:00:00.000Z',
    };

    const result = processPipeline(raw);
    expect(result.ok).toBe(true);
    if (result.ok) {
      expect(result.entry.section).toBe('network');
      expect(result.entry.generated_at).toBe('2026-01-01T00:00:00.000Z');
    }
  });
});
