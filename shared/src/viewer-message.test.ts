import { describe, expect, it } from 'bun:test';
import { ViewerMessage } from './viewer-message';

describe('ViewerMessage', () => {
  it('parses subscribe message', () => {
    const msg = {
      type: 'subscribe',
      session_ids: ['s-1', 's-2'],
      min_severity: 'warning',
      sections: ['events'],
      text_filter: 'error',
    };
    expect(ViewerMessage.parse(msg)).toMatchObject(msg);
  });

  it('parses unsubscribe message', () => {
    const msg = { type: 'unsubscribe', session_ids: ['s-1'] };
    expect(ViewerMessage.parse(msg)).toMatchObject(msg);
  });

  it('parses history_query message', () => {
    const msg = {
      type: 'history_query',
      query_id: 'q-1',
      from: '2026-02-07T00:00:00.000Z',
      to: '2026-02-07T23:59:59.000Z',
      session_id: 's-1',
      search: 'database',
      limit: 100,
      cursor: 'cur-abc',
    };
    expect(ViewerMessage.parse(msg)).toMatchObject(msg);
  });

  it('parses rpc_request message', () => {
    const msg = {
      type: 'rpc_request',
      rpc_id: '550e8400-e29b-41d4-a716-446655440000',
      target_session_id: 's-1',
      rpc_method: 'getConfig',
      rpc_args: { key: 'theme' },
    };
    expect(ViewerMessage.parse(msg)).toMatchObject(msg);
  });

  it('parses session_list message', () => {
    const msg = { type: 'session_list' };
    expect(ViewerMessage.parse(msg)).toMatchObject(msg);
  });

  it('parses state_query message', () => {
    const msg = { type: 'state_query', state_session_id: 's-1' };
    expect(ViewerMessage.parse(msg)).toMatchObject(msg);
  });

  // ── Rejection tests ──

  it('rejects invalid type', () => {
    expect(() => ViewerMessage.parse({ type: 'invalid' })).toThrow();
  });

  it('rejects missing type', () => {
    expect(() => ViewerMessage.parse({})).toThrow();
  });

  it('rejects invalid min_severity', () => {
    expect(() =>
      ViewerMessage.parse({ type: 'subscribe', min_severity: 'fatal' }),
    ).toThrow();
  });

  it('rejects invalid rpc_id', () => {
    expect(() =>
      ViewerMessage.parse({
        type: 'rpc_request',
        rpc_id: 'not-a-uuid',
        rpc_method: 'test',
      }),
    ).toThrow();
  });

  it('rejects limit out of range', () => {
    expect(() =>
      ViewerMessage.parse({
        type: 'history_query',
        limit: 0,
      }),
    ).toThrow();
    expect(() =>
      ViewerMessage.parse({
        type: 'history_query',
        limit: 10001,
      }),
    ).toThrow();
  });

  it('rejects invalid from timestamp', () => {
    expect(() =>
      ViewerMessage.parse({
        type: 'history_query',
        from: 'not-a-date',
      }),
    ).toThrow();
  });
});
