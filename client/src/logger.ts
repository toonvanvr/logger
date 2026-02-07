import type { ExceptionData, LogEntry, Severity as SeverityType } from '@logger/shared';
import { LogQueue } from './queue.js';
import { parseStackTrace } from './stack-parser.js';
import { createTransport, type TransportType } from './transport/auto.js';
import type { TransportAdapter } from './transport/types.js';

// ─── Public types ────────────────────────────────────────────────────

export type Middleware = (entry: LogEntry, next: () => void) => void;

export interface LoggerOptions {
  url?: string;
  app?: string;
  environment?: string;
  transport?: TransportType;
  middleware?: Middleware[];
  maxQueueSize?: number;
  sessionId?: string;
  /** @internal — inject a pre-built transport (for testing). */
  _transport?: TransportAdapter;
}

// ─── Logger ──────────────────────────────────────────────────────────

export class Logger {
  // Internals
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
  private readonly rpcHandlers = new Map<
    string,
    {
      description: string;
      category: 'getter' | 'tool';
      argsSchema?: Record<string, unknown>;
      confirm?: boolean;
      handler: (args: unknown) => unknown | Promise<unknown>;
    }
  >();

  // ── Public session façade ────────────────────────────────────────

  readonly session: {
    readonly id: string;
    start: (metadata?: Record<string, unknown>) => void;
    end: () => void;
  };

  // ── Public rpc façade ────────────────────────────────────────────

  readonly rpc: {
    register: (
      name: string,
      opts: {
        description: string;
        category: 'getter' | 'tool';
        argsSchema?: Record<string, unknown>;
        confirm?: boolean;
        handler: (args: unknown) => unknown | Promise<unknown>;
      },
    ) => void;
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

    // If no injected transport, lazily connect in the background.
    if (!this.transport) {
      this.transportReady = createTransport({
        type: this.transportType,
        url: this.url,
      }).then((t) => {
        this.transport = t;
        // Wire up server message handling (RPC dispatch).
        if (this.transport.onMessage) {
          this.transport.onMessage((data: unknown) => this.handleServerMessage(data));
        }
      }).catch(() => {
        // Transport unavailable — entries accumulate in queue.
      });
    } else {
      // Injected transport — wire up immediately.
      if (this.transport.onMessage) {
        this.transport.onMessage((data: unknown) => this.handleServerMessage(data));
      }
    }

    // Background drain interval.
    this.drainTimer = setInterval(() => this.drainQueue(), 100);

    // Session façade.
    this.session = {
      id: this._sessionId,
      start: (metadata?: Record<string, unknown>) => this.startSession(metadata),
      end: () => this.endSession(),
    };

    // RPC façade.
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
    this.enqueue({
      ...this.baseFields((options?.severity as SeverityType) ?? 'info'),
      type: 'json',
      json: data,
    });
  }

  html(content: string, options?: { severity?: string }): void {
    this.enqueue({
      ...this.baseFields((options?.severity as SeverityType) ?? 'info'),
      type: 'html',
      html: content,
    });
  }

  binary(data: Uint8Array, options?: { severity?: string }): void {
    const b64 = Buffer.from(data).toString('base64');
    this.enqueue({
      ...this.baseFields((options?.severity as SeverityType) ?? 'info'),
      type: 'binary',
      binary: b64,
    });
  }

  // ─── Group ───────────────────────────────────────────────────────

  group(name: string): void;
  group(name: string, fn: () => void | Promise<void>): Promise<void>;
  group(name: string, fn?: () => void | Promise<void>): void | Promise<void> {
    const groupId = crypto.randomUUID();
    this.groupStack.push(groupId);

    this.enqueue({
      ...this.baseFields('info'),
      type: 'group',
      group_id: groupId,
      group_action: 'open',
      group_label: name,
    });

    if (fn) {
      return (async () => {
        try {
          await fn();
        } finally {
          this.groupEnd();
        }
      })();
    }
  }

  groupEnd(): void {
    const groupId = this.groupStack.pop();
    if (!groupId) return;

    this.enqueue({
      ...this.baseFields('info'),
      type: 'group',
      group_id: groupId,
      group_action: 'close',
    });
  }

  // ─── State ───────────────────────────────────────────────────────

  state(key: string, value: unknown): void {
    this.enqueue({
      ...this.baseFields('info'),
      type: 'state',
      state_key: key,
      state_value: value,
    });
  }

  // ─── Image ───────────────────────────────────────────────────────

  image(
    data: Buffer | Uint8Array | string,
    mime: string,
    options?: { id?: string },
  ): void {
    const b64 = typeof data === 'string' ? data : Buffer.from(data).toString('base64');
    this.enqueue({
      ...this.baseFields('info'),
      ...(options?.id ? { id: options.id, replace: true } : {}),
      type: 'image',
      image: { data: b64, mimeType: mime },
    });
  }

  // ─── Custom ──────────────────────────────────────────────────────

  custom(
    type: string,
    data: unknown,
    options?: { id?: string; replace?: boolean },
  ): void {
    this.enqueue({
      ...this.baseFields('info'),
      ...(options?.id ? { id: options.id } : {}),
      ...(options?.replace || options?.id ? { replace: true } : {}),
      type: 'custom',
      custom_type: type,
      custom_data: data,
    });
  }

  // ─── Convenience custom helpers ──────────────────────────────────

