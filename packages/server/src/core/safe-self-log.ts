import type { SelfLogger } from '../modules/self-logger'

type LogLevel = 'info' | 'warn' | 'error'

/**
 * Safely call selfLogger, falling back to console if it throws.
 * Handles undefined selfLogger (e.g. LokiForwarder before wiring).
 */
export function safeSelfLog(
  selfLogger: SelfLogger | undefined,
  level: LogLevel,
  msg: string,
): void {
  try {
    selfLogger?.[level](msg)
  } catch {
    console[level](msg)
  }
}
