import type { QueuedMessage } from '../logger-types.js'

/**
 * Transport adapter interface.
 * All transports implement this contract so the Logger can swap them.
 */
export interface TransportAdapter {
  connect(): Promise<void>
  send(messages: QueuedMessage[]): Promise<void>
  /** Optional bidirectional message handler (used by WS). */
  onMessage?(handler: (data: unknown) => void): void
  close(): Promise<void>
  readonly connected: boolean
}
