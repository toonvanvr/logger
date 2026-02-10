import type { StoredEntry } from '@logger/shared'
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

  wsHub.broadcast({ type: 'log', entry })
}
