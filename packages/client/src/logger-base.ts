import {
  baseFields,
  buildErrorException,
  buildGroupCloseEntry,
  buildGroupOpenEntry,
  buildTextEntry,
  buildUnstickyEntry,
  type Severity,
  stringifyTags,
} from './logger-builders.js'
import {
  buildSessionEndEntry,
  buildSessionStartEntry,
  drainTransportQueue,
  handleRpcRequest,
  type RpcHandler,
} from './logger-session.js'
import { type LoggerOptions, type Middleware, type QueuedMessage, runMiddlewareChain } from './logger-types.js'
import { LogQueue } from './queue.js'
import { createTransport, type TransportType } from './transport/auto.js'
import type { TransportAdapter } from './transport/types.js'

// ─── LoggerBase ──────────────────────────────────────────────────────

export class LoggerBase {
  protected readonly queue: LogQueue
  protected transport: TransportAdapter | null
  protected readonly middlewares: Middleware[]
  protected readonly app: string
  protected readonly environment: string
  protected readonly url: string
  protected readonly transportType: TransportType
  protected currentSection: string | undefined
  protected groupStack: string[] = [];
  protected sessionStarted = false;
  protected drainTimer: ReturnType<typeof setInterval> | null = null;
  protected readonly _sessionId: string
  protected transportReady: Promise<void> | null = null;
  protected readonly rpcHandlers = new Map<string, RpcHandler>();
  protected _nextSticky = false;
  protected _nextId: string | undefined
  protected _nextAfterId: string | undefined
  protected _nextBeforeId: string | undefined
  readonly session: { readonly id: string; start: (metadata?: Record<string, unknown>) => void; end: () => void }
  readonly rpc: { register: (name: string, opts: RpcHandler) => void; unregister: (name: string) => void }

  constructor(options?: LoggerOptions) {
    this._sessionId = options?.sessionId ?? crypto.randomUUID()
    this.app = options?.app ?? process.env.npm_package_name ?? 'unknown'
    this.environment = options?.environment ?? process.env.LOGGER_ENVIRONMENT ?? 'dev'
    this.url = options?.url ?? process.env.LOGGER_URL ?? 'ws://localhost:8080'
    this.transportType = options?.transport ?? 'auto'
    this.queue = new LogQueue(options?.maxQueueSize)
    this.middlewares = options?.middleware ? [...options.middleware] : []
    this.transport = options?._transport ?? null

    if (!this.transport) {
      this.transportReady = createTransport({
        type: this.transportType,
        url: this.url,
      }).then((t) => {
        this.transport = t
        if (this.transport.onMessage) {
          this.transport.onMessage((data: unknown) => this.handleServerMessage(data))
        }
      }).catch(() => {
        // Transport unavailable — entries accumulate in queue.
      })
    } else {
      if (this.transport.onMessage) {
        this.transport.onMessage((data: unknown) => this.handleServerMessage(data))
      }
    }

    this.drainTimer = setInterval(() => this.drainQueue(), 100)

    this.session = { id: this._sessionId, start: (metadata?) => this.startSession(metadata), end: () => this.endSession() }
    this.rpc = { register: (name, opts) => this.rpcHandlers.set(name, opts), unregister: (name) => this.rpcHandlers.delete(name) }
  }

  debug(message: string, meta?: Record<string, unknown>): void { this.log('debug', message, meta) }
  info(message: string, meta?: Record<string, unknown>): void { this.log('info', message, meta) }
  warn(message: string, meta?: Record<string, unknown>): void { this.log('warning', message, meta) }

  error(message: string | Error, meta?: Record<string, unknown>): void {
    if (message instanceof Error) { this.logError('error', message, meta) } else { this.log('error', message, meta) }
  }

  critical(message: string | Error, meta?: Record<string, unknown>): void {
    if (message instanceof Error) { this.logError('critical', message, meta) } else { this.log('critical', message, meta) }
  }

  // ─── Sticky modifier ────────────────────────────────────────────────

  /** Mark the next logged entry as sticky (pinned to top of viewport). */
  sticky(): this {
    this._nextSticky = true
    return this
  }

  /** Send an unpin action for a sticky group (and optionally a specific entry). */
  unsticky(groupId: string, entryId?: string): void {
    this.enqueue(buildUnstickyEntry(this.base('info'), groupId, entryId))
  }

