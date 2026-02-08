import type { LogEntry } from '@logger/shared';
import { isSystemSession } from '../modules/self-logger';
import type { ServerDeps } from './types';

/**
 * Process raw input through hooks + pipeline.
 * Does NOT ingest — caller decides (allows rate limit checks between steps).
 */
export function processEntry(
  raw: unknown,
  deps: ServerDeps,
): { ok: true; entry: LogEntry } | { ok: false; error: string } {
  const { pipeline, hookManager } = deps;

  const hooked = hookManager.runPreValidate(raw);
  const result = pipeline(hooked);
  if (!result.ok) {
    return { ok: false, error: result.error };
  }

  const entry = hookManager.runPostValidate(result.entry);
  return { ok: true, entry };
}

/**
 * Ingest a validated entry: session tracking, buffer, Loki, WS broadcast, hooks.
 */
export function ingestEntry(entry: LogEntry, deps: ServerDeps): void {
  const { sessionManager, ringBuffer, lokiForwarder, wsHub, hookManager, storeWriter } = deps;

  if (entry.type === 'session') {
    sessionManager.handleSessionAction(entry);
  }

  sessionManager.getOrCreate(entry.session_id, entry.application);
  sessionManager.incrementLogCount(entry.session_id);

  if (entry.replace) {
    ringBuffer.upsert(entry);
  } else {
    ringBuffer.push(entry);
  }

  if (!isSystemSession(entry.session_id)) {
    if (storeWriter) {
      storeWriter.push([entry]);
    } else {
      lokiForwarder.push(entry);
    }
  }

  wsHub.broadcast({ type: 'log', entry });
  hookManager.runPostStore(entry);
}
