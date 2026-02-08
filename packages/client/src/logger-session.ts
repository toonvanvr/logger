import type { LogEntry, Severity as SeverityType } from '@logger/shared';
import type { LogQueue } from './queue.js';
import type { TransportAdapter } from './transport/types.js';

// ─── RPC handler type ────────────────────────────────────────────────

export type RpcHandler = {
  description: string;
  category: 'getter' | 'tool';
  argsSchema?: Record<string, unknown>;
  confirm?: boolean;
  handler: (args: unknown) => unknown | Promise<unknown>;
};

// ─── Session entries ─────────────────────────────────────────────────

export function buildSessionStartEntry(
  base: LogEntry,
  tags?: Record<string, string>,
): LogEntry {
  return {
    ...base,
    type: 'session',
    session_action: 'start',
    ...(tags ? { tags } : {}),
  };
}

export function buildSessionEndEntry(base: LogEntry): LogEntry {
  return {
    ...base,
    type: 'session',
    session_action: 'end',
  };
}

// ─── RPC handling ────────────────────────────────────────────────────

export function handleRpcRequest(
  msg: Record<string, unknown>,
  handlers: Map<string, RpcHandler>,
  enqueue: (entry: LogEntry) => void,
  buildBase: (severity: SeverityType) => LogEntry,
): void {
  if (msg.type !== 'rpc_request' || typeof msg.rpc_method !== 'string') return;

  const handler = handlers.get(msg.rpc_method);
  if (!handler) {
    enqueue({
      ...buildBase('error'),
      type: 'rpc',
      rpc_id: msg.rpc_id as string,
      rpc_direction: 'error',
      rpc_method: msg.rpc_method,
      rpc_error: `Unknown RPC method: ${msg.rpc_method}`,
    });
    return;
  }

  Promise.resolve(handler.handler(msg.rpc_args)).then(
    (result) => {
      enqueue({
        ...buildBase('info'),
        type: 'rpc',
        rpc_id: msg.rpc_id as string,
        rpc_direction: 'response',
        rpc_method: msg.rpc_method as string,
        rpc_response: result,
      });
    },
    (err: Error) => {
      enqueue({
        ...buildBase('error'),
        type: 'rpc',
        rpc_id: msg.rpc_id as string,
        rpc_direction: 'error',
        rpc_method: msg.rpc_method as string,
        rpc_error: err.message,
      });
    },
  );
}

// ─── Queue drain ─────────────────────────────────────────────────────

export async function drainTransportQueue(
  transport: TransportAdapter | null,
  queue: LogQueue,
  maxBatch = 100,
): Promise<void> {
  if (!transport || !transport.connected) return;
  const entries = queue.drain(maxBatch);
  if (entries.length === 0) return;
  try {
    await transport.send(entries);
  } catch {
    // Re-enqueue on failure (best-effort).
    for (const e of entries) {
      queue.push(e);
    }
  }
}
