import { afterAll, beforeAll, describe, expect, it } from 'bun:test';
import { mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { FileStore } from './file-store';

// ─── Tests ───────────────────────────────────────────────────────────

describe('FileStore', () => {
  let tempDir: string;

  beforeAll(async () => {
    tempDir = await mkdtemp(join(tmpdir(), 'logger-filestore-test-'));
  });

  afterAll(async () => {
    await rm(tempDir, { recursive: true, force: true });
  });

  it('stores and retrieves a file', async () => {
    const store = new FileStore({ storePath: tempDir, maxBytes: 10 * 1024 * 1024 });
    const data = Buffer.from('hello world');
    const ref = await store.store('sess-1', data, 'text/plain', 'greeting');

    expect(ref).toBeTruthy();
    expect(typeof ref).toBe('string');

    const result = await store.retrieve(ref);
    expect(result).not.toBeNull();
    expect(result!.data.toString()).toBe('hello world');
    expect(result!.mimeType).toBe('text/plain');
    expect(result!.label).toBe('greeting');
  });

  it('cleans up session files', async () => {
    const store = new FileStore({ storePath: tempDir, maxBytes: 10 * 1024 * 1024 });

    const ref1 = await store.store('sess-cleanup', Buffer.from('file1'), 'image/png');
    const ref2 = await store.store('sess-cleanup', Buffer.from('file2'), 'image/jpeg');
    const ref3 = await store.store('sess-other', Buffer.from('file3'), 'image/gif');

    expect(store.getUsage().fileCount).toBe(3);

    await store.cleanupSession('sess-cleanup');

    expect(await store.retrieve(ref1)).toBeNull();
    expect(await store.retrieve(ref2)).toBeNull();
    expect(await store.retrieve(ref3)).not.toBeNull();
    expect(store.getUsage().fileCount).toBe(1);
  });

  it('tracks usage correctly', async () => {
    const store = new FileStore({ storePath: tempDir, maxBytes: 10 * 1024 * 1024 });
    const data1 = Buffer.alloc(1000, 'a');
    const data2 = Buffer.alloc(2000, 'b');

    await store.store('sess-u', data1, 'application/octet-stream');
    await store.store('sess-u', data2, 'application/octet-stream');

    const usage = store.getUsage();
    expect(usage.fileCount).toBe(2);
    expect(usage.totalBytes).toBe(3000);
  });

  it('enforces size limit by deleting oldest files', async () => {
    const store = new FileStore({ storePath: tempDir, maxBytes: 2500 });

    // Store 3 files of 1000 bytes each (total 3000 > 2500)
    const ref1 = await store.store('sess-limit', Buffer.alloc(1000, 'a'), 'text/plain');
    // Small delay to ensure different createdAt timestamps
    await Bun.sleep(5);
    const ref2 = await store.store('sess-limit', Buffer.alloc(1000, 'b'), 'text/plain');
    await Bun.sleep(5);
    const ref3 = await store.store('sess-limit', Buffer.alloc(1000, 'c'), 'text/plain');

    expect(store.getUsage().totalBytes).toBe(3000);

    await store.enforceLimit();

    // Should have deleted oldest (ref1) to get under 2500
    expect(store.getUsage().totalBytes).toBe(2000);
    expect(await store.retrieve(ref1)).toBeNull();
    expect(await store.retrieve(ref2)).not.toBeNull();
    expect(await store.retrieve(ref3)).not.toBeNull();
  });

  it('handles missing file gracefully', async () => {
    const store = new FileStore({ storePath: tempDir, maxBytes: 10 * 1024 * 1024 });

    const result = await store.retrieve('nonexistent-ref');
    expect(result).toBeNull();
  });

  it('deletes a single file', async () => {
    const store = new FileStore({ storePath: tempDir, maxBytes: 10 * 1024 * 1024 });
    const ref = await store.store('sess-del', Buffer.from('deleteme'), 'text/plain');

    expect(store.getUsage().fileCount).toBe(1);
    await store.delete(ref);
    expect(store.getUsage().fileCount).toBe(0);
    expect(await store.retrieve(ref)).toBeNull();
  });
});