  /** Override the ID of the next logged entry. One-shot modifier. */
  withId(id: string): this {
    this._nextId = id
    return this
  }

  /** Insert the next logged entry visually after the entry with the given ID. One-shot modifier. */
  after(id: string): this {
    this._nextAfterId = id
    return this
  }

  /** Insert the next logged entry visually before the entry with the given ID. One-shot modifier. */
  before(id: string): this {
    this._nextBeforeId = id
    return this
  }


  group(name: string, options?: { sticky?: boolean }): string
  group(name: string, fn: () => void | Promise<void>, options?: { sticky?: boolean }): Promise<string>
  group(name: string, fnOrOpts?: (() => void | Promise<void>) | { sticky?: boolean }, maybeOpts?: { sticky?: boolean }): string | Promise<string> {
    let fn: (() => void | Promise<void>) | undefined
    let options: { sticky?: boolean } | undefined
    if (typeof fnOrOpts === 'function') {
      fn = fnOrOpts
      options = maybeOpts
    } else {
      options = fnOrOpts
    }

    const groupId = crypto.randomUUID()
    this.groupStack.push(groupId)
    this.enqueue(buildGroupOpenEntry(this.base('info'), groupId, name, options))
    if (fn) {
      return (async () => {
        try { await fn!() } finally { this.groupEnd() }
        return groupId
      })()
    }
    return groupId
  }

  groupEnd(): void {
    const groupId = this.groupStack.pop()
    if (groupId) this.enqueue(buildGroupCloseEntry(this.base('info'), groupId))
  }

  section(name: string): void { this.currentSection = name }
  use(middleware: Middleware): void { this.middlewares.push(middleware) }
  async flush(): Promise<void> { await this.drainQueue() }

  async close(): Promise<void> {
    if (this.drainTimer) { clearInterval(this.drainTimer); this.drainTimer = null }
    await this.drainQueue()
    if (this.transport) await this.transport.close()
  }
  // ─── Protected internals ────────────────────────────────────────
  protected base(severity: Severity): QueuedMessage {
    return baseFields(
      this._sessionId, this.app, this.environment, severity,
      this.currentSection,
      this.groupStack.length > 0 ? this.groupStack[this.groupStack.length - 1] : undefined,
    )
  }

  protected log(severity: Severity, message: string, meta?: Record<string, unknown>): void {
    this.enqueue(buildTextEntry(this.base(severity), message, meta ? stringifyTags(meta) : undefined))
  }

  protected logError(severity: Severity, err: Error, meta?: Record<string, unknown>): void {
    this.enqueue({
      ...buildTextEntry(this.base(severity), err.message, meta ? stringifyTags(meta) : undefined),
      exception: buildErrorException(err),
    })
  }

  protected enqueue(entry: QueuedMessage): void {
    if (this._nextSticky) {
      const existing = (entry.labels as Record<string, string>) ?? {}
      entry = { ...entry, labels: { ...existing, _sticky: 'true' } }
      this._nextSticky = false
    }
    if (this._nextId) { entry = { ...entry, id: this._nextId }; this._nextId = undefined }
    if (this._nextAfterId) { entry = { ...entry, prev_id: this._nextAfterId }; this._nextAfterId = undefined }
    if (this._nextBeforeId) { entry = { ...entry, next_id: this._nextBeforeId }; this._nextBeforeId = undefined }
    if (!this.sessionStarted) this.startSession()
    runMiddlewareChain(this.middlewares, entry, () => this.queue.push(entry))
  }

  private async drainQueue(): Promise<void> {
    await drainTransportQueue(this.transport, this.queue)
  }

  private startSession(metadata?: Record<string, unknown>): void {
    if (this.sessionStarted) return
    this.sessionStarted = true
    this.queue.push(
      buildSessionStartEntry(
        this._sessionId,
        this.app,
        this.environment,
        metadata ? stringifyTags(metadata) : undefined,
      ),
    )
  }

  private endSession(): void {
    this.queue.push(buildSessionEndEntry(this._sessionId))
  }

  private handleServerMessage(data: unknown): void {
    if (!data || typeof data !== 'object') return
    handleRpcRequest(
      data as Record<string, unknown>,
      this.rpcHandlers,
      (entry) => this.enqueue(entry),
      (severity) => this.base(severity),
    )
  }
}
