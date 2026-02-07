import type { ServerWebSocket } from 'bun';
import { ingestEntry, processEntry } from './ingest';
import type { ServerDeps } from './types';

// ─── Types ───────────────────────────────────────────────────────────

interface WsData {
  role: 'client' | 'viewer';
  sessionId?: string;
}

// ─── WebSocket Setup ─────────────────────────────────────────────────

export function setupWebSocket(deps: ServerDeps) {
  const { config, rateLimiter, wsHub, rpcBridge } = deps;

  /** Client WS connections indexed by session ID for RPC routing. */
  const clientSockets = new Map<string, ServerWebSocket<WsData>>();

  // Wire up RPC bridge to forward requests to client WebSockets
  rpcBridge.setClientSender((sessionId, message) => {
    const ws = clientSockets.get(sessionId);
    if (ws) {
      ws.send(JSON.stringify(message));
    }
  });

  return {
    /**
     * Attempt to upgrade a request to a WebSocket connection.
     * Returns true if the upgrade succeeded.
     */
    upgrade(req: Request, server: { upgrade(req: Request, options?: any): boolean }): boolean {
      const role = req.headers.get('x-logger-role') ?? 'viewer';

      if (role !== 'client' && role !== 'viewer') {
        return false;
      }

      // Auth check
      if (config.apiKey) {
        const authHeader = req.headers.get('authorization');
        const apiKeyHeader = req.headers.get('x-api-key');
        if (authHeader !== `Bearer ${config.apiKey}` && apiKeyHeader !== config.apiKey) {
          return false;
        }
      }

      const sessionId = req.headers.get('x-session-id') ?? undefined;

      return server.upgrade(req, {
        data: { role, sessionId } satisfies WsData,
      });
    },

    handlers: {
      open(ws: ServerWebSocket<WsData>) {
        if (ws.data.role === 'viewer') {
          wsHub.addViewer(ws);

          // Send current session list to newly connected viewer
          const sessions = deps.sessionManager.getSessions();
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
          }));
        } else if (ws.data.role === 'client' && ws.data.sessionId) {
          clientSockets.set(ws.data.sessionId, ws);
        }
      },

      message(ws: ServerWebSocket<WsData>, message: string | Buffer) {
        let parsed: any;
        try {
          parsed = JSON.parse(typeof message === 'string' ? message : message.toString());
        } catch {
          return;
        }

        if (ws.data.role === 'client') {
          handleClientMessage(ws, parsed);
        } else {
          handleViewerMessage(ws, parsed);
        }
      },

      close(ws: ServerWebSocket<WsData>) {
        if (ws.data.role === 'viewer') {
          wsHub.removeViewer(ws);
        } else if (ws.data.role === 'client' && ws.data.sessionId) {
          clientSockets.delete(ws.data.sessionId);
          rpcBridge.unregisterSession(ws.data.sessionId);
        }
      },

      idleTimeout: 40, // seconds — Bun handles ping/pong natively
    },
  };

  // ─── Internal Handlers ─────────────────────────────────────────────

  function handleClientMessage(ws: ServerWebSocket<WsData>, parsed: any): void {
    // RPC response from client → forward to waiting viewer
    if (parsed.rpc_id && (parsed.rpc_direction === 'response' || parsed.rpc_direction === 'error')) {
      rpcBridge.handleResponse({
        rpcId: parsed.rpc_id,
        data: parsed.rpc_response,
        error: parsed.rpc_error,
      });
      return;
    }

    // Tool registration
    if (parsed.type === 'register_tools' && Array.isArray(parsed.tools)) {
      rpcBridge.registerTools(ws.data.sessionId ?? parsed.session_id ?? '', parsed.tools);
      return;
    }

    // Regular log entry — process through pipeline
    const result = processEntry(parsed, deps);
    if (!result.ok) {
      ws.send(JSON.stringify({ type: 'error', error_message: result.error }));
      return;
    }

    const entry = result.entry;

    // Rate limit check (same as HTTP)
    if (!rateLimiter.tryConsume(entry.session_id)) {
      ws.send(JSON.stringify({ type: 'error', error_code: 'RATE_LIMITED', error_message: 'Rate limit exceeded' }));
      return;
    }

    ingestEntry(entry, deps);

    // Acknowledge
    ws.send(JSON.stringify({ type: 'ack', ack_ids: [entry.id] }));
  }

  function handleViewerMessage(ws: ServerWebSocket<WsData>, parsed: any): void {
    // RPC request from viewer → route to client
    if (parsed.type === 'rpc_request' && parsed.rpc_id) {
      rpcBridge.handleRequest({
        rpcId: parsed.rpc_id,
        targetSessionId: parsed.target_session_id,
        method: parsed.rpc_method,
        args: parsed.rpc_args,
        viewerWs: ws,
      });
      return;
    }

    // Handle history_query: query ring buffer and respond
    if (parsed.type === 'history_query') {
      const result = deps.ringBuffer.query({
        sessionId: parsed.session_id,
        from: parsed.from,
        to: parsed.to,
        severity: parsed.severity,
        limit: parsed.limit ?? 1000,
        cursor: parsed.cursor ? Number(parsed.cursor) : undefined,
      });
      ws.send(JSON.stringify({
        type: 'history',
        query_id: parsed.query_id,
        history_entries: result.entries,
        has_more: result.cursor !== null,
        cursor: result.cursor !== null ? String(result.cursor) : undefined,
      }));
      return;
    }

    // Handle session_list: respond with current sessions
    if (parsed.type === 'session_list') {
      const sessions = deps.sessionManager.getSessions();
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
      }));
      return;
    }

    // All other viewer messages (subscribe, unsubscribe, etc.)
    wsHub.handleViewerMessage(ws, parsed);
  }
}
