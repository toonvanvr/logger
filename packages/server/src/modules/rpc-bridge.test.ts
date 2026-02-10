import { describe, expect, it } from 'bun:test';
import { RpcBridge, type RpcToolInfo } from './rpc-bridge';

// ─── Mock WebSocket ──────────────────────────────────────────────────

class MockWebSocket {
  sent: any[] = [];
  send(data: string) {
    this.sent.push(JSON.parse(data));
  }
}

// ─── Helpers ─────────────────────────────────────────────────────────

function makeTools(): RpcToolInfo[] {
  return [
    { name: 'getCurrentUser', description: 'Get the current user', category: 'getter' },
    { name: 'clearCache', description: 'Clear the application cache', category: 'tool', confirm: true },
  ];
}

// ─── Tests ───────────────────────────────────────────────────────────

describe('RpcBridge', () => {
  it('registers and gets tools for a session', () => {
    const bridge = new RpcBridge();
    const tools = makeTools();

    bridge.registerTools('sess-1', tools);

    expect(bridge.getTools('sess-1')).toEqual(tools);
    expect(bridge.getTools('sess-unknown')).toEqual([]);
  });

  it('getAllTools returns tools across all sessions', () => {
    const bridge = new RpcBridge();
    const tools1 = [makeTools()[0]!];
    const tools2 = [makeTools()[1]!];

    bridge.registerTools('sess-1', tools1);
    bridge.registerTools('sess-2', tools2);

    const all = bridge.getAllTools();
    expect(all.size).toBe(2);
    expect(all.get('sess-1')).toEqual(tools1);
    expect(all.get('sess-2')).toEqual(tools2);
  });

  it('routes request to the correct session', async () => {
    const bridge = new RpcBridge();
    const viewerWs = new MockWebSocket();
    const sentToClient: any[] = [];

    bridge.registerTools('sess-1', makeTools());
    bridge.setClientSender((sessionId, message) => {
      sentToClient.push({ sessionId, message });
    });

    // Start request (don't await — we need to respond first)
    const promise = bridge.handleRequest({
      rpcId: 'r1',
      targetSessionId: 'sess-1',
      method: 'getCurrentUser',
      args: { includeEmail: true },
      viewerWs,
    });

    // Verify the request was forwarded to client
    expect(sentToClient).toHaveLength(1);
    expect(sentToClient[0].sessionId).toBe('sess-1');
    expect(sentToClient[0].message.type).toBe('rpc_request');
    expect(sentToClient[0].message.rpc_id).toBe('r1');
    expect(sentToClient[0].message.method).toBe('getCurrentUser');
    expect(sentToClient[0].message.args).toEqual({ includeEmail: true });

    // Respond from client
    bridge.handleResponse({ rpcId: 'r1', data: { name: 'John' } });
    await promise;

    expect(viewerWs.sent).toHaveLength(1);
    expect(viewerWs.sent[0].type).toBe('rpc_response');
    expect(viewerWs.sent[0].rpc_id).toBe('r1');
    expect(viewerWs.sent[0].result).toEqual({ name: 'John' });
  });

  it('handles response with error and forwards to viewer', async () => {
    const bridge = new RpcBridge();
    const viewerWs = new MockWebSocket();

    bridge.registerTools('sess-1', makeTools());
    bridge.setClientSender(() => {});

    const promise = bridge.handleRequest({
      rpcId: 'r2',
      targetSessionId: 'sess-1',
      method: 'getCurrentUser',
      args: undefined,
      viewerWs,
    });

    bridge.handleResponse({ rpcId: 'r2', error: 'User not authenticated' });
    await promise;

    expect(viewerWs.sent).toHaveLength(1);
    expect(viewerWs.sent[0].type).toBe('rpc_response');
    expect(viewerWs.sent[0].error).toBe('User not authenticated');
  });

  it('times out after configured duration', async () => {
    const bridge = new RpcBridge({ timeoutMs: 50 });
    const viewerWs = new MockWebSocket();

    bridge.registerTools('sess-1', makeTools());
    bridge.setClientSender(() => {});

    await bridge.handleRequest({
      rpcId: 'r3',
      targetSessionId: 'sess-1',
      method: 'getCurrentUser',
      args: undefined,
      viewerWs,
    });

    expect(viewerWs.sent).toHaveLength(1);
    expect(viewerWs.sent[0].type).toBe('rpc_response');
    expect(viewerWs.sent[0].error).toBe('RPC timeout after 50ms');
    expect(bridge.getPendingCount()).toBe(0);
  });

  it('unregister session clears tools', () => {
    const bridge = new RpcBridge();
    bridge.registerTools('sess-1', makeTools());

    expect(bridge.getTools('sess-1')).toHaveLength(2);

    bridge.unregisterSession('sess-1');

    expect(bridge.getTools('sess-1')).toEqual([]);
  });

  it('returns error for unknown session', async () => {
    const bridge = new RpcBridge();
    const viewerWs = new MockWebSocket();

    await bridge.handleRequest({
      rpcId: 'r4',
      targetSessionId: 'sess-unknown',
      method: 'getCurrentUser',
      args: undefined,
      viewerWs,
    });

    expect(viewerWs.sent).toHaveLength(1);
    expect(viewerWs.sent[0].type).toBe('rpc_response');
    expect(viewerWs.sent[0].error).toBe('Session "sess-unknown" not found');
  });

  it('returns error for unknown method', async () => {
    const bridge = new RpcBridge();
    const viewerWs = new MockWebSocket();

    bridge.registerTools('sess-1', makeTools());

    await bridge.handleRequest({
      rpcId: 'r5',
      targetSessionId: 'sess-1',
      method: 'nonExistentMethod',
      args: undefined,
      viewerWs,
    });

    expect(viewerWs.sent).toHaveLength(1);
    expect(viewerWs.sent[0].type).toBe('rpc_response');
    expect(viewerWs.sent[0].error).toBe('Unknown method "nonExistentMethod" on session "sess-1"');
  });

  it('handles multiple concurrent requests', async () => {
    const bridge = new RpcBridge();
    const viewerWs1 = new MockWebSocket();
    const viewerWs2 = new MockWebSocket();

    bridge.registerTools('sess-1', makeTools());
    bridge.registerTools('sess-2', [
      { name: 'getStatus', description: 'Get status', category: 'getter' },
    ]);
    bridge.setClientSender(() => {});

    // Fire two requests concurrently
    const p1 = bridge.handleRequest({
      rpcId: 'r10',
      targetSessionId: 'sess-1',
      method: 'getCurrentUser',
      args: undefined,
      viewerWs: viewerWs1,
    });

    const p2 = bridge.handleRequest({
      rpcId: 'r11',
      targetSessionId: 'sess-2',
      method: 'getStatus',
      args: undefined,
      viewerWs: viewerWs2,
    });

    expect(bridge.getPendingCount()).toBe(2);

    // Respond in reverse order
    bridge.handleResponse({ rpcId: 'r11', data: { status: 'ok' } });
    bridge.handleResponse({ rpcId: 'r10', data: { name: 'Alice' } });

    await Promise.all([p1, p2]);

    expect(viewerWs1.sent).toHaveLength(1);
    expect(viewerWs1.sent[0].result).toEqual({ name: 'Alice' });

    expect(viewerWs2.sent).toHaveLength(1);
    expect(viewerWs2.sent[0].result).toEqual({ status: 'ok' });

    expect(bridge.getPendingCount()).toBe(0);
  });

  it('ignores response for unknown rpcId', () => {
    const bridge = new RpcBridge();

    // Should not throw
    bridge.handleResponse({ rpcId: 'non-existent', data: 'whatever' });
    expect(bridge.getPendingCount()).toBe(0);
  });
});
