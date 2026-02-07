import type { LogEntry } from '@logger/shared';
import { describe, expect, it } from 'bun:test';
import { HookManager, createRedactHook } from './hooks';

function makeEntry(overrides: Partial<LogEntry> = {}): LogEntry {
  return {
    id: '550e8400-e29b-41d4-a716-446655440000',
    timestamp: new Date().toISOString(),
    session_id: 'sess-1',
    severity: 'info',
    type: 'text',
    text: 'hello world',
    ...overrides,
  } as LogEntry;
}

describe('HookManager', () => {
  it('registers and runs pre-validate hooks', () => {
    const manager = new HookManager();
    const calls: unknown[] = [];

    manager.registerHook('pre-validate', (raw) => {
      calls.push(raw);
      return raw;
    });

    const input = { foo: 'bar' };
    const result = manager.runPreValidate(input);
    expect(calls).toHaveLength(1);
    expect(calls[0]).toBe(input);
    expect(result).toBe(input);
  });

  it('registers and runs post-validate hooks', () => {
    const manager = new HookManager();
    const entry = makeEntry({ text: 'original' });

    manager.registerHook('post-validate', (e) => {
      return { ...e, text: 'modified' } as LogEntry;
    });

    const result = manager.runPostValidate(entry);
    expect(result.text).toBe('modified');
  });

  it('registers and runs post-store hooks', () => {
    const manager = new HookManager();
    const stored: LogEntry[] = [];

    manager.registerHook('post-store', (e) => {
      stored.push(e);
    });

    const entry = makeEntry();
    manager.runPostStore(entry);
    expect(stored).toHaveLength(1);
    expect(stored[0]).toBe(entry);
  });

  it('chains multiple hooks in order', () => {
    const manager = new HookManager();
    const order: number[] = [];

    manager.registerHook('pre-validate', (raw) => {
      order.push(1);
      return raw;
    });
    manager.registerHook('pre-validate', (raw) => {
      order.push(2);
      return raw;
    });

    manager.runPreValidate({});
    expect(order).toEqual([1, 2]);
  });
});

describe('createRedactHook', () => {
  it('redacts matching patterns in text', () => {
    const hook = createRedactHook(['password=\\S+', 'secret-\\d+']);

    const entry = makeEntry({ text: 'auth password=abc123 and secret-42 here' });
    const result = hook(entry);
    expect(result.text).toBe('auth [REDACTED] and [REDACTED] here');
  });

  it('returns original entry when no patterns match', () => {
    const hook = createRedactHook(['password=\\S+']);

    const entry = makeEntry({ text: 'no sensitive data here' });
    const result = hook(entry);
    expect(result).toBe(entry); // same reference — no copy
  });

  it('handles entries without text', () => {
    const hook = createRedactHook(['password=\\S+']);

    const entry = makeEntry({ type: 'json', text: undefined });
    const result = hook(entry);
    expect(result).toBe(entry);
  });

  it('handles multiple occurrences', () => {
    const hook = createRedactHook(['token=\\S+']);

    const entry = makeEntry({ text: 'token=abc token=def token=ghi' });
    const result = hook(entry);
    expect(result.text).toBe('[REDACTED] [REDACTED] [REDACTED]');
  });
});
