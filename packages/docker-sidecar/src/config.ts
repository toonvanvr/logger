/**
 * Docker Log Sidecar — configuration from environment variables.
 */

export const config = {
  DOCKER_SOCKET: process.env.DOCKER_SOCKET ?? '/var/run/docker.sock',
  LOGGER_SERVER_URL: process.env.LOGGER_SERVER_URL ?? 'http://localhost:8080',
  CONTAINER_FILTER: process.env.CONTAINER_FILTER ?? '',
  POLL_INTERVAL_MS: 2_000,
} as const
