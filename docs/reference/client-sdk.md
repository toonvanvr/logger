# Client SDK API Reference

The Logger client SDK (`@logger/client`) is a lightweight TypeScript library for sending structured logs to the Logger server. Install via the Bun workspace — no separate publish step.

## Quick Start

```typescript
import { Logger } from "@logger/client";

const logger = new Logger({ app: "my-app" });
logger.info("Application started");
logger.error(new Error("Something broke"));
await logger.flush();
await logger.close();
```

With no explicit `url` or `transport`, the SDK defaults to `ws://localhost:8080` and `transport: "auto"` (tries WebSocket first, then falls back to HTTP).

## Logger Class

### Constructor

```typescript
new Logger(options?: LoggerOptions)
```

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `url` | `string` | `process.env.LOGGER_URL ?? ws://localhost:8080` | Server URL used by the selected transport. |
| `app` | `string` | `process.env.npm_package_name` | Application name attached to all entries. |
| `environment` | `string` | `process.env.LOGGER_ENVIRONMENT ?? "dev"` | Environment label. |
| `transport` | `TransportType` | `"auto"` | `"auto"` \| `"http"` \| `"ws"` \| `"udp"` \| `"tcp"`. |
| `middleware` | `Middleware[]` | `[]` | Functions that intercept entries before queuing. |
| `maxQueueSize` | `number` | `8 MB` | Max byte budget for the outgoing queue. |
| `sessionId` | `string` | Random UUID | Override the session ID. |

### Log Methods

```typescript
logger.debug(message, meta?)   // severity: debug
logger.info(message, meta?)    // severity: info
logger.warn(message, meta?)    // severity: warning
logger.error(message | Error, meta?)  // severity: error
logger.critical(message | Error, meta?)  // severity: critical
```

When passed an `Error`, the SDK extracts `type`, `message`, `stack_trace`, and nested `cause` chains into an `exception` field.

### Structured Methods

```typescript
logger.json(data, { severity? })      // JSON widget
logger.html(content, { severity? })   // HTML widget
logger.binary(data, { severity? })    // Binary hex dump widget
logger.state(key, value)              // Persistent key-value state
logger.image(data, mime, { id? })     // Inline image
logger.custom(type, data, { id?, replace? })  // Custom widget type
```

### Convenience Widgets

```typescript
logger.table(columns, rows)                    // Table widget
logger.progress(label, value, max, { id? })    // Progress bar (auto-replace)
logger.kv(entries, { id? })                    // Key-value pairs (auto-replace)
logger.http(method, url, { status?, duration_ms?, ... })  // HTTP request widget
```

### Modifiers (One-Shot)

Modifiers apply to the next logged entry only, then reset.

```typescript
logger.sticky().info("Pinned message")    // Pin to viewport top
logger.unsticky(groupId, entryId?)        // Unpin a sticky entry
logger.withId("custom-id").info("msg")    // Override entry ID
logger.after("prev-id").info("msg")       // Insert after entry
logger.before("next-id").info("msg")      // Insert before entry
```

### Groups

```typescript
// Manual open/close
const groupId = logger.group("Deploy");
logger.info("Step 1");
logger.groupEnd();

// Auto-close with callback
await logger.group("Deploy", async () => {
  logger.info("Step 1");
});
```

### Sections

```typescript
logger.section("database");   // Tag subsequent entries
logger.info("Query executed"); // tagged with "database"
```

### Session Control

```typescript
logger.session.id;                    // Read session ID
logger.session.start({ version: "1.0" });  // Explicit start with metadata
logger.session.end();                 // End session
```

Sessions auto-start on first log entry if not explicitly started.

### RPC

```typescript
logger.rpc.register("getStatus", {
  description: "Returns app status",
  category: "getter",
  handler: async (args) => ({ status: "ok" }),
});
logger.rpc.unregister("getStatus");
```

### Middleware

```typescript
logger.use((entry, next) => {
  entry.labels = { ...entry.labels, env: "staging" };
  next(); // Call next() to continue, or omit to drop the entry
});
```

### Lifecycle

```typescript
await logger.flush();  // Drain the queue immediately
await logger.close();  // Flush + close transport
```

## Queue Behavior

The SDK buffers entries in a `LogQueue` (circular buffer, default 8 MB). A drain timer flushes every 100ms. If the queue reaches its byte budget, new entries are dropped (returns `false`).

## Transport Selection

When `transport: "auto"` (default), the SDK tries WebSocket first and falls back to HTTP if WS connection fails.

| URL Scheme | Transport | Behavior |
|------------|-----------|----------|
| `http://` / `https://` | HTTP | Batch POST per drain cycle (`/api/v2/session`, `/api/v2/events`, `/api/v2/data`) |
| `ws://` / `wss://` | WebSocket | Persistent connection; if path is missing, SDK uses `/api/v2/stream` |
| `udp://` | UDP | Fire-and-forget datagrams |
| explicit `transport: "tcp"` | TCP | Newline-delimited JSON over TCP |

RPC registration/response is supported only on WebSocket transport. HTTP/UDP/TCP skip RPC frames.

## Exports

The package exports `Logger`, `LoggerOptions`, `Middleware`, `Severity`, `MessageKind`, `QueuedMessage`, `createTransport`, `TransportType`, `TransportAdapter`, `LogQueue`, `parseStackTrace`, and `color` helpers.
