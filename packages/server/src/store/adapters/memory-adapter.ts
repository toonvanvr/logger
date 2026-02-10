import type { StoredEntry } from '@logger/shared'
import type { RingBuffer } from '../../modules/ring-buffer'
import type { LogStoreReader, SessionSummary, StoreQuery, StoreQueryResult } from '../log-store-reader'
import type { LogStoreWriter, StoreHealth } from '../log-store-writer'

// ─── Memory Store Writer ────────────────────────────────────────────

/** No-op writer — ring buffer already stores entries via ingest pipeline. */
export class MemoryStoreWriter implements LogStoreWriter {
  async push(_entries: StoredEntry[]): Promise<void> {
    // No-op: ring buffer handles storage in the ingest path
  }

  async flush(): Promise<void> {
    // No-op
  }

  async shutdown(): Promise<void> {
    // No-op
  }

  getHealth(): StoreHealth {
    return { status: 'healthy', bufferSize: 0, errors: 0 }
  }
}

// ─── Memory Store Reader ────────────────────────────────────────────

/** Reader that wraps the ring buffer's query method. */
export class MemoryStoreReader implements LogStoreReader {
  constructor(private readonly ringBuffer: RingBuffer) { }

  async query(filter: StoreQuery): Promise<StoreQueryResult> {
    const cursor = filter.cursor ? parseInt(filter.cursor, 10) : undefined

    const result = this.ringBuffer.query({
      sessionId: filter.sessionId,
      from: filter.from,
      to: filter.to,
      severity: filter.severity,
      limit: filter.limit,
      cursor: Number.isFinite(cursor) ? cursor : undefined,
    })

    return {
      entries: result.entries,
      cursor: result.cursor !== null ? String(result.cursor) : null,
      source: 'memory',
    }
  }

  async getSessions(): Promise<SessionSummary[]> {
    // Ring buffer doesn't track sessions — return empty
    return []
  }

  async getRange(
    from: string,
    to: string,
    opts?: { sessionId?: string; limit?: number },
  ): Promise<StoredEntry[]> {
    const result = await this.query({
      from,
      to,
      sessionId: opts?.sessionId,
      limit: opts?.limit ?? 1000,
      direction: 'forward',
    })
    return result.entries
  }

  async isAvailable(): Promise<boolean> {
    return true
  }
}
