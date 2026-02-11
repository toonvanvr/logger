import type { QueuedMessage } from './logger-types'

/**
 * Internal circular-buffer queue for outgoing messages.
 * Drops entries when the estimated byte budget is exceeded.
 */
export class LogQueue {
  private buffer: QueuedMessage[] = [];
  private _byteEstimate = 0;
  private readonly maxBytes: number

  constructor(maxBytes: number = 8 * 1024 * 1024) {
    this.maxBytes = maxBytes
  }

  /** Approximate byte size of a serialised message. */
  private estimateSize(entry: QueuedMessage): number {
    return JSON.stringify(entry).length * 2
  }

  /**
   * Push a message onto the queue.
   * @returns `true` if accepted, `false` if dropped (queue full).
   */
  push(entry: QueuedMessage): boolean {
    const size = this.estimateSize(entry)
    if (this._byteEstimate + size > this.maxBytes) {
      return false
    }
    this.buffer.push(entry)
    this._byteEstimate += size
    return true
  }

  /**
   * Drain up to `maxCount` messages from the front of the queue.
   * Returns an empty array when the queue is empty.
   */
  drain(maxCount?: number): QueuedMessage[] {
    const count = maxCount !== undefined ? Math.min(maxCount, this.buffer.length) : this.buffer.length
    if (count === 0) return []

    const drained = this.buffer.splice(0, count)
    this._byteEstimate = this.buffer.reduce((acc, e) => acc + this.estimateSize(e), 0)
    return drained
  }

  /** Number of messages currently queued. */
  get size(): number {
    return this.buffer.length
  }

  /** Estimated total byte size of all queued messages. */
  get byteEstimate(): number {
    return this._byteEstimate
  }

  /** Remove all messages from the queue. */
  clear(): void {
    this.buffer = []
    this._byteEstimate = 0
  }
}
