# Log Entry Protocol Reference

The Logger protocol uses a unified `StoredEntry` schema for internal storage. Input is split across three endpoint-specific schemas (`EventMessage`, `DataMessage`, `SessionMessage`) that normalize to `StoredEntry`. Schemas are defined in Zod at `packages/shared/src/` — `stored-entry.ts` is the **single source of truth**.

## StoredEntry Schema

### Core Fields

| Field | Type | Description |
|-------|------|-------------|
| `id` | `string` | Auto-generated or client-provided unique ID. |
| `timestamp` | `string` | ISO 8601 datetime with offset (server-assigned). |
| `session_id` | `string` | Groups logs from a single application run. |
| `kind` | `EntryKind` | Entry discriminator: `session`, `event`, or `data`. |
| `severity` | `Severity` | Log severity level. Default: `"info"`. |
| `received_at` | `string` | ISO 8601 datetime (server-assigned on ingestion). |

### Entry Kinds

```
session | event | data
```

### Severity Levels

```
debug | info | warning | error | critical
```

### Event Fields (kind: event)

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `message` | `string \| null` | `null` | Human-readable text. Supports ANSI escape codes (SGR). |
| `tag` | `string \| null` | `null` | Category label for filtering (max 128 chars). |
| `exception` | `ExceptionData \| null` | `null` | Exception details with stack trace. |
| `parent_id` | `string \| null` | `null` | Parent event ID for tree nesting. Mutually exclusive with `group_id`. |
| `group_id` | `string \| null` | `null` | Flat grouping reference. Mutually exclusive with `parent_id`. |
| `prev_id` | `string \| null` | `null` | Ordering hint: insert after this event. |
| `next_id` | `string \| null` | `null` | Ordering hint: insert before this event. |
| `widget` | `WidgetPayload \| null` | `null` | Rich rendered content (see [WidgetPayload](#widgetpayload)). |
| `replace` | `boolean` | `false` | When true and `id` matches existing entry, update in place. |
| `icon` | `IconRef \| null` | `null` | Iconify icon reference. |
| `labels` | `Record<string, string> \| null` | `null` | Key-value metadata for filtering/searching. |
| `generated_at` | `string \| null` | `null` | ISO 8601 — when the log was originally generated. |
| `sent_at` | `string \| null` | `null` | ISO 8601 — when the log was sent over the wire. |

The `message` field supports ANSI escape codes (SGR sequences). The viewer renders these with syntax-highlighted colors. Use standard `\x1b[...m` sequences for colored output.

### Data Fields (kind: data)

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `key` | `string \| null` | `null` | Unique data key per session (max 256 chars). |
| `value` | `unknown` | `undefined` | Any JSON value. Omit or `null` to delete the key. |
| `override` | `boolean` | `true` | `true` = replace value, `false` = append to history. |
| `display` | `DisplayLocation` | `"default"` | Where to render: `default`, `static`, or `shelf`. |

**State lifecycle:** Sending a data entry with the same `key` and `session_id` upserts the value. Setting `value` to `null` removes the key from the session's state store entirely.

### Session Fields (kind: session)

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `session_action` | `string \| null` | `null` | `"start"`, `"end"`, or `"heartbeat"`. |
| `application` | `ApplicationInfo \| null` | `null` | Application identity (required on `start`). |
| `metadata` | `Record<string, unknown> \| null` | `null` | Arbitrary session metadata. |

## Input Message Types

Three endpoint-specific schemas normalize to `StoredEntry` on the server.

### EventMessage (`POST /api/v2/events`)

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `session_id` | `string` | Yes | Target session. |
| `id` | `string` | No | Client-assigned ID for idempotency/upsert. |
| `severity` | `Severity` | No | Default: `"info"`. |
| `message` | `string` | No | Human-readable text. |
| `tag` | `string` | No | Category label. |
| `exception` | `ExceptionData` | No | Exception details. |
| `parent_id` | `string` | No | Parent event ID (tree nesting). |
| `group_id` | `string` | No | Flat grouping reference. |
| `prev_id` | `string` | No | Insert after this event. |
| `next_id` | `string` | No | Insert before this event. |
| `widget` | `WidgetPayload` | No | Rich rendered content. |
| `replace` | `boolean` | No | Default: `false`. |
| `generated_at` | `string` | No | ISO 8601 generation timestamp. |
| `sent_at` | `string` | No | ISO 8601 send timestamp. |
| `icon` | `IconRef` | No | Iconify icon reference. |
| `labels` | `Record<string, string>` | No | Key-value metadata. |

### DataMessage (`POST /api/v2/data`)

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `session_id` | `string` | Yes | Target session. |
| `key` | `string` | Yes | Unique data key per session (max 256). |
| `value` | `unknown` | No | Any JSON value. |
| `override` | `boolean` | No | Default: `true`. |
| `display` | `DisplayLocation` | No | Default: `"default"`. |
| `widget` | `WidgetConfig` | No | Rendering configuration (`{type, ...}`). |
| `label` | `string` | No | Display name (max 256). |
| `icon` | `IconRef` | No | Iconify icon reference. |

### SessionMessage (`POST /api/v2/session`)

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `session_id` | `string (UUID)` | Yes | Client-generated session UUID. |
| `action` | `string` | Yes | `"start"`, `"end"`, or `"heartbeat"`. |
| `application` | `ApplicationInfo` | Start only | Required when `action` is `"start"`. |
| `metadata` | `Record<string, unknown>` | No | Arbitrary session metadata. |

## WidgetPayload

Discriminated union on `type`. Used in `EventMessage.widget` and `StoredEntry.widget`. Schemas defined in `packages/shared/src/widget.ts`.

| `type` | Description | Key Fields |
|--------|-------------|------------|
| `json` | Arbitrary JSON | `data` |
| `html` | HTML string | `content` |
| `binary` | Base64 data | `data`, `encoding` (`"base64"`) |
| `image` | Image (inline or upload ref) | `data?`, `ref?`, `mime_type?`, `label?`, `width?`, `height?` |
| `table` | Data table | `columns`, `rows`, `highlight_column?`, `sortable?`, `caption?` |
| `progress` | Progress bar/ring | `value`, `max?`, `label?`, `sublabel?`, `color?`, `style?` (`bar`\|`ring`) |
| `kv` | Key-value pairs | `entries[{key,value,icon?,color?}]`, `layout?` (`inline`\|`stacked`) |
| `chart` | Inline chart | `chart_type` (`sparkline`\|`bar`\|`area`\|`dense_bar`), `values?`, `labels?`, `color?`, `height?`, `min?`, `max?`, `title?` |
| `diff` | Side-by-side diff | `before`, `after`, `language?` (`json`\|`yaml`\|`sql`\|`text`), `context_lines?` |
| `tree` | Collapsible tree | `root` (recursive `TreeNode`), `default_expanded_depth?` |
| `timeline` | Event timeline | `events[{label,time,duration_ms?,color?,icon?,meta?}]`, `show_duration?`, `total_label?` |
| `http_request` | HTTP request/response | `method`, `url`, `status?`, `duration_ms?`, headers, body fields |

Example (progress bar via EventMessage):

```json
{
  "session_id": "abc-123",
  "message": "Uploading files",
  "widget": {
    "type": "progress",
    "value": 42,
    "max": 100,
    "label": "Uploading files",
    "style": "bar"
  }
}
```

### TreeNode

Recursive structure used by the `tree` widget:

| Field | Type | Description |
|-------|------|-------------|
| `label` | `string` | Node display text. |
| `icon` | `string` | Optional Iconify reference. |
| `meta` | `string` | Optional metadata text. |
| `color` | `string` | Hex color (`#RRGGBB`). |
| `children` | `TreeNode[]` | Child nodes (max 500). |
| `expanded` | `boolean` | Whether node starts expanded. |

## State Charts

Data keys prefixed with `_chart.` are treated specially by the viewer: they are filtered out of the key-value display and rendered as live-updating inline charts in the state view panel.

The `value` for a chart key must be an object with the following shape:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `chart_type` | `string` | No | Chart variant: `bar` (default), `sparkline`, `area`, `dense_bar`. |
| `values` | `number[]` | Yes | Data points (minimum 2). |
| `title` | `string` | No | Short label displayed above the chart. |
| `color` | `string` | No | Hex color override for the chart fill. |

Example (via `POST /api/v2/data`):

```json
{
  "session_id": "abc-123",
  "key": "_chart.memory",
  "value": {
    "chart_type": "sparkline",
    "values": [120, 135, 128, 142, 150],
    "title": "Heap MB"
  }
}
```

The `dense_bar` variant renders thin vertical bars without gaps, suitable for high-frequency time-series data.

**Chart titles** are truncated with ellipsis (single line, no wrapping). Keep titles short.

**Chart removal:** Set `value` to `null` for the chart key to remove it.

## State Shelf Keys (`_shelf.*`)

Data keys prefixed with `_shelf.` are rendered in a secondary "shelf" area below the main state view. Use `display: "shelf"` or the `_shelf.` key prefix for supplementary status data that should be visible but not prominent.

## Sub-Schemas

### ApplicationInfo

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | `string` | Yes | Application name (1-128 chars). |
| `version` | `string` | No | App version (max 64 chars). |
| `environment` | `string` | No | Environment: `dev`, `staging`, `prod`, etc. (max 64 chars). |

### ExceptionData

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `type` | `string` | — | Exception class/type name. |
| `message` | `string` | — | Error message. |
| `stack_trace` | `string` | — | Stack trace as a string. |
| `source` | `string` | — | File/module where error occurred. |
| `handled` | `boolean` | `true` | Whether the exception was caught. |
| `inner` | `ExceptionData` | — | Inner/cause exception (recursive). |

Example:

```json
{
  "type": "TypeError",
  "message": "Cannot read property 'x' of undefined",
  "stack_trace": "    at handleRequest (src/handler.ts:42:15)\n    at Server.onRequest (src/server.ts:10:5)",
  "source": "src/handler.ts",
  "handled": true,
  "inner": null
}
```

### IconRef

| Field | Type | Description |
|-------|------|-------------|
| `icon` | `string` | Iconify icon reference (e.g., `"mdi:home"`). |
| `color` | `string` | Optional hex color. |
| `size` | `number` | Optional icon size in pixels. |

## Batch Wrapper

Multiple `EventMessage` entries can be sent in a single request to `POST /api/v2/events`:

```json
{
  "entries": [ /* 1-1000 EventMessage objects */ ]
}
```

## Transport Endpoints

| Transport | Endpoint | Format |
|-----------|----------|--------|
| HTTP | `POST /api/v2/session` | SessionMessage JSON body |
| HTTP | `POST /api/v2/events` | EventMessage (single or batch) |
| HTTP | `POST /api/v2/data` | DataMessage JSON body |
| HTTP | `POST /api/v2/upload` | Image file upload |
| HTTP | `GET /api/v2/health` | Health check |
| HTTP | `GET /api/v2/sessions` | List active sessions |
| HTTP | `GET /api/v2/query` | Query stored entries |
| UDP | Port 8081 | JSON-encoded entry per datagram |
| TCP | Port 8082 | Newline-delimited JSON entries |
| WebSocket | `ws://localhost:8080/api/v2/stream` | `ServerBroadcast` / `ViewerCommand` JSON frames |

## Server Messages (Server → Viewer)

Defined in `shared/src/server-broadcast.ts`. Discriminated union on `type`.

| Type | Key Fields | Description |
|------|------------|-------------|
| `event` | `entry: StoredEntry` | Single log entry broadcast. |
| `data_update` | `session_id`, `key`, `value?`, `display?`, `widget?` | Data/state key updated. |
| `session_update` | `session_id`, `action`, `application?` | Session lifecycle change. |
| `session_list` | `sessions: SessionInfo[]` | List of all sessions. |
| `data_snapshot` | `session_id`, `data: Record<string, DataState>` | Full state snapshot for a session. |
| `history` | `query_id`, `entries`, `has_more`, `cursor?`, `source`, `fence_ts?` | Response to history query. |
| `ack` | `ids: string[]` | Acknowledges received entry IDs. |
| `error` | `code`, `message`, `entry_id?` | Error response. |
| `subscribe_ack` | — | Subscription confirmed. |
| `rpc_request` | `rpc_id`, `method`, `args?` | RPC request forwarded from client app. |
| `rpc_response` | `rpc_id`, `result?`, `error?` | RPC response forwarded from client app. |

### SessionInfo

| Field | Type | Description |
|-------|------|-------------|
| `session_id` | `string` | Session identifier. |
| `application` | `ApplicationInfo` | Application identity. |
| `started_at` | `string` | ISO 8601 session start time. |
| `last_heartbeat` | `string` | ISO 8601 last heartbeat. |
| `is_active` | `boolean` | Whether session is active. |
| `log_count` | `number` | Total log entries in session. |
| `color_index` | `number` | Assigned color index for UI. |

### DataState

| Field | Type | Description |
|-------|------|-------------|
| `value` | `unknown` | Current value. |
| `history` | `unknown[]` | Previous values. |
| `display` | `DisplayLocation` | Render location. |
| `widget` | `WidgetConfig` | Optional rendering config. |
| `label` | `string` | Optional display name. |
| `icon` | `IconRef` | Optional icon. |
| `updated_at` | `string` | ISO 8601 last update time. |

## Viewer Messages (Viewer → Server)

Defined in `shared/src/viewer-command.ts`. Discriminated union on `type`.

| Type | Key Fields | Description |
|------|------------|-------------|
| `subscribe` | `session_ids?`, `min_severity?`, `tags?`, `text_filter?` | Subscribe to sessions with optional filters. |
| `unsubscribe` | `session_ids?` | Unsubscribe from sessions. |
| `history` | `query_id`, `from?`, `to?`, `session_id?`, `search?`, `limit?`, `cursor?`, `source?` | Query historical log entries. |
| `rpc_request` | `rpc_id`, `target_session_id`, `method`, `args?` | Send RPC to a client application. |
| `session_list` | — | Request current session list. |
| `data_query` | `session_id` | Request data snapshot for a session. |

**RPC flow:** Viewer sends `rpc_request` (with `target_session_id`) → Server forwards to client session → Client responds → Server sends `rpc_response` back to viewer. The `rpc_id` correlates request and response. RPC is session-scoped with no multi-server routing.

## Image Upload

Images can be sent inline (base64 in `widget.data`) or uploaded separately:

1. `POST /api/v2/upload` with the image file → returns a `ref` ID.
2. Use the `ref` in an event's `widget` field: `{"type": "image", "ref": "upload-id"}`.

This avoids embedding large base64 payloads in log entries.

## Client SDK Architecture

The TypeScript client SDK (`packages/client/`) exposes a `Logger` class that extends `LoggerBase`. Key design notes:

- **Protected methods:** `enqueue()` and `base()` on `LoggerBase` are `protected`. Subclasses (like session-scoped loggers) override behavior through inheritance. These are not accessible to external consumers.
- **Batching:** The client batches log entries via an internal queue (`packages/client/src/queue.ts`) and flushes periodically or when the batch size threshold is reached.
- **Session lifecycle:** Managed by `LoggerSession` — each session gets a unique `session_id` and handles `start`/`end`/`heartbeat` actions automatically.
