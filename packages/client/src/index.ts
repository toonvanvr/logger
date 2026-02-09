// ─── Main API ────────────────────────────────────────────────────────
export { Logger } from './logger.js'
export type { LoggerOptions, Middleware } from './logger.js'

// ─── v2 Message types ────────────────────────────────────────────────
export type { Severity } from './logger-builders.js'
export type { MessageKind, QueuedMessage } from './logger-types.js'

// ─── Transport ───────────────────────────────────────────────────────
export { createTransport } from './transport/auto.js'
export type { TransportType } from './transport/auto.js'
export type { TransportAdapter } from './transport/types.js'

// ─── Internals (for advanced use) ────────────────────────────────────
export { LogQueue } from './queue.js'
export { parseStackTrace } from './stack-parser.js'

// ─── Color Helpers ───────────────────────────────────────────────────
export * as color from './color.js';

