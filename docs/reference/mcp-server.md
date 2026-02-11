# MCP Server Reference

The Logger MCP server (`packages/mcp/`) exposes Logger functionality to AI agents via the [Model Context Protocol](https://modelcontextprotocol.io/). It connects to the Logger server's HTTP API and provides tools for querying logs, sending entries, and invoking RPC.

## Setup

### With Claude Desktop

Add to `~/.config/claude/claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "logger": {
      "command": "bun",
      "args": ["run", "/path/to/logger/packages/mcp/src/index.ts"],
      "env": {
        "LOGGER_URL": "http://localhost:8080"
      }
    }
  }
}
```

### Standalone

```bash
cd packages/mcp
LOGGER_URL=http://localhost:8080 bun run src/index.ts
```

The server uses **stdio transport** — it reads JSON-RPC from stdin and writes to stdout.

## Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `LOGGER_URL` | `http://localhost:8080` | Logger server HTTP endpoint. |
| `LOGGER_API_KEY` | *(empty)* | API key for authenticated access. Sent as `x-api-key` header. |

## Tools

### `logger.query`

Query Logger server data: health, sessions, state, or log entries.

| Parameter | Type | Description |
|-----------|------|-------------|
| `scope` | `"health" \| "sessions" \| "state" \| "logs"` | What to query. Default: `"logs"`. |
| `sessionId` | `string?` | Required for `state`, optional filter for `logs`. |
| `severity` | `Severity?` | Filter by severity (`logs` only). |
| `from` | `string?` | Start of time range, ISO 8601 (`logs` only). |
| `to` | `string?` | End of time range, ISO 8601 (`logs` only). |
| `limit` | `number?` | Max entries, 1–1000, default 20 (`logs` only). |
| `search` | `string?` | Full-text search (`logs` only). |

### `logger.send`

Send a log entry to the Logger server.

| Parameter | Type | Description |
|-----------|------|-------------|
| `severity` | `Severity` | Log severity level. |
| `text` | `string` | Log message text. |
| `session` | `string?` | Session ID. Default: `"mcp"`. |

### `logger.rpc`

Invoke an RPC method on a connected client session.

| Parameter | Type | Description |
|-----------|------|-------------|
| `sessionId` | `string` | Target session ID. |
| `method` | `string` | RPC method name. |
| `args` | `unknown?` | Arguments to pass. |
