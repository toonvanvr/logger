import {
  DataMessage,
  EventMessage,
  SessionMessage,
} from '@logger/shared/src/v2/index.ts'
import { normalizeData, normalizeEvent, normalizeSession } from '../core/normalizer'
import { ingestStoredEntry } from './ingest'
import type { ServerDeps } from './types'

// ─── Constants ───────────────────────────────────────────────────────

const MAX_BATCH_SIZE = 1000

// ─── Auth Helper (matches v1 pattern) ────────────────────────────────

function checkAuth(req: Request, apiKey: string | null): Response | null {
  if (!apiKey) return null
  const authHeader = req.headers.get('authorization')
  const apiKeyHeader = req.headers.get('x-api-key')
  if (authHeader === `Bearer ${apiKey}` || apiKeyHeader === apiKey) return null
  return Response.json({ ok: false, error: 'Unauthorized' }, { status: 401 })
}

// ─── Route Setup ─────────────────────────────────────────────────────

export function setupHttpV2Routes(deps: ServerDeps): Record<string, any> {
  const { config, rateLimiter } = deps

  return {
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

        ingestStoredEntry(entry, deps)
        return Response.json({ ok: true, session_id: entry.session_id })
      },
    },

    '/api/v2/events': {
      POST: async (req: Request) => {
        const authError = checkAuth(req, config.apiKey)
        if (authError) return authError

        let body: unknown
        try { body = await req.json() } catch {
          return Response.json({ ok: false, error: 'Invalid JSON' }, { status: 400 })
        }

        // Auto-detect single vs batch
        if (Array.isArray(body)) {
          return handleEventBatch(body, deps)
        }
        return handleSingleEvent(body, deps)
      },
    },

    '/api/v2/data': {
      POST: async (req: Request) => {
        const authError = checkAuth(req, config.apiKey)
        if (authError) return authError

        let body: unknown
        try { body = await req.json() } catch {
          return Response.json({ ok: false, error: 'Invalid JSON' }, { status: 400 })
        }

        // Auto-detect single vs batch
        if (Array.isArray(body)) {
          return handleDataBatch(body, deps)
        }
        return handleSingleData(body, deps)
      },
    },
  }
}

// ─── Internal Handlers ───────────────────────────────────────────────

function handleSingleEvent(body: unknown, deps: ServerDeps): Response {
  const parsed = EventMessage.safeParse(body)
  if (!parsed.success) {
    const msg = parsed.error.issues.map(i => `${i.path.join('.')}: ${i.message}`).join('; ')
    return Response.json({ ok: false, error: 'validation_error', message: msg }, { status: 400 })
  }

  const entry = normalizeEvent(parsed.data)
  if (!deps.rateLimiter.tryConsume(entry.session_id)) {
    return Response.json({ ok: false, error: 'Rate limit exceeded' }, { status: 429 })
  }

  ingestStoredEntry(entry, deps)
  return Response.json({ ok: true, id: entry.id })
}

function handleEventBatch(items: unknown[], deps: ServerDeps): Response {
  if (items.length === 0 || items.length > MAX_BATCH_SIZE) {
    return Response.json({ ok: false, error: `Batch must contain 1 to ${MAX_BATCH_SIZE} items` }, { status: 400 })
  }

  const results = items.map((item) => {
    const parsed = EventMessage.safeParse(item)
    if (!parsed.success) {
      const msg = parsed.error.issues.map(i => `${i.path.join('.')}: ${i.message}`).join('; ')
      return { ok: false as const, error: 'validation_error', message: msg }
    }
    const entry = normalizeEvent(parsed.data)
    if (!deps.rateLimiter.tryConsume(entry.session_id)) {
      return { ok: false as const, error: 'rate_limited', message: 'Rate limit exceeded' }
    }
    ingestStoredEntry(entry, deps)
    return { ok: true as const, id: entry.id }
  })

  return Response.json({ ok: true, results })
}

function handleSingleData(body: unknown, deps: ServerDeps): Response {
  const parsed = DataMessage.safeParse(body)
  if (!parsed.success) {
    const msg = parsed.error.issues.map(i => `${i.path.join('.')}: ${i.message}`).join('; ')
    return Response.json({ ok: false, error: 'validation_error', message: msg }, { status: 400 })
  }

  const entry = normalizeData(parsed.data)
  if (!deps.rateLimiter.tryConsume(entry.session_id)) {
    return Response.json({ ok: false, error: 'Rate limit exceeded' }, { status: 429 })
  }

  ingestStoredEntry(entry, deps)
  return Response.json({ ok: true, id: entry.id })
}

function handleDataBatch(items: unknown[], deps: ServerDeps): Response {
  if (items.length === 0 || items.length > MAX_BATCH_SIZE) {
    return Response.json({ ok: false, error: `Batch must contain 1 to ${MAX_BATCH_SIZE} items` }, { status: 400 })
  }

  const results = items.map((item) => {
    const parsed = DataMessage.safeParse(item)
    if (!parsed.success) {
      const msg = parsed.error.issues.map(i => `${i.path.join('.')}: ${i.message}`).join('; ')
      return { ok: false as const, error: 'validation_error', message: msg }
    }
    const entry = normalizeData(parsed.data)
    if (!deps.rateLimiter.tryConsume(entry.session_id)) {
      return { ok: false as const, error: 'rate_limited', message: 'Rate limit exceeded' }
    }
    ingestStoredEntry(entry, deps)
    return { ok: true as const, id: entry.id }
  })

  return Response.json({ ok: true, results })
}
