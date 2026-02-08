import type { LogEntry, Severity as SeverityType } from '@logger/shared';
import {
  baseFields,
  buildBinaryEntry,
  buildCustomEntry,
  buildErrorException,
  buildGroupCloseEntry,
  buildGroupOpenEntry,
  buildHtmlEntry,
  buildImageEntry,
  buildJsonEntry,
  buildStateEntry,
  buildTextEntry,
  buildUnstickyEntry,
  stringifyTags,
} from './logger-builders.js';
import {
  buildSessionEndEntry,
  buildSessionStartEntry,
  drainTransportQueue,
  handleRpcRequest,
  type RpcHandler,
} from './logger-session.js';
import { type LoggerOptions, type Middleware, runMiddlewareChain } from './logger-types.js';
import { LogQueue } from './queue.js';
import { createTransport, type TransportType } from './transport/auto.js';
import type { TransportAdapter } from './transport/types.js';

// Re-export public types from their canonical location.
export type { LoggerOptions, Middleware } from './logger-types.js';

// ─── Logger ──────────────────────────────────────────────────────────

export class Logger {
  private readonly queue: LogQueue;
  private transport: TransportAdapter | null;
  private readonly middlewares: Middleware[];
  private readonly app: string;
  private readonly environment: string;
  private readonly url: string;
  private readonly transportType: TransportType;
  private currentSection: string | undefined;
  private groupStack: string[] = [];
  private sessionStarted = false;
  private drainTimer: ReturnType<typeof setInterval> | null = null;
  private readonly _sessionId: string;
  private transportReady: Promise<void> | null = null;
  private readonly rpcHandlers = new Map<string, RpcHandler>();
  private _nextSticky = false;
  private _nextId: string | undefined;
  private _nextAfterId: string | undefined;
  private _nextBeforeId: string | undefined;

  readonly session: {
    readonly id: string;
    start: (metadata?: Record<string, unknown>) => void;
    end: () => void;
  };

  readonly rpc: {
    register: (name: string, opts: RpcHandler) => void;
    unregister: (name: string) => void;
  };

  constructor(options?: LoggerOptions) {
    this._sessionId = options?.sessionId ?? crypto.randomUUID();
    this.app = options?.app ?? process.env.npm_package_name ?? 'unknown';
    this.environment = options?.environment ?? process.env.LOGGER_ENVIRONMENT ?? 'dev';
    this.url = options?.url ?? process.env.LOGGER_URL ?? 'ws://localhost:8080';
    this.transportType = options?.transport ?? 'auto';
    this.queue = new LogQueue(options?.maxQueueSize);
    this.middlewares = options?.middleware ? [...options.middleware] : [];
    this.transport = options?._transport ?? null;

    if (!this.transport) {
      this.transportReady = createTransport({
        type: this.transportType,
        url: this.url,
      }).then((t) => {
        this.transport = t;
        if (this.transport.onMessage) {
          this.transport.onMessage((data: unknown) => this.handleServerMessage(data));
        }
      }).catch(() => {
        // Transport unavailable — entries accumulate in queue.
      });
    } else {
      if (this.transport.onMessage) {
        this.transport.onMessage((data: unknown) => this.handleServerMessage(data));
      }
    }

    this.drainTimer = setInterval(() => this.drainQueue(), 100);

    this.session = {
      id: this._sessionId,
      start: (metadata?: Record<string, unknown>) => this.startSession(metadata),
      end: () => this.endSession(),
    };

    this.rpc = {
      register: (name, opts) => this.rpcHandlers.set(name, opts),
      unregister: (name) => this.rpcHandlers.delete(name),
    };
  }

  // ─── Severity methods ────────────────────────────────────────────

  debug(message: string, meta?: Record<string, unknown>): void {
    this.log('debug', message, meta);
  }

  info(message: string, meta?: Record<string, unknown>): void {
    this.log('info', message, meta);
  }

  warn(message: string, meta?: Record<string, unknown>): void {
    this.log('warning', message, meta);
  }

  error(message: string | Error, meta?: Record<string, unknown>): void {
    if (message instanceof Error) {
      this.logError('error', message, meta);
    } else {
      this.log('error', message, meta);
    }
  }

  critical(message: string | Error, meta?: Record<string, unknown>): void {
    if (message instanceof Error) {
      this.logError('critical', message, meta);
    } else {
      this.log('critical', message, meta);
    }
  }

  // ─── Structured methods ──────────────────────────────────────────

  json(data: unknown, options?: { severity?: string }): void {
    this.enqueue(buildJsonEntry(this.base((options?.severity as SeverityType) ?? 'info'), data));
  }

  html(content: string, options?: { severity?: string }): void {
    this.enqueue(buildHtmlEntry(this.base((options?.severity as SeverityType) ?? 'info'), content));
  }

  binary(data: Uint8Array, options?: { severity?: string }): void {
    this.enqueue(buildBinaryEntry(this.base((options?.severity as SeverityType) ?? 'info'), data));
  }

  // ─── Sticky modifier ────────────────────────────────────────────────

  /** Mark the next logged entry as sticky (pinned to top of viewport). */
  sticky(): this {
    this._nextSticky = true;
    return this;
  }

  /** Send an unpin action for a sticky group (and optionally a specific entry). */
  unsticky(groupId: string, entryId?: string): void {
    this.enqueue(buildUnstickyEntry(this.base('info'), groupId, entryId));
  }

  /** Override the ID of the next logged entry. One-shot modifier. */
  withId(id: string): this {
    this._nextId = id;
    return this;
  }

