import type { Severity } from './logger-builders.js'
import type { QueuedMessage } from './logger-types.js'
import type { LogQueue } from './queue.js'
import type { TransportAdapter } from './transport/types.js'

// ─── RPC handler type ────────────────────────────────────────────────

export type RpcHandler = {
  description: string
  category: 'getter' | 'tool'
  argsSchema?: Record<string, unknown>
  confirm?: boolean
  handler: (args: unknown) => unknown | Promise<unknown>
}

// ─── Session entries ─────────────────────────────────────────────────

export function buildSessionStartEntry(
  sessionId: string,
  app: string,
  environment: string,
  metadata?: Record<string, string>,
): QueuedMessage {
  return {
    kind: 'session',
    session_id: sessionId,
    action: 'start',
    application: { name: app, environment },
    ...(metadata ? { metadata } : {}),
  }
}

export function buildSessionEndEntry(sessionId: string): QueuedMessage {
  return {
    kind: 'session',
    session_id: sessionId,
    action: 'end',
  }
}

// ─── RPC handling ────────────────────────────────────────────────────

export function handleRpcRequest(
  msg: Record<string, unknown>,
  handlers: Map<string, RpcHandler>,
  enqueue: (entry: QueuedMessage) => void,
  buildBase: (severity: Severity) => QueuedMessage,
): void {
  if (msg.type !== 'rpc_request' || typeof msg.rpc_method !== 'string') return

  const handler = handlers.get(msg.rpc_method)
  if (!handler) {
    enqueue({
      ...buildBase('error'),
      kind: 'rpc_response',
      rpc_id: msg.rpc_id as string,
      error: `Unknown RPC method: ${msg.rpc_method}`,
    })
    return
  }

  Promise.resolve(handler.handler(msg.rpc_args)).then(
    (result) => {
      enqueue({
        ...buildBase('info'),
        kind: 'rpc_response',
        rpc_id: msg.rpc_id as string,
        result,
      })
    },
    (err: Error) => {
      enqueue({
        ...buildBase('error'),
        kind: 'rpc_response',
        rpc_id: msg.rpc_id as string,
        error: err.message,
      })
    },
  )
}

// ─── Queue drain ─────────────────────────────────────────────────────

export async function drainTransportQueue(
  transport: TransportAdapter | null,
  queue: LogQueue,
  maxBatch = 100,
): Promise<void> {
  if (!transport || !transport.connected) return
  const entries = queue.drain(maxBatch)
  if (entries.length === 0) return
  try {
    await transport.send(entries)
  } catch {
    // Re-enqueue on failure (best-effort).
    for (const e of entries) {
      queue.push(e)
    }
  }
}
