/**
 * Unit tests for docker-sidecar log parser.
 *
 * Tests detectSeverity (pure), emitLog (routing), and processLogChunk (integration).
 */

import { describe, test, expect, mock } from 'bun:test'
import { detectSeverity, emitLog, processLogChunk } from './log-parser'
import type { Logger } from '@logger/client'

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/** Create a mock Logger with spied methods. */
function createMockLogger() {
  return {
    debug: mock(() => {}),
    info: mock(() => {}),
    warn: mock(() => {}),
    error: mock(() => {}),
  } as unknown as Logger & {
    debug: ReturnType<typeof mock>
    info: ReturnType<typeof mock>
    warn: ReturnType<typeof mock>
    error: ReturnType<typeof mock>
  }
}

// ---------------------------------------------------------------------------
// detectSeverity
// ---------------------------------------------------------------------------

describe('detectSeverity', () => {
  test('detects ERROR keyword → "error"', () => {
    expect(detectSeverity('ERROR: something failed')).toBe('error')
  })

  test('detects error in lowercase → "error"', () => {
    expect(detectSeverity('error: connection refused')).toBe('error')
  })

  test('detects FATAL → "error"', () => {
    expect(detectSeverity('FATAL error occurred')).toBe('error')
  })

  test('detects PANIC → "error"', () => {
    expect(detectSeverity('PANIC: system down')).toBe('error')
  })

  test('detects WARN → "warning"', () => {
    expect(detectSeverity('WARN: low disk')).toBe('warning')
  })

  test('detects WARNING → "warning"', () => {
    expect(detectSeverity('WARNING: check config')).toBe('warning')
  })

  test('detects warn in lowercase → "warning"', () => {
    expect(detectSeverity('warn: deprecated call')).toBe('warning')
  })

  test('detects DEBUG → "debug"', () => {
    expect(detectSeverity('DEBUG: trace info')).toBe('debug')
  })

  test('detects TRACE → "debug"', () => {
    expect(detectSeverity('TRACE: deep trace')).toBe('debug')
  })

  test('detects debug in lowercase → "debug"', () => {
    expect(detectSeverity('debug: entering function')).toBe('debug')
  })

  test('defaults to "info" for normal lines', () => {
    expect(detectSeverity('Just a normal log line')).toBe('info')
  })

  test('defaults to "info" for empty-ish content', () => {
    expect(detectSeverity('server started on port 8080')).toBe('info')
  })

  test('detects keyword mid-line', () => {
    expect(detectSeverity('[2026-02-10] ERROR connection reset')).toBe('error')
  })

  test('detects keyword embedded in brackets', () => {
    expect(detectSeverity('[WARN] disk usage 90%')).toBe('warning')
  })
})

// ---------------------------------------------------------------------------
// emitLog
// ---------------------------------------------------------------------------

describe('emitLog', () => {
  test('routes "error" to logger.error', () => {
    const logger = createMockLogger()
    emitLog(logger, 'error', 'boom', { key: 'val' })
    expect(logger.error).toHaveBeenCalledWith('boom', { key: 'val' })
  })

  test('routes "warning" to logger.warn', () => {
    const logger = createMockLogger()
    emitLog(logger, 'warning', 'careful', { a: 1 })
    expect(logger.warn).toHaveBeenCalledWith('careful', { a: 1 })
  })

  test('routes "debug" to logger.debug', () => {
    const logger = createMockLogger()
    emitLog(logger, 'debug', 'details', {})
    expect(logger.debug).toHaveBeenCalledWith('details', {})
  })

  test('routes "info" to logger.info', () => {
    const logger = createMockLogger()
    emitLog(logger, 'info', 'hello', {})
    expect(logger.info).toHaveBeenCalledWith('hello', {})
  })

  test('only calls the target method once', () => {
    const logger = createMockLogger()
    emitLog(logger, 'error', 'msg', {})
    expect(logger.error).toHaveBeenCalledTimes(1)
    expect(logger.info).toHaveBeenCalledTimes(0)
    expect(logger.warn).toHaveBeenCalledTimes(0)
    expect(logger.debug).toHaveBeenCalledTimes(0)
  })
})

// ---------------------------------------------------------------------------
// processLogChunk
// ---------------------------------------------------------------------------

describe('processLogChunk', () => {
  test('processes multi-line chunk', () => {
    const logger = createMockLogger()
    processLogChunk('line one\nline two\nline three', logger, 'abc123')
    // All three are plain info lines
    expect(logger.info).toHaveBeenCalledTimes(3)
  })

  test('filters empty lines', () => {
    const logger = createMockLogger()
    processLogChunk('first\n\n\nsecond', logger, 'abc123')
    expect(logger.info).toHaveBeenCalledTimes(2)
  })

  test('handles trailing newline without extra call', () => {
    const logger = createMockLogger()
    processLogChunk('only line\n', logger, 'abc123')
    expect(logger.info).toHaveBeenCalledTimes(1)
  })

  test('routes each line to correct severity', () => {
    const logger = createMockLogger()
    processLogChunk('ERROR: bad\nINFO: ok\nDEBUG: verbose', logger, 'ctr1')
    expect(logger.error).toHaveBeenCalledTimes(1)
    expect(logger.info).toHaveBeenCalledTimes(1)
    expect(logger.debug).toHaveBeenCalledTimes(1)
  })

  test('passes container shortId in meta', () => {
    const logger = createMockLogger()
    processLogChunk('hello world', logger, 'xyz789')
    expect(logger.info).toHaveBeenCalledWith('hello world', {
      source: 'docker',
      container: 'xyz789',
    })
  })

  test('handles single line without newline', () => {
    const logger = createMockLogger()
    processLogChunk('single', logger, 'id1')
    expect(logger.info).toHaveBeenCalledTimes(1)
  })

  test('trims whitespace from lines', () => {
    const logger = createMockLogger()
    processLogChunk('  padded  \n  spaced  ', logger, 'id2')
    expect(logger.info).toHaveBeenCalledWith('padded', {
      source: 'docker',
      container: 'id2',
    })
  })

  test('skips whitespace-only lines', () => {
    const logger = createMockLogger()
    processLogChunk('   \n  \t  \nreal line', logger, 'id3')
    expect(logger.info).toHaveBeenCalledTimes(1)
  })
})
