import type { TransportType } from './transport/auto'
import type { TransportAdapter } from './transport/types'

// ─── Message routing ─────────────────────────────────────────────────

/**
 * Message kinds sent by the client to the server.
 *
 * Core: 'session' | 'event' | 'data' — structured log messages via all transports.
 * RPC extension: 'rpc_response' | 'register_tools' — WebSocket-only bidirectional RPC.
 */
export type MessageKind = 'session' | 'event' | 'data' | 'rpc_response' | 'register_tools'

export interface QueuedMessage {
  kind: MessageKind
  [key: string]: unknown
}

// ─── Public types ────────────────────────────────────────────────────

export type Middleware = (entry: QueuedMessage, next: () => void) => void

export interface LoggerOptions {
  url?: string
  app?: string
  environment?: string
  transport?: TransportType
  middleware?: Middleware[]
  maxQueueSize?: number
  sessionId?: string
  /** @internal — inject a pre-built transport (for testing). */
  _transport?: TransportAdapter
}

// ─── Middleware chain runner ─────────────────────────────────────────

export function runMiddlewareChain(
  middlewares: Middleware[],
  entry: QueuedMessage,
  done: () => void,
): void {
  if (middlewares.length === 0) {
    done()
    return
  }

  let index = 0
  const next = () => {
    index++
    if (index < middlewares.length) {
      middlewares[index](entry, next)
    } else {
      done()
    }
  }
  middlewares[0](entry, next)
}
