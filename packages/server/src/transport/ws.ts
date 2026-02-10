import {
  DataMessage,
  EventMessage,
  SessionMessage,
} from '@logger/shared'
import type { ServerWebSocket } from 'bun'
import { normalizeData, normalizeEvent, normalizeSession } from '../core/normalizer'
import { ingest } from './ingest'
import type { ServerDeps } from './types'

// ─── Types ───────────────────────────────────────────────────────────

export interface WsData {
  role: 'client' | 'viewer'
  sessionId?: string
}

// ─── WebSocket Setup ─────────────────────────────────────────────────

export function setupWebSocket(deps: ServerDeps) {
  const { config, rateLimiter, wsHub, rpcBridge } = deps

  const clientSockets = new Map<string, ServerWebSocket<WsData>>()

  rpcBridge.setClientSender((sessionId, message) => {
    const ws = clientSockets.get(sessionId)
    if (ws) ws.send(JSON.stringify(message))
  })

  return {
    /** Attempt to upgrade a WebSocket request. */
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
        data: { role, sessionId } satisfies WsData,
      })
    },

    handlers: {
      open(ws: ServerWebSocket<WsData>) {
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

      message(ws: ServerWebSocket<WsData>, message: string | Buffer) {
        let parsed: any
        try {
          parsed = JSON.parse(typeof message === 'string' ? message : message.toString())
        } catch { return }

        if (ws.data.role === 'client') {
          handleClientMessage(ws, parsed)
        } else {
          handleViewerMessage(ws, parsed)
        }
      },

      close(ws: ServerWebSocket<WsData>) {
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

  // ─── Client Messages ─────────────────────────────────────────────

  function handleClientMessage(ws: ServerWebSocket<WsData>, parsed: any): void {
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

  // ─── Viewer Messages ─────────────────────────────────────────────

  async function handleViewerMessage(ws: ServerWebSocket<WsData>, parsed: any): Promise<void> {
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
      ws.send(JSON.stringify({ type: 'data_snapshot', session_id: parsed.session_id, data: {} }))
      return
    }

    if (parsed.type === 'history') {
      const result = deps.ringBuffer.query({
        sessionId: parsed.session_id,
        limit: parsed.limit ?? 5000,
        cursor: parsed.cursor,
      })
      ws.send(JSON.stringify({
        type: 'history',
        query_id: parsed.query_id ?? '',
        entries: result.entries,
        has_more: result.cursor !== null,
        source: 'buffer',
      }))
      return
    }

    // subscribe/unsubscribe handled by ws-hub
    wsHub.handleViewerMessage(ws, parsed)
  }

  // ─── Helpers ─────────────────────────────────────────────────────

  function ingestAndAck(ws: ServerWebSocket<WsData>, entry: any): void {
    if (!rateLimiter.tryConsume(entry.session_id)) {
      sendError(ws, 'RATE_LIMITED', 'Rate limit exceeded')
      return
    }
    ingest(entry, deps)
    ws.send(JSON.stringify({ type: 'ack', ids: [entry.id] }))
  }

  function sendError(ws: ServerWebSocket<WsData>, code: string, message: string): void {
    ws.send(JSON.stringify({ type: 'error', code, message }))
  }
}
