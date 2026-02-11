# Docker Sidecar Reference

The Docker sidecar (`packages/docker-sidecar/`) captures container stdout/stderr and forwards them as structured Logger entries. Each container gets its own Logger session.

## How It Works

1. Connects to the Docker socket (`/var/run/docker.sock`)
2. Attaches to all running containers on startup
3. Listens for container `start`/`die` events to auto-attach/detach
4. Parses log lines, detects severity via keyword heuristics
5. Forwards entries to the Logger server using the client SDK

## Quick Start

### Docker Compose (recommended)

```yaml
services:
  logger-sidecar:
    image: logger-sidecar
    build: packages/docker-sidecar
    environment:
      - LOGGER_SERVER_URL=http://logger-server:8080
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
```

### Standalone

```bash
cd packages/docker-sidecar
LOGGER_SERVER_URL=http://localhost:8080 bun run src/main.ts
```

## Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `DOCKER_SOCKET` | `/var/run/docker.sock` | Docker socket path. |
| `LOGGER_SERVER_URL` | `http://localhost:8080` | Logger server endpoint for log forwarding. |
| `CONTAINER_FILTER` | *(empty)* | Filter containers by label. Format: `label=key=value`. Empty = all containers. |

## Container Filtering

When `CONTAINER_FILTER` is set, only containers whose labels match are tracked:

```bash
# Only track containers with label "logger=true"
CONTAINER_FILTER=label=logger=true
```

When empty (default), all running containers are tracked.

## Severity Detection

Log lines are classified by keyword heuristics:

| Keywords | Severity |
|----------|----------|
| `ERROR`, `FATAL`, `PANIC` | `error` |
| `WARN` | `warning` |
| `DEBUG`, `TRACE` | `debug` |
| *(default)* | `info` |

Detection is case-insensitive and searches the full log line.

## Session Naming

Each container gets a session with:
- **Session ID**: `docker-{container_id_short}` (first 12 chars)
- **App name**: Container name (without leading `/`)
- **Transport**: HTTP (always)

Sessions start on container attach and end on container detach or die.

## Architecture

| File | Purpose |
|------|---------|
| `main.ts` | Entry point — event loop, container lifecycle |
| `config.ts` | Environment variable configuration |
| `types.ts` | TypeScript type definitions |
| `docker-client.ts` | Docker socket HTTP client |
| `log-parser.ts` | Log line parsing and severity detection |

## Limitations

- Reads decoded text lines only (no raw Docker multiplexed frames)
- Severity detection is heuristic-based — structured JSON logs are forwarded as plain text
- The sidecar uses HTTP transport exclusively (no WebSocket/RPC)
- Reconnects to the Docker event stream on error after a 2-second delay
