#!/usr/bin/env bun
/**
 * Export Zod schemas to JSON Schema files for external tooling and documentation.
 * Uses Zod v4's native toJSONSchema() — no external dependency needed.
 */
import { mkdir, writeFile } from 'node:fs/promises'
import { join } from 'node:path'
import { z } from 'zod'
import { StoredEntry } from '../src/stored-entry'
import { EventMessage } from '../src/event-message'
import { DataMessage } from '../src/data-message'
import { SessionMessage } from '../src/session-message'

const SCHEMAS = [
  { name: 'stored-entry', schema: StoredEntry },
  { name: 'event-message', schema: EventMessage },
  { name: 'data-message', schema: DataMessage },
  { name: 'session-message', schema: SessionMessage },
] as const

const outDir = join(import.meta.dir, '..', 'dist', 'schemas')

async function main() {
  await mkdir(outDir, { recursive: true })

  for (const { name, schema } of SCHEMAS) {
    const jsonSchema = z.toJSONSchema(schema, { target: 'draft-7' })
    const path = join(outDir, `${name}.json`)
    await writeFile(path, JSON.stringify(jsonSchema, null, 2) + '\n')
    console.log(`  ✓ ${name}.json`)
  }

  console.log(`\nExported ${SCHEMAS.length} schemas to ${outDir}`)
}

main().catch((err) => {
  console.error('Schema export failed:', err)
  process.exit(1)
})
