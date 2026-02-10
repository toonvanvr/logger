import type { StoredEntry } from '@logger/shared'

// ─── Store Health ────────────────────────────────────────────────────

export interface StoreHealth {
  status: 'healthy' | 'degraded' | 'unavailable'
  bufferSize: number
  errors: number
}

// ─── LogStoreWriter Interface ────────────────────────────────────────

export interface LogStoreWriter {
  /** Batch write entries to the backing store. */
  push(entries: StoredEntry[]): Promise<void>

  /** Force flush any pending writes. */
  flush(): Promise<void>

  /** Graceful shutdown — flush remaining entries and release resources. */
  shutdown(): Promise<void>

  /** Current health / backpressure status. */
  getHealth(): StoreHealth
}
