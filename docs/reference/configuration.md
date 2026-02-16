# Configuration Reference

All Logger server configuration is done via environment variables. The server reads these at startup from `packages/server/src/core/config.ts`.

## Server

| Variable | Default | Description |
|----------|---------|-------------|
| `LOGGER_BIND_ADDRESS` | `127.0.0.1` | IP address the server binds to. Use `0.0.0.0` in Docker. |
| `LOGGER_PORT` | `8080` | HTTP API port for log ingestion and health checks. |
| `LOGGER_UDP_PORT` | `8081` | UDP port for high-throughput log ingestion. |
| `LOGGER_TCP_PORT` | `8082` | TCP port for **NDJSON ingestion** (not WebSocket). |
| `LOGGER_ENVIRONMENT` | `dev` | Environment label attached to all logs. |

### Port / Transport Mapping

Logger uses multiple transports, each on a specific port by default:

| Purpose | Transport | Default | Example |
|---------|-----------|---------|---------|
| HTTP API base | HTTP | `LOGGER_PORT` (`8080`) | `http://127.0.0.1:8080` |
| Viewer stream | WebSocket (upgrade on HTTP server) | `LOGGER_PORT` (`8080`) | `ws://127.0.0.1:8080/api/v2/stream` |
| High-throughput ingest | UDP | `LOGGER_UDP_PORT` (`8081`) | `udp://127.0.0.1:8081` |
| Raw ingest | TCP (NDJSON) | `LOGGER_TCP_PORT` (`8082`) | `tcp://127.0.0.1:8082` |

Notes:
- The viewer WebSocket runs on the HTTP server (`LOGGER_PORT`) at `/api/v2/stream`.
- `LOGGER_TCP_PORT` is for TCP ingestion and does not accept WebSocket connections.

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
| `LOGGER_API_KEY` | `null` | API key for authenticated API/socket access. When set, protected HTTP routes require `Authorization: Bearer <key>` or `x-api-key: <key>`, and WebSocket/TCP clients must authenticate. When null (default), auth is disabled for local-dev use. |
| `LOGGER_MAX_TIMESTAMP_SKEW_MS` | `86400000` (24h) | Maximum allowed timestamp skew from server time. Entries outside this window are rejected. |

Auth route behavior:
- `GET /health` is intentionally unauthenticated for basic liveness checks.
- `GET /api/v2/health` and other `/api/v2/*` operational routes enforce `LOGGER_API_KEY` when set.

## Operational Self-Logging

The server emits structured internal operational events through the built-in self-logger.

- Session ID: `__system__`
- Typical startup signals: server bind/start, selected store backend, ring-buffer limits
- Failure-path signals: upload/storage/Loki forwarding errors are emitted as self-log events
- Self-log events stay in the in-memory/live viewer path and are not forwarded to external stores by default

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

The Flutter desktop viewer (`app/`) persists a small amount of UI/tray state to disk.

### Persisted state

Files are stored in the platform config directory.

Linux:
- `$XDG_CONFIG_HOME/logger/settings.json` (fallback `~/.config/logger/settings.json`)
- `$XDG_CONFIG_HOME/logger/tray_prefs.json` (fallback `~/.config/logger/tray_prefs.json`)

macOS:
- `~/Library/Application Support/logger/settings.json`
- `~/Library/Application Support/logger/tray_prefs.json`

Windows:
- `%APPDATA%\\logger\\settings.json`
- `%APPDATA%\\logger\\tray_prefs.json`

What is persisted:
- **Store enabled**: stored per server base URL and re-applied when you connect.
- **Tray toggles**: tray menu checkbox state (e.g. Loki/Grafana integration toggles).

### In-memory only

| Setting | Storage | Description |
|---------|---------|-------------|
| Server connections | In-memory `Map` | Added via the UI connection dialog. Not persisted to disk — connections must be re-added after restarting the viewer. Intentional for a local-dev tool. |
| Filters & subscriptions | In-memory | Active filters, severity toggles, and session subscriptions reset on restart. |

### Clear semantics

Logger has multiple “clear” actions with different meanings:

- **Clear all filters**: clears active filters in the filter bar (does not affect stored data).
- **Timeline “Clear”**: performs a *timeline cut* (“show logs since now”) without deleting entries. It is reversible via the existing timeline reset controls.
- **Tray “Clear store”**: clears stored log/state data (viewer caches + server in-memory store). It does **not** delete history already forwarded to Loki.

### Linux tray behavior

On Linux builds with tray support enabled:

- **Show/hide logger** toggles the window visibility while keeping the app running.
- **Quit** terminates the viewer process and removes the tray indicator.
- **Official documentation** opens the project docs at: https://github.com/toonvanvr/logger/tree/main/docs

### Minimap discoverability

The minimap is the 48dp timeline bar at the bottom of the log view.

- Use it to zoom/pan the visible time range.
- The minimap includes a **Clear** control to “show logs since now” (timeline cut).

### Detached (noninteractive) run — Linux

To run the viewer detached from your terminal (while keeping tray access), use:

```bash
./scripts/run-viewer-detached-linux.sh
```

Behavior:
- Builds `app/build/linux/x64/release/bundle/app` if missing.
- Detaches via `nohup`/`setsid` and writes logs to an on-disk log file.
- Writes a PID file to `$XDG_RUNTIME_DIR/logger/viewer.pid` (fallback `~/.cache/logger/viewer.pid`).
- If the PID file points to a live process, it exits 0 without launching a second instance.

## Workspace Setup

The repository uses **Bun workspaces** for TypeScript package management. The root `package.json` declares:

```json
{
  "workspaces": ["packages/*"]
}
```

Run `bun install` from the repository root to install dependencies for all packages. Cross-package imports resolve automatically via the workspace configuration.
