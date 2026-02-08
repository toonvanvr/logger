import { Logger } from '@logger/client'

const delay = (ms: number) => new Promise(r => setTimeout(r, ms))

export async function runStickyDemo() {
  const logger = new Logger({ app: 'demo-sticky', transport: 'http' })

  try {
    logger.info('=== Sticky Entries Demo ===')
    await delay(200)

    // ─── 1. Sticky progress bar ───────────────────────────────────────
    logger.info('Starting build process with sticky progress...')
    await delay(200)

    const buildId = crypto.randomUUID()
    const steps = ['Compiling', 'Linking', 'Optimizing', 'Packaging', 'Signing']
    for (let i = 0; i < steps.length; i++) {
      const value = Math.round((i / steps.length) * 100)
      const builder = i === 0
        ? logger.withId(buildId).sticky()
        : logger.withId(buildId).replace()
      builder.custom('progress', {
        value,
        max: 100,
        label: `Build: ${steps[i]}...`,
        sublabel: `Step ${i + 1}/${steps.length}`,
        color: '#E6B455',
      })
      await delay(400)

      // Emit some normal logs while progress is pinned
      logger.info(`Build step "${steps[i]}" processing...`)
      await delay(200)
    }

    // Complete
    logger.withId(buildId).replace().custom('progress', {
      value: 100,
      max: 100,
      label: 'Build complete',
      sublabel: 'All 5 steps succeeded',
      color: '#A8CC7E',
      style: 'bar',
    })
    await delay(500)
    logger.info('Build finished — unpinning progress bar')
    logger.unsticky('', buildId)
    await delay(300)

    // ─── 2. Sticky deploy pipeline that unsticks on completion ───────
    const deployGroupId = logger.group('Deploy Pipeline', { sticky: true })
    logger.info('Starting deployment to production...')
    await delay(100)
    logger.info('Pre-flight checks passed')
    await delay(100)
    logger.info('Building container image...')
    await delay(100)
    logger.info('Pushing to registry...')
    await delay(100)
    logger.info('Rolling update: 3/3 replicas healthy')
    await delay(100)
    logger.info('Deploy complete: v2.4.1 → production ✓')
    logger.groupEnd()
    await delay(300)

    // Normal logs flow while sticky is pinned
    logger.info('Client connected: 192.168.1.42')
    await delay(100)
    logger.debug('Heartbeat received from worker-3')
    await delay(100)
    logger.info('Cache hit ratio: 94.2%')
    await delay(100)

    // Unsticky the deploy group (it "completed")
    logger.info('Deploy verified — unpinning status banner...')
    logger.unsticky(deployGroupId)
    await delay(500)

    // ─── 3. Individual sticky entries that unstick after delays ──────
    logger.info('--- Individual Sticky Lifecycle ---')
    await delay(200)

    const serverId = crypto.randomUUID()
    logger.withId(serverId).sticky().info('Server running on http://localhost:3000')
    await delay(200)

    const memoryId = crypto.randomUUID()
    logger.withId(memoryId).sticky().warn('Memory usage: 87% (threshold: 90%)')
    await delay(200)

    // Normal traffic flows
    logger.debug('WebSocket ping/pong: 12ms')
    await delay(100)
    logger.info('Scheduled job "cleanup" completed in 340ms')
    await delay(100)

    // Memory warning resolves — unsticky it
    logger.info('Memory reclaimed after GC — 62% usage')
    logger.unsticky('', memoryId)
    await delay(300)

    // Server status remains sticky until later
    logger.info('Server status remains pinned')
    await delay(300)

    // ─── 4. Sticky group with prepend/append ────────────────────────
    logger.info('--- Sticky Group: Prepend & Append ---')
    await delay(200)

    const statusGroupId = logger.group('System Status', { sticky: true })

    // Initial entries with known IDs
    const firstEntryId = crypto.randomUUID()
    logger.withId(firstEntryId).info('CPU: 42% | Memory: 1.3GB / 4GB')
    await delay(100)

    const secondEntryId = crypto.randomUUID()
    logger.withId(secondEntryId).info('Disk: 67% used (134GB / 200GB)')
    await delay(100)

    const lastEntryId = crypto.randomUUID()
    logger.withId(lastEntryId).info('Network: 120 Mbps in / 85 Mbps out')
    logger.groupEnd()
    await delay(500)

    // Append a new entry after the last one
    logger.info('New GPU metric detected — appending to status group...')
    await delay(200)
    logger.after(lastEntryId).info('GPU: 78% utilization (CUDA cores active)')
    await delay(300)

    // Prepend an alert before the first entry
    logger.info('Alert triggered — prepending to status group...')
    await delay(200)
    logger.before(firstEntryId).warn('⚠ ALERT: Disk I/O latency spike detected')
    await delay(500)

    // Clean up the status group
    logger.info('Status normalized — unpinning system status...')
    logger.unsticky(statusGroupId)
    await delay(300)

    // ─── 5. Sticky overflow: many stickies at once ──────────────────
    logger.info('--- Sticky Overflow Test ---')
    await delay(200)

    logger.info('Creating 10 sticky entries rapidly to trigger overflow...')
    await delay(200)

    const overflowIds: string[] = []
    const services = [
      'auth-service',
      'api-gateway',
      'user-service',
      'order-service',
      'payment-engine',
      'notification-hub',
      'search-indexer',
      'cache-warmer',
      'metrics-collector',
      'log-aggregator',
    ]

    for (let i = 0; i < services.length; i++) {
      const id = crypto.randomUUID()
      overflowIds.push(id)
      logger.withId(id).sticky().info(`[${services[i]}] Status: healthy ✓`)
      await delay(80)
    }

    // Let them sit so the overflow indicator shows
    await delay(1000)

    // Gradually unstick them
    logger.info('Services stabilizing — removing sticky status entries...')
    for (let i = 0; i < overflowIds.length; i++) {
      await delay(300)
      logger.info(`${services[i]} check-in complete — unpinning`)
      logger.unsticky('', overflowIds[i])
    }
    await delay(500)

    // ─── 6. Nested sticky with phase transitions ────────────────────
    logger.info('--- Nested Sticky Groups ---')
    await delay(200)

    logger.group('CI Pipeline')
    logger.info('Triggered by push to main branch')
    await delay(100)

    const buildGroupId = logger.group('Build Phase', { sticky: true })
    logger.info('Compiling TypeScript...')
    await delay(100)
    logger.info('Bundling with esbuild...')
    await delay(100)
    logger.info('Build complete: 12 files, 245KB')
    logger.groupEnd()
    await delay(300)

    // Build phase done — unsticky it
    logger.info('Build succeeded, moving to test phase...')
    logger.unsticky(buildGroupId)
    await delay(200)

    const testGroupId = logger.group('Test Phase', { sticky: true })
    logger.info('Running 342 unit tests...')
    await delay(100)
    for (let i = 0; i <= 342; i += 68) {
      logger.progress('Tests', Math.min(i, 342), 342, { id: 'ci-test-progress' })
      await delay(80)
    }
    logger.info('All 342 tests passed ✓')
    logger.groupEnd()
    await delay(300)

    // Test phase done — unsticky it
    logger.info('Tests passed, finalizing...')
    logger.unsticky(testGroupId)
    await delay(200)

    logger.info('CI Pipeline complete — all stages green ✓')
    logger.groupEnd()
    await delay(300)

    // ─── 7. Remaining background logs ───────────────────────────────
    for (let i = 0; i < 10; i++) {
      logger.debug(`Background task ${i + 1}/10: processing batch`)
      await delay(50)
    }

    // Finally unstick the server status from step 2
    logger.info('Shutting down — unpinning server status')
    logger.unsticky('', serverId)
    await delay(100)

    logger.info('=== Sticky Demo Complete ===')
    await logger.flush()
  } finally {
    await logger.close()
  }
}
