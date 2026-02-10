import {
  SessionMessage,
} from '@logger/shared'
import { normalizeSession } from '../core/normalizer'
import { handleDataBatch, handleEventBatch, handleSingleData, handleSingleEvent } from './http-handlers'
import { ingest } from './ingest'
import type { ServerDeps } from './types'

// ─── Constants ───────────────────────────────────────────────────────

const MAX_UPLOAD_SIZE = 16 * 1024 * 1024 // 16 MB
const startTime = Date.now()

// ─── Auth Helper ─────────────────────────────────────────────────────

function checkAuth(req: Request, apiKey: string | null): Response | null {
  if (!apiKey) return null
  const authHeader = req.headers.get('authorization')
  const apiKeyHeader = req.headers.get('x-api-key')
  if (authHeader === `Bearer ${apiKey}` || apiKeyHeader === apiKey) return null
  return Response.json({ ok: false, error: 'Unauthorized' }, { status: 401 })
}

// ─── Route Setup ─────────────────────────────────────────────────────

export function setupHttpRoutes(deps: ServerDeps): Record<string, any> {
  const { config, rateLimiter, ringBuffer, sessionManager, lokiForwarder, fileStore, rpcBridge } = deps

  return {
    // ─── Health ──────────────────────────────────────────────────────

    '/health': {
      GET: () => Response.json({ status: 'ok' }),
    },

    '/api/v2/health': {
      GET: (req: Request) => {
        const authError = checkAuth(req, config.apiKey)
        if (authError) return authError

        const lokiHealth = lokiForwarder.getHealth()
        return Response.json({
          status: 'ok',
          uptime: Math.floor((Date.now() - startTime) / 1000),
          buffer: { size: ringBuffer.size, bytes: ringBuffer.byteEstimate },
          sessions: sessionManager.getSessions().length,
          connections: deps.wsHub.getViewerCount(),
          loki: lokiHealth,
          rpcPending: rpcBridge.getPendingCount(),
        })
      },
    },

    // ─── Sessions ────────────────────────────────────────────────────

    '/api/v2/sessions': {
      GET: (req: Request) => {
        const authError = checkAuth(req, config.apiKey)
        if (authError) return authError

        return Response.json(sessionManager.getSessions())
      },
    },

    // ─── Upload ──────────────────────────────────────────────────────

    '/api/v2/upload': {
      POST: async (req: Request) => {
        const authError = checkAuth(req, config.apiKey)
        if (authError) return authError

        let formData: FormData
        try {
          formData = await req.formData()
        } catch {
          return Response.json({ ok: false, error: 'Invalid multipart data' }, { status: 400 })
        }

        const file = formData.get('file')
        if (!file || !(file instanceof File)) {
          return Response.json({ ok: false, error: 'Missing file field' }, { status: 400 })
        }

        if (file.size > MAX_UPLOAD_SIZE) {
          return Response.json({ ok: false, error: 'File too large' }, { status: 413 })
        }

        const sessionId = formData.get('session_id')
        if (!sessionId || typeof sessionId !== 'string') {
          return Response.json({ ok: false, error: 'Missing session_id' }, { status: 400 })
        }

        const label = formData.get('label')

        try {
          const bytes = new Uint8Array(await file.arrayBuffer())
          const ref = await fileStore.store(
            sessionId,
            bytes,
            file.type || 'application/octet-stream',
            typeof label === 'string' ? label : undefined,
          )
          return Response.json({ ok: true, ref })
        } catch (err) {
          try { deps.selfLogger.error(`[HTTP] File upload error: ${err}`) } catch { console.error('[HTTP] File upload error:', err) }
          return Response.json({ ok: false, error: 'Internal server error' }, { status: 500 })
        }
      },
    },

    // ─── Session Management ──────────────────────────────────────────

    '/api/v2/session': {
      POST: async (req: Request) => {
        const authError = checkAuth(req, config.apiKey)
        if (authError) return authError

        let body: unknown
        try { body = await req.json() } catch {
          return Response.json({ ok: false, error: 'Invalid JSON' }, { status: 400 })
        }

        const parsed = SessionMessage.safeParse(body)
        if (!parsed.success) {
          const msg = parsed.error.issues.map(i => `${i.path.join('.')}: ${i.message}`).join('; ')
          return Response.json({ ok: false, error: 'validation_error', message: msg }, { status: 400 })
        }

        const entry = normalizeSession(parsed.data)

        if (!rateLimiter.tryConsume(entry.session_id)) {
          return Response.json({ ok: false, error: 'Rate limit exceeded' }, { status: 429 })
        }

        ingest(entry, deps)
        return Response.json({ ok: true, session_id: entry.session_id })
      },
    },

    // ─── Events ──────────────────────────────────────────────────────

    '/api/v2/events': {
      POST: async (req: Request) => {
        const authError = checkAuth(req, config.apiKey)
        if (authError) return authError

        let body: unknown
        try { body = await req.json() } catch {
          return Response.json({ ok: false, error: 'Invalid JSON' }, { status: 400 })
        }

        if (Array.isArray(body)) {
          return handleEventBatch(body, deps)
        }
        return handleSingleEvent(body, deps)
      },
    },

    // ─── Data ────────────────────────────────────────────────────────

    '/api/v2/data': {
      POST: async (req: Request) => {
        const authError = checkAuth(req, config.apiKey)
        if (authError) return authError

        let body: unknown
        try { body = await req.json() } catch {
          return Response.json({ ok: false, error: 'Invalid JSON' }, { status: 400 })
        }

        if (Array.isArray(body)) {
          return handleDataBatch(body, deps)
        }
        return handleSingleData(body, deps)
      },
    },

    // ─── Session State ───────────────────────────────────────────────

    '/api/v2/sessions/:id/state': {
      GET: (req: Request) => {
        const authError = checkAuth(req, config.apiKey)
        if (authError) return authError

        const url = new URL(req.url)
        const segments = url.pathname.split('/')
        const sessionId = segments[4] ?? ''
        if (!sessionId) {
          return Response.json({ ok: false, error: 'Missing session ID' }, { status: 400 })
        }

        const session = sessionManager.getSession(sessionId)
        if (!session) {
          return Response.json({ ok: false, error: 'Session not found' }, { status: 404 })
        }

        const dataEntries = ringBuffer.query({ sessionId, limit: 1000 })
        const state: Record<string, unknown> = {}
        for (const entry of dataEntries.entries) {
          if (entry.kind === 'data' && entry.key) {
            state[entry.key] = entry.value
          }
        }

        return Response.json({ ok: true, session, state })
      },
    },

    // ─── Query ───────────────────────────────────────────────────────

    '/api/v2/query': {
      POST: async (req: Request) => {
        const authError = checkAuth(req, config.apiKey)
        if (authError) return authError

        let body: Record<string, unknown>
        try { body = await req.json() as Record<string, unknown> } catch {
          return Response.json({ ok: false, error: 'Invalid JSON' }, { status: 400 })
        }

        const sessionId = (body.session_id ?? body.sessionId) as string | undefined
        const severity = body.severity as string | undefined
        const from = body.from as string | undefined
        const to = body.to as string | undefined
        const limit = (body.limit as number) ?? 100

        const result = ringBuffer.query({ sessionId, severity, from, to, limit })

        const text = (body.text ?? body.search) as string | undefined
        if (text) {
          const lower = text.toLowerCase()
          result.entries = result.entries.filter((e) =>
            e.message?.toLowerCase().includes(lower) || e.tag?.toLowerCase().includes(lower),
          )
        }

        return Response.json({ ok: true, ...result })
      },
    },

    // ─── RPC Proxy ───────────────────────────────────────────────────

    '/api/v2/rpc': {
      POST: async (req: Request) => {
        const authError = checkAuth(req, config.apiKey)
        if (authError) return authError

        let body: Record<string, unknown>
        try { body = await req.json() as Record<string, unknown> } catch {
          return Response.json({ ok: false, error: 'Invalid JSON' }, { status: 400 })
        }

        const sessionId = (body.session_id ?? body.sessionId) as string | undefined
        const method = (body.tool ?? body.method) as string | undefined
        const args = body.args

        if (!sessionId || !method) {
          return Response.json(
            { ok: false, error: 'Missing session_id/sessionId and tool/method' },
            { status: 400 },
          )
        }

        const rpcId = crypto.randomUUID()

        return new Promise<Response>((resolve) => {
          const mockWs = {
            send(data: string) {
              const msg = JSON.parse(data)
              if (msg.rpc_error) {
                resolve(Response.json({ ok: false, rpc_id: rpcId, error: msg.rpc_error }, { status: 502 }))
              } else {
                resolve(Response.json({ ok: true, rpc_id: rpcId, data: msg.rpc_response }))
              }
            },
          }
          rpcBridge.handleRequest({ rpcId, targetSessionId: sessionId, method, args, viewerWs: mockWs })
        })
      },
    },
  }
}
