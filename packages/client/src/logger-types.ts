import type { LogEntry } from '@logger/shared';
import type { TransportType } from './transport/auto.js';
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

// ─── Middleware chain runner ─────────────────────────────────────────

export function runMiddlewareChain(
  middlewares: Middleware[],
  entry: LogEntry,
  done: () => void,
): void {
  if (middlewares.length === 0) {
    done();
    return;
  }

  let index = 0;
  const next = () => {
    index++;
    if (index < middlewares.length) {
      middlewares[index](entry, next);
    } else {
      done();
    }
  };
  middlewares[0](entry, next);
}
