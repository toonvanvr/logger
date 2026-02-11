# Configuration Reference

All Logger server configuration is done via environment variables. The server reads these at startup from `packages/server/src/core/config.ts`.

## Server

| Variable | Default | Description |
|----------|---------|-------------|
| `LOGGER_BIND_ADDRESS` | `127.0.0.1` | IP address the server binds to. Use `0.0.0.0` in Docker. |
| `LOGGER_PORT` | `8080` | HTTP API port for log ingestion and health checks. |
| `LOGGER_UDP_PORT` | `8081` | UDP port for high-throughput log ingestion. |
| `LOGGER_TCP_PORT` | `8082` | TCP port for WebSocket viewer connections. |
| `LOGGER_ENVIRONMENT` | `dev` | Environment label attached to all logs. |

## Ring Buffer

The in-memory ring buffer stores recent log entries for real-time viewer access.

| Variable | Default | Description |
|----------|---------|-------------|
| `LOGGER_BUFFER_MAX_ENTRIES` | `1000000` | Maximum number of entries in the ring buffer. |
| `LOGGER_BUFFER_MAX_BYTES` | `268435456` (256 MB) | Maximum total size of the ring buffer in bytes. |

## Rate Limiting

Rate limits protect the server from excessive log volume.

| Variable | Default | Description |
|----------|---------|-------------|
| `LOGGER_RATE_LIMIT_GLOBAL` | `10000` | Maximum logs per second across all sessions. |
| `LOGGER_RATE_LIMIT_SESSION` | `1000` | Maximum logs per second per session. |
| `LOGGER_RATE_LIMIT_BURST` | `2` | Burst multiplier — allows temporary spikes above the rate limit. |

## Loki Integration

Controls the async batch forwarding of logs to Grafana Loki.

| Variable | Default | Description |
|----------|---------|-------------|
| `LOGGER_LOKI_URL` | `http://localhost:3100` | Loki push API endpoint. Use `http://loki:3100` in Docker. Fallback: `LOKI_URL` (deprecated). |
| `LOGGER_LOKI_BATCH_SIZE` | `100` | Number of entries per Loki push request. |
| `LOGGER_LOKI_FLUSH_MS` | `1000` | Maximum time (ms) between Loki flushes. |
| `LOGGER_LOKI_MAX_BUFFER` | `10000` | Maximum entries buffered before dropping. |
| `LOGGER_LOKI_RETRIES` | `3` | Number of retry attempts for failed Loki pushes. |

## Security

| Variable | Default | Description |
|----------|---------|-------------|
| `LOGGER_API_KEY` | `null` | API key for authenticating log ingestion. When set, clients must send `Authorization: Bearer <key>`. When null (default), no authentication is required. |
| `LOGGER_MAX_TIMESTAMP_SKEW_MS` | `86400000` (24h) | Maximum allowed timestamp skew from server time. Entries outside this window are rejected. |

## Images

| Variable | Default | Description |
|----------|---------|-------------|
| `LOGGER_IMAGE_STORE_PATH` | `/tmp/logger-images` | Filesystem path for uploaded image storage. |
| `LOGGER_IMAGE_STORE_MAX_BYTES` | `2147483648` (2 GB) | Maximum total size of stored images. |

## Hooks

| Variable | Default | Description |
|----------|---------|-------------|
| `LOGGER_HOOK_REDACT_PATTERNS` | *(empty)* | Comma-separated list of regex patterns. Matching content is redacted from log entries before storage. |

## Storage Backend

| Variable | Default | Description |
|----------|---------|-------------|
| `LOGGER_STORE_BACKEND` | `memory` | Storage backend for log persistence. Options: `loki` (forward to Grafana Loki) or `memory` (in-memory only, no external dependencies). |

## Docker Compose Defaults

The `compose.yml` sets these for the containerized server:

```yaml
environment:
  - LOGGER_LOKI_URL=http://loki:3100
  - LOGGER_BIND_ADDRESS=0.0.0.0
  - LOGGER_ENVIRONMENT=dev
```

Resource limits:
- Server: 512 MB memory
- Loki: 4 GB memory
- Grafana: 1 GB memory

## Viewer (Flutter App)

The Flutter desktop viewer (`app/`) has no persistent configuration files. All state is in-memory:

| Setting | Storage | Description |
|---------|---------|-------------|
| Server connections | In-memory `Map` | Added via the UI connection dialog. Not persisted to disk — connections must be re-added after restarting the viewer. Intentional for a local-dev tool. |
| Filters & subscriptions | In-memory | Active filters, severity toggles, and session subscriptions reset on restart. |

## Workspace Setup

The repository uses **Bun workspaces** for TypeScript package management. The root `package.json` declares:

```json
{
  "workspaces": ["packages/*"]
}
```

Run `bun install` from the repository root to install dependencies for all packages. Cross-package imports resolve automatically via the workspace configuration.
