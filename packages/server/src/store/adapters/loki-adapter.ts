import type { StoredEntry } from '@logger/shared'
import type { LokiForwarder } from '../../modules/loki-forwarder'
import type { LogStoreReader, SessionSummary, StoreQuery, StoreQueryResult } from '../log-store-reader'
import type { LogStoreWriter, StoreHealth } from '../log-store-writer'

// ─── Loki Store Writer ──────────────────────────────────────────────

export class LokiStoreWriter implements LogStoreWriter {
  constructor(private readonly forwarder: LokiForwarder) { }

  async push(entries: StoredEntry[]): Promise<void> {
    for (const entry of entries) {
      this.forwarder.push(entry)
    }
  }

  async flush(): Promise<void> {
    await this.forwarder.flush()
  }

  async shutdown(): Promise<void> {
    await this.forwarder.shutdown()
  }

  getHealth(): StoreHealth {
    const h = this.forwarder.getHealth()
    const status =
      h.status === 'healthy' ? 'healthy' :
        h.status === 'warning' ? 'degraded' :
          'degraded'
    return { status, bufferSize: h.bufferSize, errors: h.consecutiveFailures }
  }
}

// ─── Loki Store Reader ──────────────────────────────────────────────

interface LokiReaderConfig {
  lokiUrl: string
}

export class LokiStoreReader implements LogStoreReader {
  private readonly lokiUrl: string

  constructor(config: LokiReaderConfig) {
    this.lokiUrl = config.lokiUrl
  }

  async query(filter: StoreQuery): Promise<StoreQueryResult> {
    const params = new URLSearchParams()
    params.set('query', this.buildLogQL(filter))
    params.set('limit', String(filter.limit))
    params.set('direction', filter.direction === 'backward' ? 'BACKWARD' : 'FORWARD')

    if (filter.from) {
      params.set('start', String(new Date(filter.from).getTime() * 1_000_000))
    }
    if (filter.to) {
      params.set('end', String(new Date(filter.to).getTime() * 1_000_000))
    }
    if (filter.cursor) {
      try {
        const decoded = JSON.parse(atob(filter.cursor)) as { ts: string }
        if (filter.direction === 'forward') {
          params.set('start', decoded.ts)
        } else {
          params.set('end', decoded.ts)
        }
      } catch {
        // Invalid cursor — ignore and use from/to
      }
    }

    const url = `${this.lokiUrl}/loki/api/v1/query_range?${params}`
    const res = await fetch(url)
    if (!res.ok) {
      return { entries: [], cursor: null, source: 'loki' }
    }

    const body = (await res.json()) as LokiQueryResponse
    const entries = this.parseStreams(body)

    let cursor: string | null = null
    if (entries.length >= filter.limit && entries.length > 0) {
      const last = entries[entries.length - 1]!
      cursor = btoa(JSON.stringify({ ts: String(new Date(last.timestamp).getTime() * 1_000_000) }))
    }

    return { entries, cursor, source: 'loki' }
  }

  async getSessions(): Promise<SessionSummary[]> {
    const url = `${this.lokiUrl}/loki/api/v1/label/session/values`
    try {
      const res = await fetch(url)
      if (!res.ok) return []
      const body = (await res.json()) as { data: string[] }
      return (body.data ?? []).map((sessionId) => ({
        sessionId,
        firstSeen: '',
        lastSeen: '',
        entryCount: 0,
      }))
    } catch {
      return []
    }
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
    try {
      const res = await fetch(`${this.lokiUrl}/ready`)
      return res.ok
    } catch {
      return false
    }
  }

  // ─── Private Helpers ─────────────────────────────────────────────

  private buildLogQL(filter: StoreQuery): string {
    const selectors: string[] = []

    if (filter.sessionId) {
      selectors.push(`session="${filter.sessionId}"`)
    }
    if (filter.severity) {
      selectors.push(`severity="${filter.severity}"`)
    }

    const labelExpr = selectors.length > 0 ? selectors.join(', ') : 'app=~".+"'
    let query = `{${labelExpr}}`

    if (filter.search) {
      query += ` |~ \`${filter.search}\``
    }

    return query
  }

  private parseStreams(body: LokiQueryResponse): StoredEntry[] {
    const entries: StoredEntry[] = []

    if (body.status !== 'success' || !body.data?.result) return entries

    for (const stream of body.data.result) {
      for (const [, line] of stream.values) {
        try {
          entries.push(JSON.parse(line) as StoredEntry)
        } catch {
          // Skip unparseable lines
        }
      }
    }

    return entries
  }
}

// ─── Loki Response Types ────────────────────────────────────────────

interface LokiQueryResponse {
  status: string
  data?: {
    resultType: string
    result: Array<{
      stream: Record<string, string>
      values: Array<[string, string]>
    }>
  }
}
