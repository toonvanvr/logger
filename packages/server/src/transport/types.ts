import type { HookManager } from '../core/hooks'
import type { RateLimiter } from '../core/rate-limiter'
import type { FileStore } from '../modules/file-store'
import type { LokiForwarder } from '../modules/loki-forwarder'
import type { RingBuffer } from '../modules/ring-buffer'
import type { RpcBridge } from '../modules/rpc-bridge'
import type { SelfLogger } from '../modules/self-logger'
import type { SessionManager } from '../modules/session-manager'
import type { WebSocketHub } from '../modules/ws-hub'
import type { LogStoreReader } from '../store/log-store-reader'
import type { LogStoreWriter } from '../store/log-store-writer'

export interface ServerConfig {
  host: string
  port: number
  udpPort: number
  tcpPort: number
  apiKey: string | null
  environment: string
}

export interface ServerDeps {
  config: ServerConfig
  rateLimiter: RateLimiter
  hookManager: HookManager
  ringBuffer: RingBuffer
  sessionManager: SessionManager
  wsHub: WebSocketHub
  lokiForwarder: LokiForwarder
  fileStore: FileStore
  rpcBridge: RpcBridge
  selfLogger: SelfLogger
  storeWriter?: LogStoreWriter
  storeReader?: LogStoreReader
}
