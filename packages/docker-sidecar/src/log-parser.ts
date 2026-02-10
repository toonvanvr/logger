/**
 * Docker Log Sidecar — log line parser and severity detection.
 */

import type { Logger } from '@logger/client'

/** Emit a log entry at the given severity level. */
export function emitLog(
  logger: Logger,
  severity: 'debug' | 'info' | 'warning' | 'error',
  message: string,
  meta: Record<string, unknown>,
): void {
  switch (severity) {
    case 'error': logger.error(message, meta); break
    case 'warning': logger.warn(message, meta); break
    case 'debug': logger.debug(message, meta); break
    default: logger.info(message, meta); break
  }
}

/**
 * Process a raw log chunk from a Docker container stream.
 *
 * Docker multiplexed stream: each frame has an 8-byte header
 * [stream_type(1) padding(3) size(4-byte big-endian)] + payload
 * When fetched via the API with follow=true, Bun delivers decoded text lines.
 */
export function processLogChunk(raw: string, logger: Logger, shortId: string): void {
  const lines = raw.split('\n')
  for (const line of lines) {
    const trimmed = line.trim()
    if (!trimmed) continue

    // Determine severity heuristic: lines with ERROR/WARN/FATAL → error/warning
    const severity = detectSeverity(trimmed)
    emitLog(logger, severity, trimmed, { source: 'docker', container: shortId })
  }
}

/** Detect log severity from line content using keyword heuristics. */
export function detectSeverity(line: string): 'debug' | 'info' | 'warning' | 'error' {
  const upper = line.toUpperCase()
  if (upper.includes('ERROR') || upper.includes('FATAL') || upper.includes('PANIC'))
    return 'error'
  if (upper.includes('WARN'))
    return 'warning'
  if (upper.includes('DEBUG') || upper.includes('TRACE'))
    return 'debug'
  return 'info'
}
