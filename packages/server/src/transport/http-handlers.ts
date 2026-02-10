import { DataMessage, EventMessage } from '@logger/shared'
import { normalizeData, normalizeEvent } from '../core/normalizer'
import { ingest } from './ingest'
import type { ServerDeps } from './types'

// ─── Constants ───────────────────────────────────────────────────────

export const MAX_BATCH_SIZE = 1000

// ─── Event Handlers ──────────────────────────────────────────────────

export function handleSingleEvent(body: unknown, deps: ServerDeps): Response {
  const parsed = EventMessage.safeParse(body)
  if (!parsed.success) {
    const msg = parsed.error.issues.map(i => `${i.path.join('.')}: ${i.message}`).join('; ')
    return Response.json({ ok: false, error: 'validation_error', message: msg }, { status: 400 })
  }

  const entry = normalizeEvent(parsed.data)
  if (!deps.rateLimiter.tryConsume(entry.session_id)) {
    return Response.json({ ok: false, error: 'Rate limit exceeded' }, { status: 429 })
  }

  ingest(entry, deps)
  return Response.json({ ok: true, id: entry.id })
}

export function handleEventBatch(items: unknown[], deps: ServerDeps): Response {
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
    ingest(entry, deps)
    return { ok: true as const, id: entry.id }
  })

  return Response.json({ ok: true, results })
}

// ─── Data Handlers ───────────────────────────────────────────────────

export function handleSingleData(body: unknown, deps: ServerDeps): Response {
  const parsed = DataMessage.safeParse(body)
  if (!parsed.success) {
    const msg = parsed.error.issues.map(i => `${i.path.join('.')}: ${i.message}`).join('; ')
    return Response.json({ ok: false, error: 'validation_error', message: msg }, { status: 400 })
  }

  const entry = normalizeData(parsed.data)
  if (!deps.rateLimiter.tryConsume(entry.session_id)) {
    return Response.json({ ok: false, error: 'Rate limit exceeded' }, { status: 429 })
  }

  ingest(entry, deps)
  return Response.json({ ok: true, id: entry.id })
}

export function handleDataBatch(items: unknown[], deps: ServerDeps): Response {
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
    ingest(entry, deps)
    return { ok: true as const, id: entry.id }
  })

  return Response.json({ ok: true, results })
}
