/**
 * Docker Log Sidecar — Docker socket HTTP helper functions.
 */

import { config } from './config'

/** Fetch JSON from the Docker socket API. */
export async function dockerGet<T>(path: string, signal?: AbortSignal): Promise<T> {
  const res = await fetch(`http://localhost${path}`, {
    unix: config.DOCKER_SOCKET,
    signal,
  } as RequestInit)

  if (!res.ok) {
    throw new Error(`Docker API ${path}: ${res.status} ${res.statusText}`)
  }
  return res.json() as Promise<T>
}

/** Open a streaming connection to the Docker socket API. */
export async function dockerStream(path: string, signal?: AbortSignal): Promise<ReadableStream<Uint8Array>> {
  const res = await fetch(`http://localhost${path}`, {
    unix: config.DOCKER_SOCKET,
    signal,
  } as RequestInit)

  if (!res.ok) {
    throw new Error(`Docker API ${path}: ${res.status} ${res.statusText}`)
  }
  if (!res.body) {
    throw new Error(`Docker API ${path}: no body`)
  }
  return res.body
}
