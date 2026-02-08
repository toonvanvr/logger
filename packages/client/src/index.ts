// ─── Main API ────────────────────────────────────────────────────────
export { Logger } from './logger.js';
export type { LoggerOptions, Middleware } from './logger.js';

// ─── Transport ───────────────────────────────────────────────────────
export { createTransport } from './transport/auto.js';
export type { TransportType } from './transport/auto.js';
export type { TransportAdapter } from './transport/types.js';

// ─── Internals (for advanced use) ────────────────────────────────────
export { LogQueue } from './queue.js';
export { parseStackTrace } from './stack-parser.js';

// ─── Color Helpers ───────────────────────────────────────────────────
export * as color from './color.js';

// ─── Re-exports from @logger/shared ─────────────────────────────────
export type {
    ApplicationInfo, ExceptionData, GroupAction, IconRef, ImageData, LogBatch, LogEntry,
    LogType, RpcDirection, ServerMessage,
    ServerMessageType, SessionAction, SessionInfo, Severity, SourceLocation, StackFrame
} from '@logger/shared';