  /** Insert the next logged entry visually after the entry with the given ID. One-shot modifier. */
  after(id: string): this {
    this._nextAfterId = id;
    return this;
  }

  /** Insert the next logged entry visually before the entry with the given ID. One-shot modifier. */
  before(id: string): this {
    this._nextBeforeId = id;
    return this;
  }

  // ─── Group ───────────────────────────────────────────────────────

  group(name: string, options?: { sticky?: boolean }): string;
  group(name: string, fn: () => void | Promise<void>, options?: { sticky?: boolean }): Promise<string>;
  group(name: string, fnOrOpts?: (() => void | Promise<void>) | { sticky?: boolean }, maybeOpts?: { sticky?: boolean }): string | Promise<string> {
    let fn: (() => void | Promise<void>) | undefined;
    let options: { sticky?: boolean } | undefined;
    if (typeof fnOrOpts === 'function') {
      fn = fnOrOpts;
      options = maybeOpts;
    } else {
      options = fnOrOpts;
    }

    const groupId = crypto.randomUUID();
    this.groupStack.push(groupId);
    this.enqueue(buildGroupOpenEntry(this.base('info'), groupId, name, options));
    if (fn) {
      return (async () => {
        try { await fn!(); } finally { this.groupEnd(); }
        return groupId;
      })();
    }
    return groupId;
  }

  groupEnd(): void {
    const groupId = this.groupStack.pop();
    if (!groupId) return;
    this.enqueue(buildGroupCloseEntry(this.base('info'), groupId));
  }

  // ─── State / Image / Custom ──────────────────────────────────────

  state(key: string, value: unknown): void {
    this.enqueue(buildStateEntry(this.base('info'), key, value));
  }

  image(data: Buffer | Uint8Array | string, mime: string, options?: { id?: string }): void {
    this.enqueue(buildImageEntry(this.base('info'), data, mime, options?.id));
  }

  custom(type: string, data: unknown, options?: { id?: string; replace?: boolean }): void {
    this.enqueue(buildCustomEntry(this.base('info'), type, data, options));
  }

  table(columns: string[], rows: unknown[][]): void {
    this.custom('table', { columns, rows });
  }

  progress(label: string, value: number, max: number, options?: { id?: string }): void {
    const id = options?.id ?? `progress-${label}`;
    this.custom('progress', { label, value, max }, { id, replace: true });
  }

  kv(entries: Record<string, unknown>, options?: { id?: string }): void {
    const formatted = Object.entries(entries).map(([key, value]) => ({
      key,
      value: value as string | number | boolean,
    }));
    const id = options?.id ?? `kv-${Object.keys(entries).sort().join(',')}`;
    this.custom('kv', { entries: formatted }, { id, replace: true });
  }

  // ─── Section / Middleware / Lifecycle ─────────────────────────────

  section(name: string): void { this.currentSection = name; }

  use(middleware: Middleware): void { this.middlewares.push(middleware); }

  async flush(): Promise<void> { await this.drainQueue(); }

  async close(): Promise<void> {
    if (this.drainTimer) { clearInterval(this.drainTimer); this.drainTimer = null; }
    await this.drainQueue();
    if (this.transport) await this.transport.close();
  }

  // ─── Internals ──────────────────────────────────────────────────

  private base(severity: SeverityType): LogEntry {
    return baseFields(
      this._sessionId, this.app, this.environment, severity,
      this.currentSection,
      this.groupStack.length > 0 ? this.groupStack[this.groupStack.length - 1] : undefined,
    );
  }

  private log(severity: SeverityType, message: string, meta?: Record<string, unknown>): void {
    this.enqueue(buildTextEntry(this.base(severity), message, meta ? stringifyTags(meta) : undefined));
  }

  private logError(severity: SeverityType, err: Error, meta?: Record<string, unknown>): void {
    this.enqueue({
      ...buildTextEntry(this.base(severity), err.message, meta ? stringifyTags(meta) : undefined),
      exception: buildErrorException(err),
    });
  }

  private enqueue(entry: LogEntry): void {
    if (this._nextSticky) {
      entry = { ...entry, sticky: true };
      this._nextSticky = false;
    }
    if (this._nextId) {
      entry = { ...entry, id: this._nextId };
      this._nextId = undefined;
    }
    if (this._nextAfterId) {
      entry = { ...entry, after_id: this._nextAfterId };
      this._nextAfterId = undefined;
    }
    if (this._nextBeforeId) {
      entry = { ...entry, before_id: this._nextBeforeId };
      this._nextBeforeId = undefined;
    }
    if (!this.sessionStarted) this.startSession();
    runMiddlewareChain(this.middlewares, entry, () => this.queue.push(entry));
  }

  private async drainQueue(): Promise<void> {
    await drainTransportQueue(this.transport, this.queue);
  }

  private startSession(metadata?: Record<string, unknown>): void {
    if (this.sessionStarted) return;
    this.sessionStarted = true;
    this.queue.push(
      buildSessionStartEntry(this.base('info'), metadata ? stringifyTags(metadata) : undefined),
    );
  }

  private endSession(): void {
    this.queue.push(buildSessionEndEntry(this.base('info')));
  }

  private handleServerMessage(data: unknown): void {
    if (!data || typeof data !== 'object') return;
    handleRpcRequest(
      data as Record<string, unknown>,
      this.rpcHandlers,
      (entry) => this.enqueue(entry),
      (severity) => this.base(severity),
    );
  }
}
