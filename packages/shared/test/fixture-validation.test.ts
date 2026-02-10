import { describe, test, expect } from 'bun:test'
import { readFileSync } from 'fs'
import { join } from 'path'
import { ServerBroadcast } from '../src/server-broadcast'
import { ViewerCommand } from '../src/viewer-command'

const fixturesDir = join(import.meta.dir, 'fixtures')

function loadFixture(name: string) {
  return JSON.parse(readFileSync(join(fixturesDir, name), 'utf-8'))
}

describe('protocol fixtures', () => {
  const broadcastFixtures = [
    'broadcast_event.json',
    'broadcast_data_update.json',
    'broadcast_data_snapshot.json',
    'broadcast_session_update.json',
    'broadcast_session_list.json',
    'broadcast_history.json',
    'broadcast_error.json',
    'broadcast_ack.json',
    'broadcast_rpc_request.json',
    'broadcast_rpc_response.json',
    'broadcast_subscribe_ack.json',
  ]

  for (const fixture of broadcastFixtures) {
    test(`ServerBroadcast validates: ${fixture}`, () => {
      const data = loadFixture(fixture)
      const result = ServerBroadcast.safeParse(data)
      if (!result.success) {
        console.error(`Fixture ${fixture} errors:`, JSON.stringify(result.error.issues, null, 2))
      }
      expect(result.success).toBe(true)
    })
  }

  const commandFixtures = [
    'command_subscribe.json',
    'command_unsubscribe.json',
    'command_history.json',
  ]

  for (const fixture of commandFixtures) {
    test(`ViewerCommand validates: ${fixture}`, () => {
      const data = loadFixture(fixture)
      const result = ViewerCommand.safeParse(data)
      if (!result.success) {
        console.error(`Fixture ${fixture} errors:`, JSON.stringify(result.error.issues, null, 2))
      }
      expect(result.success).toBe(true)
    })
  }
})
