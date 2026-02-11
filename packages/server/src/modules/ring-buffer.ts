import type { StoredEntry } from '@logger/shared'

export interface RingBufferQueryOptions {
  sessionId?: string
  from?: string
  to?: string
  severity?: string
  limit?: number
  cursor?: number
}

export interface RingBufferQueryResult {
  entries: StoredEntry[]
  cursor: number | null
}

const ID_INDEX_MAX = 100_000

function estimateBytes(entry: StoredEntry): number {
  if (entry.kind === 'event' && !entry.exception && !entry.labels) {
    return 200 + ((entry.message?.length ?? 0) * 2)
  }
  return JSON.stringify(entry).length * 2 + 100
}

export class RingBuffer {
  private entries: (StoredEntry | null)[]
  private entrySizes: (number | null)[]
  private head = 0;
  private count = 0;
  private bytesUsed = 0;
  private readonly maxEntries: number
  private readonly maxBytes: number

  /** ID → slot index for O(1) lookup. Map insertion order doubles as LRU queue. */
  private idIndex = new Map<string, number>();

  constructor(maxEntries: number, maxBytes: number) {
    this.maxEntries = maxEntries
    this.maxBytes = maxBytes
    this.entries = new Array<StoredEntry | null>(maxEntries).fill(null)
    this.entrySizes = new Array<number | null>(maxEntries).fill(null)
  }

  get size(): number {
    return this.count
  }

  get byteEstimate(): number {
    return this.bytesUsed
  }

  push(entry: StoredEntry): void {
    const size = estimateBytes(entry)

    while (this.count > 0 && (this.count >= this.maxEntries || this.bytesUsed + size > this.maxBytes)) {
      this.evictOldest()
    }

    const slot = this.head
    this.entries[slot] = entry
    this.entrySizes[slot] = size
    this.bytesUsed += size
    this.count++
    this.head = (this.head + 1) % this.maxEntries

    this.indexId(entry.id, slot)
  }

  upsert(entry: StoredEntry): void {
    if (entry.replace && this.idIndex.has(entry.id)) {
      const slot = this.idIndex.get(entry.id)!
      const oldSize = this.entrySizes[slot] ?? 0
      const newSize = estimateBytes(entry)

      this.entries[slot] = entry
      this.entrySizes[slot] = newSize
      this.bytesUsed += newSize - oldSize
    } else {
      this.push(entry)
    }
  }

  get(id: string): StoredEntry | undefined {
    const slot = this.idIndex.get(id)
    if (slot === undefined) return undefined
    return this.entries[slot] ?? undefined
  }

  query(options: RingBufferQueryOptions): RingBufferQueryResult {
    const limit = options.limit ?? 100
    const startCursor = options.cursor ?? 0
    const results: StoredEntry[] = []

    let scanned = 0
    let skipped = 0
    let lastIndex = -1

    for (let i = 0; i < this.count; i++) {
      const slot = this.slotAt(i)
      const entry = this.entries[slot]
      if (!entry) continue

      if (skipped < startCursor) {
        skipped++
        continue
      }

      if (options.sessionId && entry.session_id !== options.sessionId) continue
      if (options.severity && entry.severity !== options.severity) continue
      if (options.from && entry.timestamp < options.from) continue
      if (options.to && entry.timestamp > options.to) continue

      results.push(entry)
      scanned++
      lastIndex = skipped + scanned

      if (results.length >= limit) break
    }

    return {
      entries: results,
      cursor: results.length >= limit ? startCursor + skipped + scanned - startCursor : null,
    }
  }

  private slotAt(logicalIndex: number): number {
    // oldest entry is at (head - count + logicalIndex) mod maxEntries
    return ((this.head - this.count + logicalIndex) % this.maxEntries + this.maxEntries) % this.maxEntries
  }

  private evictOldest(): void {
    const oldestSlot = this.slotAt(0)
    const oldEntry = this.entries[oldestSlot]
    const oldSize = this.entrySizes[oldestSlot] ?? 0

    if (oldEntry) {
      this.idIndex.delete(oldEntry.id)
    }

    this.entries[oldestSlot] = null
    this.entrySizes[oldestSlot] = null
    this.bytesUsed -= oldSize
    this.count--
  }

  /** Clear all entries and reset state for clean shutdown. */
  shutdown(): void {
    this.entries.fill(null)
    this.entrySizes.fill(null)
    this.head = 0
    this.count = 0
    this.bytesUsed = 0
    this.idIndex.clear()
  }

  private indexId(id: string, slot: number): void {
    // Map.delete + Map.set moves key to end (insertion order)
    this.idIndex.delete(id)
    this.idIndex.set(id, slot)

    // LRU eviction of ID index entries
    while (this.idIndex.size > ID_INDEX_MAX) {
      const oldestKey = this.idIndex.keys().next().value
      if (oldestKey === undefined) break
      // Only delete if it still points to a valid entry
      const evictSlot = this.idIndex.get(oldestKey)!
      const slotEntry = this.entries[evictSlot]
      if (!slotEntry || slotEntry.id === oldestKey) {
        this.idIndex.delete(oldestKey)
      } else {
        // Slot was reused, just remove the stale index entry
        this.idIndex.delete(oldestKey)
      }
    }
  }
}
