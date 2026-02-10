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
}

/**
 * Parse a raw JSON object by type and ingest via the normalizer pipeline.
 * Returns true if the message was valid and ingested, false otherwise.
 */
export function parseAndIngest(
  parsed: { type?: string;[k: string]: unknown },
  deps: ServerDeps,
): boolean {
  if (parsed.type === 'session') {
    const r = SessionMessage.safeParse(parsed)
    if (!r.success) return false
    ingest(normalizeSession(r.data), deps)
    return true
  }
  if (parsed.type === 'data') {
    const r = DataMessage.safeParse(parsed)
    if (!r.success) return false
    ingest(normalizeData(r.data), deps)
    return true
  }
  const r = EventMessage.safeParse(parsed)
  if (!r.success) return false
  ingest(normalizeEvent(r.data), deps)
  return true
}
