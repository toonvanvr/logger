import type { StoredEntry } from '@logger/shared'

// ─── Query Types ─────────────────────────────────────────────────────

export interface StoreQuery {
  sessionId?: string
  from?: string
  to?: string
  severity?: string
  search?: string
  limit: number
  cursor?: string
  direction: 'forward' | 'backward'
}

export interface StoreQueryResult {
  entries: StoredEntry[]
  cursor: string | null
  source: string
}

// ─── Session Summary ─────────────────────────────────────────────────

export interface SessionSummary {
  sessionId: string
  firstSeen: string
  lastSeen: string
  entryCount: number
}

// ─── LogStoreReader Interface ────────────────────────────────────────

export interface LogStoreReader {
  /** Paginated filtered query. */
  query(filter: StoreQuery): Promise<StoreQueryResult>

  /** List sessions known to the store. */
  getSessions(): Promise<SessionSummary[]>

  /** Fetch entries in a time range. */
  getRange(
    from: string,
    to: string,
    opts?: { sessionId?: string; limit?: number },
  ): Promise<StoredEntry[]>

  /** Check if the backing store is reachable. */
  isAvailable(): Promise<boolean>
}
