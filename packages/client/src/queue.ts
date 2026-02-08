import type { LogEntry } from '@logger/shared';

/**
 * Internal circular-buffer queue for outgoing log entries.
 * Drops entries when the estimated byte budget is exceeded.
 */
export class LogQueue {
  private buffer: LogEntry[] = [];
  private _byteEstimate = 0;
  private readonly maxBytes: number;

  constructor(maxBytes: number = 8 * 1024 * 1024) {
    this.maxBytes = maxBytes;
  }

  /** Approximate byte size of a serialised entry. */
  private estimateSize(entry: LogEntry): number {
    // Fast heuristic: JSON.stringify length × 2 (UTF-16 chars → bytes).
    // We cache nothing — the queue is transient.
    return JSON.stringify(entry).length * 2;
  }

  /**
   * Push an entry onto the queue.
   * @returns `true` if accepted, `false` if dropped (queue full).
   */
  push(entry: LogEntry): boolean {
    const size = this.estimateSize(entry);
    if (this._byteEstimate + size > this.maxBytes) {
      return false;
    }
    this.buffer.push(entry);
    this._byteEstimate += size;
    return true;
  }

  /**
   * Drain up to `maxCount` entries from the front of the queue.
   * Returns an empty array when the queue is empty.
   */
  drain(maxCount?: number): LogEntry[] {
    const count = maxCount !== undefined ? Math.min(maxCount, this.buffer.length) : this.buffer.length;
    if (count === 0) return [];

    const drained = this.buffer.splice(0, count);
    // Recalculate byte estimate for remaining entries.
    this._byteEstimate = this.buffer.reduce((acc, e) => acc + this.estimateSize(e), 0);
    return drained;
  }

  /** Number of entries currently queued. */
  get size(): number {
    return this.buffer.length;
  }

  /** Estimated total byte size of all queued entries. */
  get byteEstimate(): number {
    return this._byteEstimate;
  }

  /** Remove all entries from the queue. */
  clear(): void {
    this.buffer = [];
    this._byteEstimate = 0;
  }
}
