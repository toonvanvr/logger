import { LoggerBase } from './logger-base.js'
import type { Severity } from './logger-builders.js'
import {
  buildBinaryEntry,
  buildCustomEntry,
  buildHtmlEntry,
  buildHttpEntry,
  buildImageEntry,
  buildJsonEntry,
  buildStateEntry,
} from './logger-builders.js'
import type { LoggerOptions } from './logger-types.js'

// Re-export public types from their canonical location.
export type { LoggerOptions, Middleware } from './logger-types.js'

// ─── Logger ──────────────────────────────────────────────────────────

export class Logger extends LoggerBase {
  constructor(options?: LoggerOptions) {
    super(options)
  }

  // ─── Structured methods ──────────────────────────────────────────

  json(data: unknown, options?: { severity?: string }): void {
    this.enqueue(buildJsonEntry(this.base((options?.severity as Severity) ?? 'info'), data))
  }

  html(content: string, options?: { severity?: string }): void {
    this.enqueue(buildHtmlEntry(this.base((options?.severity as Severity) ?? 'info'), content))
  }

  binary(data: Uint8Array, options?: { severity?: string }): void {
    this.enqueue(buildBinaryEntry(this.base((options?.severity as Severity) ?? 'info'), data))
  }

  // ─── State / Image / Custom ──────────────────────────────────────

  state(key: string, value: unknown): void {
    this.enqueue(buildStateEntry(this.base('info'), key, value))
  }

  image(data: Buffer | Uint8Array | string, mime: string, options?: { id?: string }): void {
    this.enqueue(buildImageEntry(this.base('info'), data, mime, options?.id))
  }

  custom(type: string, data: unknown, options?: { id?: string; replace?: boolean }): void {
    this.enqueue(buildCustomEntry(this.base('info'), type, data, options))
  }

  table(columns: string[], rows: unknown[][]): void {
    this.custom('table', { columns, rows })
  }

  progress(label: string, value: number, max: number, options?: { id?: string }): void {
    const id = options?.id ?? `progress-${label}`
    this.custom('progress', { label, value, max }, { id, replace: true })
  }

  kv(entries: Record<string, unknown>, options?: { id?: string }): void {
    const formatted = Object.entries(entries).map(([key, value]) => ({
      key,
      value: value as string | number | boolean,
    }))
    const id = options?.id ?? `kv-${Object.keys(entries).sort().join(',')}`
    this.custom('kv', { entries: formatted }, { id, replace: true })
  }

  http(method: string, url: string, opts?: {
    status?: number
    status_text?: string
    duration_ms?: number
    ttfb_ms?: number
    request_headers?: Record<string, string>
    response_headers?: Record<string, string>
    request_body?: string
    response_body?: string
    request_body_size?: number
    response_body_size?: number
    request_id?: string
    started_at?: string
    content_type?: string
    is_error?: boolean
  }): void {
    const severity = opts?.status != null
      ? (opts.status >= 500 ? 'error' : opts.status >= 400 ? 'warning' : 'info')
      : 'info'
    const entry = buildHttpEntry(this.base(severity as Severity), {
      method,
      url,
      ...opts,
    })

    // Auto-extract Set-Cookie as state
    const setCookie = opts?.response_headers?.['set-cookie']
      ?? opts?.response_headers?.['Set-Cookie']
    if (setCookie) {
      const cookies: Record<string, string> = {}
      for (const part of setCookie.split(',')) {
        const [nameVal] = part.split(';')
        if (nameVal) {
          const eqIdx = nameVal.indexOf('=')
          if (eqIdx > 0) {
            cookies[nameVal.slice(0, eqIdx).trim()] = nameVal.slice(eqIdx + 1).trim()
          }
        }
      }
      if (Object.keys(cookies).length > 0) {
        this.state('http.cookies', cookies)
      }
    }

    this.enqueue(entry)
  }
}
