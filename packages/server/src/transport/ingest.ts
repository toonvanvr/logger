import { DataMessage, EventMessage, SessionMessage, type StoredEntry } from '@logger/shared'
import { normalizeData, normalizeEvent, normalizeSession } from '../core/normalizer'
import { isSystemSession } from '../modules/self-logger'
import type { ServerDeps } from './types'

/**
 * Ingest a validated StoredEntry: session tracking, buffer, Loki, WS broadcast.
 */
export function ingest(entry: StoredEntry, deps: ServerDeps): void {
  const { sessionManager, ringBuffer, lokiForwarder, wsHub, storeWriter } = deps

  if (entry.kind === 'session') {
    sessionManager.handleSession(entry)
  }

  const app = entry.application ?? undefined
  sessionManager.getOrCreate(entry.session_id, app)
  sessionManager.incrementLogCount(entry.session_id)

  if (entry.replace) {
    ringBuffer.upsert(entry)
  } else {
    ringBuffer.push(entry)
  }

  if (!isSystemSession(entry.session_id)) {
    if (storeWriter) {
      storeWriter.push([entry])
    } else {
      lokiForwarder.push(entry)
    }
  }

  wsHub.broadcast({ type: 'event', entry })

  // Post-store hooks (logging, metrics, side effects)
  deps.hookManager.runPostStore(entry)
}

/**
 * Parse a raw JSON object by type and ingest via the normalizer pipeline.
 * Returns true if the message was valid and ingested, false otherwise.
 */
export function parseAndIngest(
  parsed: { type?: string;[k: string]: unknown },
  deps: ServerDeps,
): boolean {
  // Pre-validate hooks (redaction, shaping)
  const processed = deps.hookManager.runPreValidate(parsed) as { type?: string;[k: string]: unknown }

  let entry: StoredEntry
  if (processed.type === 'session') {
    const r = SessionMessage.safeParse(processed)
    if (!r.success) return false
    entry = normalizeSession(r.data)
  } else if (processed.type === 'data') {
    const r = DataMessage.safeParse(processed)
    if (!r.success) return false
    entry = normalizeData(r.data)
  } else {
    const r = EventMessage.safeParse(processed)
    if (!r.success) return false
    entry = normalizeEvent(r.data)
  }

  // Post-validate hooks (transformation, enrichment)
  entry = deps.hookManager.runPostValidate(entry)

  ingest(entry, deps)
  return true
}
