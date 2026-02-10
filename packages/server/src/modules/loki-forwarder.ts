import type { StoredEntry } from '@logger/shared'

export interface LokiForwarderConfig {
  lokiUrl: string
  batchSize: number
  flushIntervalMs: number
  maxBuffer: number
  retries: number
  environment: string
  /** @internal Base delay for retry backoff in ms. Default: 1000. */
  retryBaseMs?: number
}

type HealthStatus = 'healthy' | 'warning' | 'full'

export class LokiForwarder {
  private buffer: StoredEntry[] = [];
  private flushTimer: Timer
  private health: HealthStatus = 'healthy';
  private consecutiveFailures = 0;
  private readonly cfg: LokiForwarderConfig & { retryBaseMs: number }
  private flushing = false;

  constructor(config: LokiForwarderConfig) {
    this.cfg = { retryBaseMs: 1000, ...config }
    this.flushTimer = setInterval(() => this.flush(), this.cfg.flushIntervalMs)
  }

  /** Add entry to buffer for async forwarding. Drops if buffer full. */
  push(entry: StoredEntry): void {
    if (this.buffer.length >= this.cfg.maxBuffer) {
      console.warn('[LokiForwarder] Buffer full, dropping entry')
      this.updateHealth()
      return
    }

    this.buffer.push(entry)
    this.updateHealth()

    if (this.buffer.length >= this.cfg.batchSize) {
      this.flush()
    }
  }

  /** Force flush the buffer to Loki. */
  async flush(): Promise<void> {
    if (this.buffer.length === 0 || this.flushing) return

    this.flushing = true
    const entries = this.buffer.splice(0)

    try {
      const groups = this.groupByLabels(entries)
      for (const [, groupEntries] of groups) {
        await this.sendBatch(groupEntries)
      }
    } finally {
      this.flushing = false
      this.updateHealth()
    }
  }

  /** Get health status. */
  getHealth(): {
    status: HealthStatus
    bufferSize: number
    bufferMax: number
    consecutiveFailures: number
  } {
    return {
      status: this.health,
      bufferSize: this.buffer.length,
      bufferMax: this.cfg.maxBuffer,
      consecutiveFailures: this.consecutiveFailures,
    }
  }

  /** Shutdown cleanly — clears timer and flushes remaining entries. */
  async shutdown(): Promise<void> {
    clearInterval(this.flushTimer)
    await this.flush()
  }

  /** Batch and send entries (single label group) to Loki. */
  private async sendBatch(entries: StoredEntry[]): Promise<boolean> {
    if (entries.length === 0) return true
    const labels = this.extractLabels(entries[0]!)
    const values = entries.map((entry) => [
      toNanoseconds(entry.timestamp),
      JSON.stringify(entry),
      this.extractStructuredMetadata(entry),
    ])

    const payload = {
      streams: [{ stream: labels, values }],
    }

    for (let attempt = 0; attempt < this.cfg.retries; attempt++) {
      try {
        const res = await fetch(`${this.cfg.lokiUrl}/loki/api/v1/push`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(payload),
        })

        if (res.ok) {
          this.consecutiveFailures = 0
          this.updateHealth()
          return true
        }
      } catch {
        // Network error — fall through to retry
      }

      if (attempt < this.cfg.retries - 1) {
        await sleep(this.cfg.retryBaseMs * 2 ** attempt)
      }
    }

    this.consecutiveFailures++
    this.updateHealth()
    return false
  }

  /** Group entries into Loki streams by label set {app, severity, environment}. */
  private groupByLabels(entries: StoredEntry[]): Map<string, StoredEntry[]> {
    const groups = new Map<string, StoredEntry[]>()
    for (const entry of entries) {
      const key = labelKey(entry, this.cfg.environment)
      const group = groups.get(key)
      if (group) {
        group.push(entry)
      } else {
        groups.set(key, [entry])
      }
    }
    return groups
  }

  private extractLabels(entry: StoredEntry): Record<string, string> {
    return {
      app: entry.application?.name ?? 'unknown',
      severity: entry.severity,
      environment: this.cfg.environment,
    }
  }

  /** Extract structured metadata for Loki 3.0. */
  private extractStructuredMetadata(entry: StoredEntry): Record<string, string> {
    const meta: Record<string, string> = {
      session: entry.session_id,
    }
    if (entry.kind) meta.kind = entry.kind
    if (entry.tag) meta.tag = entry.tag
    const widgetType = (entry.widget as any)?.type
    if (widgetType) meta.widget_type = widgetType

    return meta
  }

  private updateHealth(): void {
    if (this.buffer.length >= this.cfg.maxBuffer) {
      this.health = 'full'
    } else if (
      this.buffer.length >= this.cfg.maxBuffer * 0.8 ||
      this.consecutiveFailures >= 3
    ) {
      this.health = 'warning'
    } else {
      this.health = 'healthy'
    }
  }
}

function labelKey(entry: StoredEntry, environment: string): string {
  return `${entry.application?.name ?? 'unknown'}|${entry.severity}|${environment}`
}

function toNanoseconds(isoTimestamp: string): string {
  const ms = new Date(isoTimestamp).getTime()
  return `${ms}000000`
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms))
}