  table(columns: string[], rows: unknown[][]): void {
    this.custom('table', { columns, rows });
  }

  progress(
    label: string,
    value: number,
    max: number,
    options?: { id?: string },
  ): void {
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

  // ─── Section ─────────────────────────────────────────────────────

  section(name: string): void {
    this.currentSection = name;
  }

  // ─── Middleware ──────────────────────────────────────────────────

  use(middleware: Middleware): void {
    this.middlewares.push(middleware);
  }

  // ─── Lifecycle ───────────────────────────────────────────────────

  async flush(): Promise<void> {
    await this.drainQueue();
  }

  async close(): Promise<void> {
    if (this.drainTimer) {
      clearInterval(this.drainTimer);
      this.drainTimer = null;
    }
    await this.drainQueue();
    if (this.transport) {
      await this.transport.close();
    }
  }

  // ─── Internals ──────────────────────────────────────────────────

  private baseFields(severity: SeverityType): LogEntry {
    return {
      id: crypto.randomUUID(),
      timestamp: new Date().toISOString(),
      session_id: this._sessionId,
      severity,
      type: 'text',
      application: {
        name: this.app,
        environment: this.environment,
      },
      ...(this.currentSection ? { section: this.currentSection } : {}),
      ...(this.groupStack.length > 0
        ? { group_id: this.groupStack[this.groupStack.length - 1] }
        : {}),
    };
  }

  private log(
    severity: SeverityType,
    message: string,
    meta?: Record<string, unknown>,
  ): void {
    this.enqueue({
      ...this.baseFields(severity),
      type: 'text',
      text: message,
      ...(meta ? { tags: this.stringifyTags(meta) } : {}),
    });
  }

  private logError(
    severity: SeverityType,
    err: Error,
    meta?: Record<string, unknown>,
  ): void {
    const exception: ExceptionData = {
      type: err.constructor.name,
      message: err.message,
      ...(err.stack ? { stackTrace: parseStackTrace(err.stack) } : {}),
      ...(err.cause instanceof Error
        ? {
            cause: {
              type: (err.cause as Error).constructor.name,
              message: (err.cause as Error).message,
              ...((err.cause as Error).stack
                ? { stackTrace: parseStackTrace((err.cause as Error).stack!) }
                : {}),
            },
          }
        : {}),
    };

    this.enqueue({
      ...this.baseFields(severity),
      type: 'text',
      text: err.message,
      exception,
      ...(meta ? { tags: this.stringifyTags(meta) } : {}),
    });
  }

  private stringifyTags(meta: Record<string, unknown>): Record<string, string> {
    const tags: Record<string, string> = {};
    for (const [k, v] of Object.entries(meta)) {
      tags[k] = typeof v === 'string' ? v : JSON.stringify(v);
    }
    return tags;
  }

  private enqueue(entry: LogEntry): void {
    // Auto-start session on first real log.
    if (!this.sessionStarted) {
      this.startSession();
    }

    // Run middleware chain.
    this.runMiddleware(entry, () => {
      this.queue.push(entry);
    });
  }

  private runMiddleware(entry: LogEntry, done: () => void): void {
    if (this.middlewares.length === 0) {
      done();
      return;
    }

    let index = 0;
    const next = () => {
      index++;
      if (index < this.middlewares.length) {
        this.middlewares[index](entry, next);
      } else {
        done();
      }
    };
    this.middlewares[0](entry, next);
  }

  private async drainQueue(): Promise<void> {
    if (!this.transport || !this.transport.connected) return;
    const entries = this.queue.drain(100);
    if (entries.length === 0) return;
    try {
      await this.transport.send(entries);
    } catch {
      // Re-enqueue on failure (best-effort).
      for (const e of entries) {
        this.queue.push(e);
      }
    }
  }

  private startSession(metadata?: Record<string, unknown>): void {
    if (this.sessionStarted) return;
    this.sessionStarted = true;

    const entry: LogEntry = {
      ...this.baseFields('info'),
      type: 'session',
      session_action: 'start',
      ...(metadata ? { tags: this.stringifyTags(metadata) } : {}),
    };
    // Session start bypasses middleware and goes straight to queue.
    this.queue.push(entry);
  }

  private endSession(): void {
    const entry: LogEntry = {
      ...this.baseFields('info'),
      type: 'session',
      session_action: 'end',
    };
    this.queue.push(entry);
  }

  private handleServerMessage(data: unknown): void {
    if (!data || typeof data !== 'object') return;
    const msg = data as Record<string, unknown>;

    // Handle RPC requests from the server/viewer.
    if (msg.type === 'rpc_request' && typeof msg.rpc_method === 'string') {
      const handler = this.rpcHandlers.get(msg.rpc_method);
      if (!handler) {
        // Send error response.
        this.enqueue({
          ...this.baseFields('error'),
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
          this.enqueue({
            ...this.baseFields('info'),
            type: 'rpc',
            rpc_id: msg.rpc_id as string,
            rpc_direction: 'response',
            rpc_method: msg.rpc_method as string,
            rpc_response: result,
          });
        },
        (err: Error) => {
          this.enqueue({
            ...this.baseFields('error'),
            type: 'rpc',
            rpc_id: msg.rpc_id as string,
            rpc_direction: 'error',
            rpc_method: msg.rpc_method as string,
            rpc_error: err.message,
          });
        },
      );
    }
  }
}
