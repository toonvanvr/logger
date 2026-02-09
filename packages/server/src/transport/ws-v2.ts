import {
  DataMessage,
  EventMessage,
  SessionMessage,
} from '@logger/shared/src/v2/index.ts'
import type { ServerWebSocket } from 'bun'
import { normalizeData, normalizeEvent, normalizeSession } from '../core/normalizer'
import { ingestStoredEntry } from './ingest'
import type { ServerDeps } from './types'

// ─── Types ───────────────────────────────────────────────────────────

export interface WsV2Data {
  role: 'client' | 'viewer'
  sessionId?: string
  protocolVersion: 'v2'
}

// ─── WS v2 Setup ─────────────────────────────────────────────────────

export function setupWebSocketV2(deps: ServerDeps) {
  const { config, rateLimiter, wsHub, rpcBridge } = deps

  const clientSockets = new Map<string, ServerWebSocket<WsV2Data>>()

  rpcBridge.setClientSender((sessionId, message) => {
    const ws = clientSockets.get(sessionId)
    if (ws) ws.send(JSON.stringify(message))
  })

  return {
    /** Check if a request is a v2 WebSocket upgrade. */
    isV2(req: Request): boolean {
      const proto = req.headers.get('sec-websocket-protocol')
      const version = req.headers.get('x-logger-version')
      return proto === 'logger-v2' || version === '2'
    },

    /** Attempt to upgrade a v2 WebSocket request. */
    upgrade(req: Request, server: { upgrade(req: Request, opts?: any): boolean }): boolean {
      const role = req.headers.get('x-logger-role') ?? 'viewer'
      if (role !== 'client' && role !== 'viewer') return false

      if (config.apiKey) {
        const authHeader = req.headers.get('authorization')
        const apiKeyHeader = req.headers.get('x-api-key')
        if (authHeader !== `Bearer ${config.apiKey}` && apiKeyHeader !== config.apiKey) return false
      }

      const sessionId = req.headers.get('x-session-id') ?? undefined
      return server.upgrade(req, {
        data: { role, sessionId, protocolVersion: 'v2' } satisfies WsV2Data,
      })
    },

    handlers: {
      open(ws: ServerWebSocket<WsV2Data>) {
        if (ws.data.role === 'viewer') {
          wsHub.addViewer(ws)
          const sessions = deps.sessionManager.getSessions()
          ws.send(JSON.stringify({
            type: 'session_list',
            sessions: sessions.map(s => ({
              session_id: s.sessionId,
              application: s.application,
              started_at: s.startedAt,
              last_heartbeat: s.lastHeartbeat,
              is_active: s.isActive,
              log_count: s.logCount,
              color_index: s.colorIndex,
            })),
          }))
        } else if (ws.data.role === 'client' && ws.data.sessionId) {
          clientSockets.set(ws.data.sessionId, ws)
        }
      },

      message(ws: ServerWebSocket<WsV2Data>, message: string | Buffer) {
        let parsed: any
        try {
          parsed = JSON.parse(typeof message === 'string' ? message : message.toString())
        } catch { return }

        if (ws.data.role === 'client') {
          handleV2ClientMessage(ws, parsed)
        } else {
          handleV2ViewerMessage(ws, parsed)
        }
      },

      close(ws: ServerWebSocket<WsV2Data>) {
        if (ws.data.role === 'viewer') {
          wsHub.removeViewer(ws)
        } else if (ws.data.role === 'client' && ws.data.sessionId) {
          clientSockets.delete(ws.data.sessionId)
          rpcBridge.unregisterSession(ws.data.sessionId)
        }
      },

      idleTimeout: 40,
    },
  }

  // ─── v2 Client Messages ──────────────────────────────────────────

  function handleV2ClientMessage(ws: ServerWebSocket<WsV2Data>, parsed: any): void {
    const msgType = parsed.type

    if (msgType === 'rpc_response' && parsed.rpc_id) {
      rpcBridge.handleResponse({ rpcId: parsed.rpc_id, data: parsed.result, error: parsed.error })
      return
    }

    if (msgType === 'register_tools' && Array.isArray(parsed.tools)) {
      rpcBridge.registerTools(ws.data.sessionId ?? parsed.session_id ?? '', parsed.tools)
      return
    }

    if (msgType === 'session') {
      const result = SessionMessage.safeParse(parsed)
      if (!result.success) { sendError(ws, 'VALIDATION', result.error.message); return }
      const entry = normalizeSession(result.data)
      ingestAndAck(ws, entry)
      return
    }

    if (msgType === 'event') {
      const result = EventMessage.safeParse(parsed)
      if (!result.success) { sendError(ws, 'VALIDATION', result.error.message); return }
      const entry = normalizeEvent(result.data)
      ingestAndAck(ws, entry)
      return
    }

    if (msgType === 'data') {
      const result = DataMessage.safeParse(parsed)
      if (!result.success) { sendError(ws, 'VALIDATION', result.error.message); return }
      const entry = normalizeData(result.data)
      ingestAndAck(ws, entry)
      return
    }
  }

  // ─── v2 Viewer Messages ──────────────────────────────────────────

  async function handleV2ViewerMessage(ws: ServerWebSocket<WsV2Data>, parsed: any): Promise<void> {
    if (parsed.type === 'rpc_request' && parsed.rpc_id) {
      rpcBridge.handleRequest({
        rpcId: parsed.rpc_id,
        targetSessionId: parsed.target_session_id,
        method: parsed.method,
        args: parsed.args,
        viewerWs: ws,
      })
      return
    }

    if (parsed.type === 'session_list') {
      const sessions = deps.sessionManager.getSessions()
      ws.send(JSON.stringify({
        type: 'session_list',
        sessions: sessions.map(s => ({
          session_id: s.sessionId,
          application: s.application,
          started_at: s.startedAt,
          last_heartbeat: s.lastHeartbeat,
          is_active: s.isActive,
          log_count: s.logCount,
          color_index: s.colorIndex,
        })),
      }))
      return
    }

    if (parsed.type === 'data_query') {
      // Placeholder — data query handled by future data store
      ws.send(JSON.stringify({ type: 'data_snapshot', session_id: parsed.session_id, data: {} }))
      return
    }

    // subscribe/unsubscribe/history handled by ws-hub
    wsHub.handleViewerMessage(ws, parsed)
  }

  // ─── Helpers ─────────────────────────────────────────────────────

  function ingestAndAck(ws: ServerWebSocket<WsV2Data>, entry: any): void {
    if (!rateLimiter.tryConsume(entry.session_id)) {
      sendError(ws, 'RATE_LIMITED', 'Rate limit exceeded')
      return
    }
    ingestStoredEntry(entry, deps)
    ws.send(JSON.stringify({ type: 'ack', ids: [entry.id] }))
  }

  function sendError(ws: ServerWebSocket<WsV2Data>, code: string, message: string): void {
    ws.send(JSON.stringify({ type: 'error', code, message }))
  }
}
