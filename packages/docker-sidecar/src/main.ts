/**
 * Docker Log Sidecar — reads container logs via Docker socket and forwards
 * them to the Logger server using the client SDK.
 *
 * Connects to `/var/run/docker.sock`, listens for container start/die events,
 * and attaches to stdout/stderr streams of running containers.
 */

import { Logger } from '@logger/client';

// ─── Configuration ───────────────────────────────────────────────────

const DOCKER_SOCKET = process.env.DOCKER_SOCKET ?? '/var/run/docker.sock';
const LOGGER_SERVER_URL = process.env.LOGGER_SERVER_URL ?? 'http://localhost:8080';
const CONTAINER_FILTER = process.env.CONTAINER_FILTER ?? '';
const POLL_INTERVAL_MS = 2_000;

// ─── Types ───────────────────────────────────────────────────────────

interface ContainerEvent {
  Action: string;
  id: string;
  Actor?: { Attributes?: Record<string, string> };
}

interface ContainerInfo {
  Id: string;
  Names: string[];
  Labels: Record<string, string>;
  State: string;
}

interface TrackedContainer {
  logger: Logger;
  abort: AbortController;
}

// ─── State ───────────────────────────────────────────────────────────

const tracked = new Map<string, TrackedContainer>();

// ─── Docker Socket HTTP Helper ───────────────────────────────────────

async function dockerGet<T>(path: string, signal?: AbortSignal): Promise<T> {
  const res = await fetch(`http://localhost${path}`, {
    unix: DOCKER_SOCKET,
    signal,
  } as RequestInit);

  if (!res.ok) {
    throw new Error(`Docker API ${path}: ${res.status} ${res.statusText}`);
  }
  return res.json() as Promise<T>;
}

async function dockerStream(path: string, signal?: AbortSignal): Promise<ReadableStream<Uint8Array>> {
  const res = await fetch(`http://localhost${path}`, {
    unix: DOCKER_SOCKET,
    signal,
  } as RequestInit);

  if (!res.ok) {
    throw new Error(`Docker API ${path}: ${res.status} ${res.statusText}`);
  }
  if (!res.body) {
    throw new Error(`Docker API ${path}: no body`);
  }
  return res.body;
}

// ─── Container Label Filter ─────────────────────────────────────────

function matchesFilter(labels: Record<string, string>): boolean {
  if (!CONTAINER_FILTER) return true;
  // Format: "label=key=value"
  const match = CONTAINER_FILTER.match(/^label=(.+?)=(.+)$/);
  if (!match) return true;
  const [, key, value] = match;
  return labels[key!] === value;
}

// ─── Attach to Container Logs ────────────────────────────────────────

async function attachContainer(containerId: string): Promise<void> {
  if (tracked.has(containerId)) return;

  const info = await dockerGet<{
    Id: string;
    Name: string;
    Config: { Labels: Record<string, string> };
  }>(`/containers/${containerId}/json`);

  const labels = info.Config.Labels;
  if (!matchesFilter(labels)) return;

  const name = info.Name.replace(/^\//, '');
  const shortId = containerId.slice(0, 12);

  const logger = new Logger({
    url: LOGGER_SERVER_URL,
    app: name,
    transport: 'http',
    sessionId: `docker-${shortId}`,
  });
  logger.session.start({ source: 'docker-sidecar', container_id: shortId });

  const abort = new AbortController();
  tracked.set(containerId, { logger, abort });

  console.log(`[sidecar] attached: ${name} (${shortId})`);

  try {
    const stream = await dockerStream(
      `/containers/${containerId}/logs?follow=true&stdout=true&stderr=true&tail=50`,
      abort.signal,
    );
    const reader = stream.getReader();
    const decoder = new TextDecoder();

    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      processLogChunk(decoder.decode(value, { stream: true }), logger, shortId);
    }
  } catch (err) {
    if (abort.signal.aborted) return; // expected on detach
    console.error(`[sidecar] stream error for ${name}: ${err}`);
  } finally {
    detachContainer(containerId);
  }
}

function processLogChunk(raw: string, logger: Logger, shortId: string): void {
  // Docker multiplexed stream: each frame has an 8-byte header
  // [stream_type(1) padding(3) size(4-byte big-endian)] + payload
  // When fetched via the API with follow=true, Bun delivers decoded text lines.
  const lines = raw.split('\n');
  for (const line of lines) {
    const trimmed = line.trim();
    if (!trimmed) continue;

    // Determine severity heuristic: lines with ERROR/WARN/FATAL → error/warning
    const severity = detectSeverity(trimmed);
    logger.log(severity, trimmed, { source: 'docker', container: shortId });
  }
}

function detectSeverity(line: string): 'debug' | 'info' | 'warning' | 'error' {
  const upper = line.toUpperCase();
  if (upper.includes('ERROR') || upper.includes('FATAL') || upper.includes('PANIC'))
    return 'error';
  if (upper.includes('WARN'))
    return 'warning';
  if (upper.includes('DEBUG') || upper.includes('TRACE'))
    return 'debug';
  return 'info';
}

// ─── Detach ──────────────────────────────────────────────────────────

async function detachContainer(containerId: string): Promise<void> {
  const entry = tracked.get(containerId);
  if (!entry) return;
  tracked.delete(containerId);

  entry.abort.abort();
  entry.logger.session.end();
  await entry.logger.close();

  const shortId = containerId.slice(0, 12);
  console.log(`[sidecar] detached: ${shortId}`);
}

// ─── Event Listener ──────────────────────────────────────────────────

async function watchEvents(): Promise<void> {
  console.log('[sidecar] watching Docker events...');

  while (true) {
    try {
      const stream = await dockerStream(
        '/events?filters=' +
          encodeURIComponent(JSON.stringify({ event: ['start', 'die'] })),
      );
      const reader = stream.getReader();
      const decoder = new TextDecoder();

      while (true) {
        const { done, value } = await reader.read();
        if (done) break;

        const text = decoder.decode(value, { stream: true });
        for (const line of text.split('\n')) {
          if (!line.trim()) continue;
          try {
            const event = JSON.parse(line) as ContainerEvent;
            if (event.Action === 'start') {
              attachContainer(event.id).catch((e) =>
                console.error(`[sidecar] attach failed: ${e}`),
              );
            } else if (event.Action === 'die') {
              detachContainer(event.id).catch((e) =>
                console.error(`[sidecar] detach failed: ${e}`),
              );
            }
          } catch { /* skip malformed event JSON */ }
        }
      }
    } catch (err) {
      console.error(`[sidecar] event stream error: ${err}`);
    }

    // Reconnect after a short delay
    await Bun.sleep(POLL_INTERVAL_MS);
  }
}

// ─── Bootstrap: attach to already-running containers ─────────────────

async function attachExisting(): Promise<void> {
  const containers = await dockerGet<ContainerInfo[]>(
    '/containers/json?filters=' +
      encodeURIComponent(JSON.stringify({ status: ['running'] })),
  );

  for (const c of containers) {
    attachContainer(c.Id).catch((e) =>
      console.error(`[sidecar] attach failed for ${c.Id.slice(0, 12)}: ${e}`),
    );
  }
}

// ─── Main ────────────────────────────────────────────────────────────

console.log(`[sidecar] Logger Docker Sidecar starting`);
console.log(`[sidecar] socket: ${DOCKER_SOCKET}`);
console.log(`[sidecar] server: ${LOGGER_SERVER_URL}`);
console.log(`[sidecar] filter: ${CONTAINER_FILTER || '(none)'}`);

await attachExisting();
await watchEvents();
