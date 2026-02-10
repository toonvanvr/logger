import { mkdir, rm } from 'node:fs/promises';
import { join } from 'node:path';

// ─── Types ───────────────────────────────────────────────────────────

export interface StoredFile {
  data: Buffer;
  mimeType: string;
  label?: string;
}

interface FileRecord {
  sessionId: string;
  refId: string;
  mimeType: string;
  label?: string;
  size: number;
  createdAt: number;
}

// ─── MIME → Extension mapping ────────────────────────────────────────

const MIME_TO_EXT: Record<string, string> = {
  'image/png': 'png',
  'image/jpeg': 'jpg',
  'image/gif': 'gif',
  'image/webp': 'webp',
  'image/svg+xml': 'svg',
  'image/bmp': 'bmp',
  'image/tiff': 'tiff',
  'application/pdf': 'pdf',
  'application/json': 'json',
  'text/plain': 'txt',
  'text/html': 'html',
  'application/octet-stream': 'bin',
};

function extForMime(mimeType: string): string {
  return MIME_TO_EXT[mimeType] ?? 'bin';
}

// ─── File Store ──────────────────────────────────────────────────────

export class FileStore {
  private records = new Map<string, FileRecord>();
  private totalBytes = 0;
  private readonly storePath: string;
  private readonly maxBytes: number;

  constructor(options: { storePath: string; maxBytes: number }) {
    this.storePath = options.storePath;
    this.maxBytes = options.maxBytes;
  }

  /**
   * Store data to disk. Returns a reference ID.
   */
  async store(
    sessionId: string,
    data: Buffer | Uint8Array,
    mimeType: string,
    label?: string,
  ): Promise<string> {
    const refId = crypto.randomUUID();
    const ext = extForMime(mimeType);
    const dir = join(this.storePath, sessionId);
    const filePath = join(dir, `${refId}.${ext}`);

    await mkdir(dir, { recursive: true });
    await Bun.write(filePath, data);

    const size = data.byteLength;
    this.records.set(refId, {
      sessionId,
      refId,
      mimeType,
      label,
      size,
      createdAt: Date.now(),
    });
    this.totalBytes += size;

    return refId;
  }

  /**
   * Retrieve a stored file by reference ID.
   */
  async retrieve(ref: string): Promise<StoredFile | null> {
    const record = this.records.get(ref);
    if (!record) return null;

    const ext = extForMime(record.mimeType);
    const filePath = join(this.storePath, record.sessionId, `${ref}.${ext}`);
    const file = Bun.file(filePath);

    if (!(await file.exists())) {
      // Record exists but file is gone — clean up record
      this.records.delete(ref);
      this.totalBytes -= record.size;
      return null;
    }

    const arrayBuffer = await file.arrayBuffer();
    return {
      data: Buffer.from(arrayBuffer),
      mimeType: record.mimeType,
      label: record.label,
    };
  }

  /**
   * Delete a single file by reference ID.
   */
  async delete(ref: string): Promise<void> {
    const record = this.records.get(ref);
    if (!record) return;

    const ext = extForMime(record.mimeType);
    const filePath = join(this.storePath, record.sessionId, `${ref}.${ext}`);

    try {
      await rm(filePath);
    } catch {
      // File may already be gone
    }

    this.totalBytes -= record.size;
    this.records.delete(ref);
  }

  /**
   * Delete all files for a given session.
   */
  async cleanupSession(sessionId: string): Promise<void> {
    const toDelete: string[] = [];
    for (const [refId, record] of this.records) {
      if (record.sessionId === sessionId) {
        toDelete.push(refId);
      }
    }

    for (const refId of toDelete) {
      await this.delete(refId);
    }

    // Remove the session directory
    const dir = join(this.storePath, sessionId);
    try {
      await rm(dir, { recursive: true });
    } catch {
      // Directory may not exist
    }
  }

  /**
   * Get current usage stats.
   */
  getUsage(): { totalBytes: number; fileCount: number } {
    return {
      totalBytes: this.totalBytes,
      fileCount: this.records.size,
    };
  }

  /**
   * Enforce size limit by deleting oldest files until under maxBytes.
   */
  async enforceLimit(): Promise<void> {
    if (this.totalBytes <= this.maxBytes) return;

    // Sort records by creation time ascending (oldest first)
    const sorted = Array.from(this.records.values()).sort(
      (a, b) => a.createdAt - b.createdAt,
    );

    for (const record of sorted) {
      if (this.totalBytes <= this.maxBytes) break;
      await this.delete(record.refId);
    }
  }

  /**
   * Lifecycle shutdown (no resources to release).
   */
  shutdown(): void {
    /* no resources to release */
  }
}
