import { config } from './core/config'
import { HookManager } from './core/hooks'
import { processPipeline } from './core/pipeline'
import { RateLimiter } from './core/rate-limiter'
import { FileStore } from './modules/file-store'
import { LokiForwarder } from './modules/loki-forwarder'
import { RingBuffer } from './modules/ring-buffer'
import { RpcBridge } from './modules/rpc-bridge'
import { SelfLogger } from './modules/self-logger'
import { SessionManager } from './modules/session-manager'
import { WebSocketHub } from './modules/ws-hub'
import { createStoreReader, createStoreWriter } from './store'
import { setupHttpRoutes } from './transport/http'
import { setupHttpV2Routes } from './transport/http-v2'
import { setupTcp } from './transport/tcp'
import { setupUdp } from './transport/udp'
import { setupWebSocket } from './transport/ws'
import { setupWebSocketV2 } from './transport/ws-v2'

// ─── Initialize all modules ─────────────────────────────────────────

const rateLimiter = new RateLimiter(
  config.rateLimitGlobal,
  config.rateLimitPerSession,
  config.rateLimitBurstMultiplier,
)
const hookManager = new HookManager()
const ringBuffer = new RingBuffer(config.ringBufferMaxEntries, config.ringBufferMaxBytes)
const sessionManager = new SessionManager()
const wsHub = new WebSocketHub()
const lokiForwarder = new LokiForwarder({
  lokiUrl: config.lokiUrl,
  batchSize: config.lokiBatchSize,
  flushIntervalMs: config.lokiFlushInterval,
  maxBuffer: config.lokiMaxBuffer,
  retries: config.lokiRetries,
  environment: config.environment,
})
const fileStore = new FileStore({
  storePath: config.imageStorePath,
  maxBytes: config.imageStoreMaxBytes,
})
const rpcBridge = new RpcBridge()

const selfLogger = new SelfLogger(ringBuffer, wsHub, sessionManager)

// ─── Initialize store adapters ───────────────────────────────────────

const storeWriter = createStoreWriter(config, { lokiForwarder })
const storeReader = createStoreReader(config, { ringBuffer })

// ─── Wire session events to WS broadcast ─────────────────────────────

sessionManager.on((event, session) => {
  if (event === 'session-start') {
    wsHub.broadcast({
      type: 'session_update',
      session_id: session.sessionId,
      session_action: 'start',
      application: session.application,
    })
  } else if (event === 'session-end') {
    wsHub.broadcast({
      type: 'session_update',
      session_id: session.sessionId,
      session_action: 'end',
    })
  }
})

const deps = {
  config,
  pipeline: processPipeline,
  rateLimiter,
  hookManager,
  ringBuffer,
  sessionManager,
  wsHub,
  lokiForwarder,
  fileStore,
  rpcBridge,
  storeWriter,
  storeReader,
}

// ─── Setup HTTP + WS server ─────────────────────────────────────────

const ws = setupWebSocket(deps)
const wsV2 = setupWebSocketV2(deps)
const v1Routes = setupHttpRoutes(deps)
const v2Routes = setupHttpV2Routes(deps)
const routes = { ...v1Routes, ...v2Routes }

const server = Bun.serve({
  port: config.port,
  hostname: config.host,
  routes,
  websocket: ws.handlers,
  fetch(req) {
    const url = new URL(req.url)
    // v2 WebSocket: detect via protocol header or path
    if (url.pathname === '/api/v2/stream') {
      if (wsV2.upgrade(req, server)) return undefined
      return new Response('WebSocket upgrade failed', { status: 400 })
    }
    // v1 WebSocket
    if (url.pathname === '/api/v1/stream' || url.pathname === '/stream') {
      // Check if v2 protocol was requested on v1 path
      if (wsV2.isV2(req)) {
        if (wsV2.upgrade(req, server)) return undefined
        return new Response('WebSocket upgrade failed', { status: 400 })
      }
      if (ws.upgrade(req, server)) return undefined
      return new Response('WebSocket upgrade failed', { status: 400 })
    }
    return new Response('Not Found', { status: 404 })
  },
})

// ─── Setup UDP + TCP ─────────────────────────────────────────────────

await setupUdp(deps)
await setupTcp(deps)

// ─── Startup log ─────────────────────────────────────────────────────

console.log(`Logger server listening on ${config.host}:${config.port} (HTTP/WS)`)
console.log(`Logger UDP on ${config.host}:${config.udpPort}`)
console.log(`Logger TCP on ${config.host}:${config.tcpPort}`)

selfLogger.info(`Server started on ${config.host}:${config.port}`)
selfLogger.info(`Store backend: ${config.storeBackend}`)
selfLogger.info(`Ring buffer: ${config.ringBufferMaxEntries} entries / ${config.ringBufferMaxBytes} bytes`)