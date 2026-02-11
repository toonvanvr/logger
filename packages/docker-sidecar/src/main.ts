/**
 * Docker Log Sidecar — reads container logs via Docker socket and forwards
 * them to the Logger server using the client SDK.
 *
 * Connects to `/var/run/docker.sock`, listens for container start/die events,
 * and attaches to stdout/stderr streams of running containers.
 */

import { Logger } from '@logger/client'
import { config } from './config'
import type { ContainerEvent, ContainerInfo, TrackedContainer } from './types'
import { dockerGet, dockerStream } from './docker-client'
import { processLogChunk } from './log-parser'

const tracked = new Map<string, TrackedContainer>()

function matchesFilter(labels: Record<string, string>): boolean {
  if (!config.CONTAINER_FILTER) return true
  // Format: "label=key=value"
  const match = config.CONTAINER_FILTER.match(/^label=(.+?)=(.+)$/)
  if (!match) return true
  const [, key, value] = match
  return labels[key!] === value
}

async function attachContainer(containerId: string): Promise<void> {
  if (tracked.has(containerId)) return

  const info = await dockerGet<{
    Id: string
    Name: string
    Config: { Labels: Record<string, string> }
  }>(`/containers/${containerId}/json`)

  const labels = info.Config.Labels
  if (!matchesFilter(labels)) return

  const name = info.Name.replace(/^\//, '')
  const shortId = containerId.slice(0, 12)

  const logger = new Logger({
    url: config.LOGGER_SERVER_URL,
    app: name,
    transport: 'http',
    sessionId: `docker-${shortId}`,
  })
  logger.session.start({ source: 'docker-sidecar', container_id: shortId })

  const abort = new AbortController()
  tracked.set(containerId, { logger, abort })

  console.log(`[sidecar] attached: ${name} (${shortId})`)

  try {
    const stream = await dockerStream(
      `/containers/${containerId}/logs?follow=true&stdout=true&stderr=true&tail=50`,
      abort.signal,
    )
    const reader = stream.getReader()
    const decoder = new TextDecoder()

    while (true) {
      const { done, value } = await reader.read()
      if (done) break
      processLogChunk(decoder.decode(value, { stream: true }), logger, shortId)
    }
  } catch (err) {
    if (abort.signal.aborted) return // expected on detach
    console.error(`[sidecar] stream error for ${name}: ${err}`)
  } finally {
    detachContainer(containerId)
  }
}

async function detachContainer(containerId: string): Promise<void> {
  const entry = tracked.get(containerId)
  if (!entry) return
  tracked.delete(containerId)

  entry.abort.abort()
  entry.logger.session.end()
  await entry.logger.close()

  const shortId = containerId.slice(0, 12)
  console.log(`[sidecar] detached: ${shortId}`)
}

async function watchEvents(): Promise<void> {
  console.log('[sidecar] watching Docker events...')

  while (true) {
    try {
      const stream = await dockerStream(
        '/events?filters=' +
        encodeURIComponent(JSON.stringify({ event: ['start', 'die'] })),
      )
      const reader = stream.getReader()
      const decoder = new TextDecoder()

      while (true) {
        const { done, value } = await reader.read()
        if (done) break

        const text = decoder.decode(value, { stream: true })
        for (const line of text.split('\n')) {
          if (!line.trim()) continue
          try {
            const event = JSON.parse(line) as ContainerEvent
            if (event.Action === 'start') {
              attachContainer(event.id).catch((e) =>
                console.error(`[sidecar] attach failed: ${e}`),
              )
            } else if (event.Action === 'die') {
              detachContainer(event.id).catch((e) =>
                console.error(`[sidecar] detach failed: ${e}`),
              )
            }
          } catch { /* skip malformed event JSON */ }
        }
      }
    } catch (err) {
      console.error(`[sidecar] event stream error: ${err}`)
    }

    // Reconnect after a short delay
    await Bun.sleep(config.POLL_INTERVAL_MS)
  }
}

async function attachExisting(): Promise<void> {
  const containers = await dockerGet<ContainerInfo[]>(
    '/containers/json?filters=' +
    encodeURIComponent(JSON.stringify({ status: ['running'] })),
  )

  for (const c of containers) {
    attachContainer(c.Id).catch((e) =>
      console.error(`[sidecar] attach failed for ${c.Id.slice(0, 12)}: ${e}`),
    )
  }
}

console.log(`[sidecar] Logger Docker Sidecar starting`)
console.log(`[sidecar] socket: ${config.DOCKER_SOCKET}`)
console.log(`[sidecar] server: ${config.LOGGER_SERVER_URL}`)
console.log(`[sidecar] filter: ${config.CONTAINER_FILTER || '(none)'}`)

await attachExisting()
await watchEvents()
