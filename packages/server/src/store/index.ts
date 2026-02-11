import type { LokiForwarder } from '../modules/loki-forwarder';
import type { RingBuffer } from '../modules/ring-buffer';
import { LokiStoreReader, LokiStoreWriter } from './adapters/loki-adapter';
import { MemoryStoreReader, MemoryStoreWriter } from './adapters/memory-adapter';
import type { LogStoreReader } from './log-store-reader';
import type { LogStoreWriter } from './log-store-writer';

// ─── Re-exports ──────────────────────────────────────────────────────

export type { LogStoreReader, SessionSummary, StoreQuery, StoreQueryResult } from './log-store-reader';
export type { LogStoreWriter, StoreHealth } from './log-store-writer';

// ─── Factory Config ──────────────────────────────────────────────────

interface StoreFactoryConfig {
  storeBackend: string;
  lokiUrl: string;
}

// ─── Factory Functions ───────────────────────────────────────────────

export function createStoreWriter(
  config: StoreFactoryConfig,
  deps: { lokiForwarder: LokiForwarder },
): LogStoreWriter {
  if (config.storeBackend === 'memory') {
    return new MemoryStoreWriter();
  }

  return new LokiStoreWriter(deps.lokiForwarder);
}

export function createStoreReader(
  config: StoreFactoryConfig,
  deps: { ringBuffer: RingBuffer },
): LogStoreReader {
  if (config.storeBackend === 'memory') {
    return new MemoryStoreReader(deps.ringBuffer);
  }

  return new LokiStoreReader({ lokiUrl: config.lokiUrl });
}
