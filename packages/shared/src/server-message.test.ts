import { describe, expect, it } from 'bun:test';
import { ServerMessage } from './server-message';

const ts = '2026-02-07T10:30:00.000Z';

describe('ServerMessage', () => {
  it('parses ack message', () => {
    const msg = { type: 'ack', ack_ids: ['id-1', 'id-2'] };
    expect(ServerMessage.parse(msg)).toMatchObject(msg);
  });

  it('parses error message', () => {
    const msg = {
      type: 'error',
      error_code: 'VALIDATION_FAILED',
      error_message: 'Invalid severity',
      error_entry_id: 'entry-1',
    };
    expect(ServerMessage.parse(msg)).toMatchObject(msg);
  });

  it('parses log message', () => {
    const msg = {
      type: 'log',
      entry: {
        id: 'e-1',
        timestamp: ts,
        session_id: 's-1',
        severity: 'info',
        type: 'text',
        text: 'hello',
      },
    };
    expect(ServerMessage.parse(msg)).toMatchObject(msg);
  });

  it('parses logs message', () => {
    const msg = {
      type: 'logs',
      entries: [
        {
          id: 'e-1',
          timestamp: ts,
          session_id: 's-1',
          severity: 'debug',
          type: 'json',
          json: { a: 1 },
        },
      ],
    };
    expect(ServerMessage.parse(msg)).toMatchObject(msg);
  });

  it('parses rpc_request message', () => {
    const msg = {
      type: 'rpc_request',
      rpc_id: '550e8400-e29b-41d4-a716-446655440000',
      rpc_method: 'getUser',
      rpc_args: { id: 42 },
    };
    expect(ServerMessage.parse(msg)).toMatchObject(msg);
  });

  it('parses rpc_response message', () => {
    const msg = {
      type: 'rpc_response',
      rpc_id: '550e8400-e29b-41d4-a716-446655440000',
      rpc_response: { name: 'Alice' },
    };
    expect(ServerMessage.parse(msg)).toMatchObject(msg);
  });

  it('parses rpc_response with error', () => {
    const msg = {
      type: 'rpc_response',
      rpc_id: '550e8400-e29b-41d4-a716-446655440000',
      rpc_error: 'User not found',
    };
    expect(ServerMessage.parse(msg)).toMatchObject(msg);
  });

  it('parses session_list message', () => {
    const msg = {
      type: 'session_list',
      sessions: [
        {
          session_id: 's-1',
          application: { name: 'my-app' },
          started_at: ts,
          last_heartbeat: ts,
          is_active: true,
          log_count: 42,
          color_index: 3,
        },
      ],
    };
    expect(ServerMessage.parse(msg)).toMatchObject(msg);
  });

  it('parses session_update message', () => {
    const msg = {
      type: 'session_update',
      session_id: 's-1',
      session_action: 'start',
      application: { name: 'my-app', version: '2.0.0' },
    };
    expect(ServerMessage.parse(msg)).toMatchObject(msg);
  });

  it('parses state_snapshot message', () => {
    const msg = {
      type: 'state_snapshot',
      state: { counter: 10, flag: true, nested: { a: 1 } },
    };
    expect(ServerMessage.parse(msg)).toMatchObject(msg);
  });

  it('parses history message', () => {
    const msg = {
      type: 'history',
      query_id: 'q-1',
      history_entries: [
        {
          id: 'e-old',
          timestamp: ts,
          session_id: 's-1',
          severity: 'warning',
          type: 'text',
          text: 'old log',
        },
      ],
      has_more: true,
      cursor: 'cur-abc',
    };
    expect(ServerMessage.parse(msg)).toMatchObject(msg);
  });

  it('parses subscribe_ack message', () => {
    const msg = { type: 'subscribe_ack' };
    expect(ServerMessage.parse(msg)).toMatchObject(msg);
  });

  // ── Rejection tests ──

  it('rejects invalid type', () => {
    expect(() => ServerMessage.parse({ type: 'invalid' })).toThrow();
  });

  it('rejects missing type', () => {
    expect(() => ServerMessage.parse({})).toThrow();
  });

  it('rejects invalid rpc_id (not uuid)', () => {
    expect(() =>
      ServerMessage.parse({
        type: 'rpc_request',
        rpc_id: 'not-a-uuid',
        rpc_method: 'test',
      }),
    ).toThrow();
  });
});
