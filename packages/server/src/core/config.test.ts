import { describe, test, expect } from 'bun:test'
import { ConfigSchema } from './config'

describe('ConfigSchema', () => {
  test('parses empty env with defaults', () => {
    const result = ConfigSchema.parse({})
    expect(result.host).toBe('127.0.0.1')
    expect(result.port).toBe(8080)
    expect(result.udpPort).toBe(8081)
    expect(result.tcpPort).toBe(8082)
    expect(result.ringBufferMaxEntries).toBe(1000000)
    expect(result.ringBufferMaxBytes).toBe(256 * 1024 * 1024)
    expect(result.rateLimitGlobal).toBe(10000)
    expect(result.rateLimitPerSession).toBe(1000)
    expect(result.rateLimitBurstMultiplier).toBe(2)
    expect(result.lokiUrl).toBe('http://localhost:3100')
    expect(result.lokiBatchSize).toBe(100)
    expect(result.lokiFlushInterval).toBe(1000)
    expect(result.lokiMaxBuffer).toBe(10000)
    expect(result.lokiRetries).toBe(3)
    expect(result.apiKey).toBeNull()
    expect(result.maxTimestampSkew).toBe(86400000)
    expect(result.environment).toBe('dev')
    expect(result.imageStorePath).toBe('/tmp/logger-images')
    expect(result.imageStoreMaxBytes).toBe(2 * 1024 * 1024 * 1024)
    expect(result.storeBackend).toBe('memory')
    expect(result.hookRedactPatterns).toEqual([])
  })

  test('coerces string numbers', () => {
    const result = ConfigSchema.parse({ port: '9090', rateLimitBurstMultiplier: '1.5' })
    expect(result.port).toBe(9090)
    expect(result.rateLimitBurstMultiplier).toBe(1.5)
  })

  test('rejects invalid store backend', () => {
    expect(() => ConfigSchema.parse({ storeBackend: 'redis' })).toThrow()
  })

  test('splits hookRedactPatterns', () => {
    const result = ConfigSchema.parse({ hookRedactPatterns: 'password,secret' })
    expect(result.hookRedactPatterns).toEqual(['password', 'secret'])
  })

  test('returns empty array for empty hookRedactPatterns', () => {
    const result = ConfigSchema.parse({ hookRedactPatterns: '' })
    expect(result.hookRedactPatterns).toEqual([])
  })

  test('accepts nullable apiKey', () => {
    const withKey = ConfigSchema.parse({ apiKey: 'my-secret' })
    expect(withKey.apiKey).toBe('my-secret')

    const withoutKey = ConfigSchema.parse({})
    expect(withoutKey.apiKey).toBeNull()
  })

  test('accepts valid store backend values', () => {
    expect(ConfigSchema.parse({ storeBackend: 'loki' }).storeBackend).toBe('loki')
    expect(ConfigSchema.parse({ storeBackend: 'memory' }).storeBackend).toBe('memory')
  })

  test('coerces all integer fields from strings', () => {
    const result = ConfigSchema.parse({
      udpPort: '9000',
      tcpPort: '9001',
      ringBufferMaxEntries: '500',
      lokiBatchSize: '50',
    })
    expect(result.udpPort).toBe(9000)
    expect(result.tcpPort).toBe(9001)
    expect(result.ringBufferMaxEntries).toBe(500)
    expect(result.lokiBatchSize).toBe(50)
  })
})
