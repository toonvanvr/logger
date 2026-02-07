import type { LogEntry } from '@logger/shared';

export interface RingBufferQueryOptions {
  sessionId?: string;
  from?: string;
  to?: string;
  severity?: string;
  limit?: number;
  cursor?: number;
}

export interface RingBufferQueryResult {
  entries: LogEntry[];
  cursor: number | null;
}

const ID_INDEX_MAX = 100_000;

function estimateBytes(entry: LogEntry): number {
  const e = entry as Record<string, unknown>;
  if (entry.type === 'text' && !e.exception && !e.tags) {
    return 200 + ((entry.text?.length ?? 0) * 2);
  }
  return JSON.stringify(entry).length * 2 + 100;
}

export class RingBuffer {
  private entries: (LogEntry | null)[];
  private entrySizes: (number | null)[];
  private head = 0;
  private count = 0;
  private bytesUsed = 0;
  private readonly maxEntries: number;
  private readonly maxBytes: number;

  /** ID → slot index for O(1) lookup */
  private idIndex = new Map<string, number>();
  /** Insertion-order tracking for LRU eviction of ID index */
  private idInsertionOrder: string[] = [];

  constructor(maxEntries: number, maxBytes: number) {
    this.maxEntries = maxEntries;
    this.maxBytes = maxBytes;
    this.entries = new Array<LogEntry | null>(maxEntries).fill(null);
    this.entrySizes = new Array<number | null>(maxEntries).fill(null);
  }

  get size(): number {
    return this.count;
  }

  get byteEstimate(): number {
    return this.bytesUsed;
  }

  push(entry: LogEntry): void {
    const size = estimateBytes(entry);

    // Evict oldest entries if over capacity
    while (this.count > 0 && (this.count >= this.maxEntries || this.bytesUsed + size > this.maxBytes)) {
      this.evictOldest();
    }

    const slot = this.head;
    this.entries[slot] = entry;
    this.entrySizes[slot] = size;
    this.bytesUsed += size;
    this.count++;
    this.head = (this.head + 1) % this.maxEntries;

    // Update ID index
    this.indexId(entry.id, slot);
  }

  upsert(entry: LogEntry): void {
    if (entry.replace && this.idIndex.has(entry.id)) {
      const slot = this.idIndex.get(entry.id)!;
      const oldSize = this.entrySizes[slot] ?? 0;
      const newSize = estimateBytes(entry);

      this.entries[slot] = entry;
      this.entrySizes[slot] = newSize;
      this.bytesUsed += newSize - oldSize;
    } else {
      this.push(entry);
    }
  }

  get(id: string): LogEntry | undefined {
    const slot = this.idIndex.get(id);
    if (slot === undefined) return undefined;
    return this.entries[slot] ?? undefined;
  }

  query(options: RingBufferQueryOptions): RingBufferQueryResult {
    const limit = options.limit ?? 100;
    const startCursor = options.cursor ?? 0;
    const results: LogEntry[] = [];

    // Walk entries from oldest to newest
    let scanned = 0;
    let skipped = 0;
    let lastIndex = -1;

    for (let i = 0; i < this.count; i++) {
      const slot = this.slotAt(i);
      const entry = this.entries[slot];
      if (!entry) continue;

      // Apply cursor: skip entries before cursor position
      if (skipped < startCursor) {
        skipped++;
        continue;
      }

      // Apply filters
      if (options.sessionId && entry.session_id !== options.sessionId) continue;
      if (options.severity && entry.severity !== options.severity) continue;
      if (options.from && entry.timestamp < options.from) continue;
      if (options.to && entry.timestamp > options.to) continue;

      results.push(entry);
      scanned++;
      lastIndex = skipped + scanned;

      if (results.length >= limit) break;
    }

    return {
      entries: results,
      cursor: results.length >= limit ? startCursor + skipped + scanned - startCursor : null,
    };
  }

  private slotAt(logicalIndex: number): number {
    // oldest entry is at (head - count + logicalIndex) mod maxEntries
    return ((this.head - this.count + logicalIndex) % this.maxEntries + this.maxEntries) % this.maxEntries;
  }

  private evictOldest(): void {
    const oldestSlot = this.slotAt(0);
    const oldEntry = this.entries[oldestSlot];
    const oldSize = this.entrySizes[oldestSlot] ?? 0;

    if (oldEntry) {
      this.idIndex.delete(oldEntry.id);
    }

    this.entries[oldestSlot] = null;
    this.entrySizes[oldestSlot] = null;
    this.bytesUsed -= oldSize;
    this.count--;
  }

  private indexId(id: string, slot: number): void {
    // If already in index, remove from insertion order
    if (this.idIndex.has(id)) {
      const idx = this.idInsertionOrder.indexOf(id);
      if (idx !== -1) this.idInsertionOrder.splice(idx, 1);
    }

    this.idIndex.set(id, slot);
    this.idInsertionOrder.push(id);

    // LRU eviction of ID index entries
    while (this.idInsertionOrder.length > ID_INDEX_MAX) {
      const evictId = this.idInsertionOrder.shift()!;
      // Only delete from idIndex if it still points to the same old entry
      // (the slot may have been reused)
      const evictSlot = this.idIndex.get(evictId);
      if (evictSlot !== undefined) {
        const slotEntry = this.entries[evictSlot];
        if (!slotEntry || slotEntry.id === evictId) {
          this.idIndex.delete(evictId);
        }
      }
    }
  }
}
