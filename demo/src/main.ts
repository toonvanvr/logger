import { runBasicLogging } from './scenarios/basic-logging'
import { runCustomRenderers } from './scenarios/custom-renderers'
import { runErrorDebugging } from './scenarios/error-debugging'
import { runGroupedLogs } from './scenarios/grouped-logs'
import { runImageLogging } from './scenarios/image-logging'
import { runMultiService } from './scenarios/multi-service'
import { runRpcTools } from './scenarios/rpc-tools'
import { runSessionLifecycle } from './scenarios/session-lifecycle'
import { runShowcase } from './scenarios/showcase'
import { runStateTracking } from './scenarios/state-tracking'
import { runStressTest } from './scenarios/stress-test'

const scenario = process.argv[2] ?? 'all'
const delay = (ms: number) => new Promise(r => setTimeout(r, ms))

const scenarios: Record<string, () => Promise<void>> = {
  showcase: runShowcase,
  basic: runBasicLogging,
  errors: runErrorDebugging,
  multi: runMultiService,
  state: runStateTracking,
  groups: runGroupedLogs,
  custom: runCustomRenderers,
  stress: runStressTest,
  images: runImageLogging,
  session: runSessionLifecycle,
  rpc: runRpcTools,
}

if (scenario === 'all') {
  for (const [name, fn] of Object.entries(scenarios)) {
    console.log(`\n=== Running: ${name} ===`)
    await fn()
    await delay(1000)
  }
} else {
  const fn = scenarios[scenario]
  if (!fn) { console.error(`Unknown scenario: ${scenario}`); process.exit(1) }
  await fn()
}