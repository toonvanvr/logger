// ─── Main API ────────────────────────────────────────────────────────
export { Logger } from './logger'
export type { LoggerOptions, Middleware } from './logger'

// ─── Message types ───────────────────────────────────────────────────
export type { Severity } from './logger-builders'
export type { MessageKind, QueuedMessage } from './logger-types'

// ─── Transport ───────────────────────────────────────────────────────
export { createTransport } from './transport/auto'
export type { TransportType } from './transport/auto'
export type { TransportAdapter } from './transport/types'

// ─── Color Helpers ───────────────────────────────────────────────────
export * as color from './color'

