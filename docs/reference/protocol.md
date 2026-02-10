# Log Entry Protocol Reference

The Logger protocol uses a unified `StoredEntry` schema for internal storage. Input is split across three endpoint-specific schemas (`EventMessage`, `DataMessage`, `SessionMessage`) that normalize to `StoredEntry`. Schemas are defined in Zod at `packages/shared/src/` — `stored-entry.ts` is the **single source of truth** for the internal model.

## StoredEntry Schema

### Required Fields

| Field | Type | Description |
|-------|------|-------------|
| `id` | `string` | Client-assigned unique ID (UUID or custom string). |
| `timestamp` | `string` | ISO 8601 datetime with offset and millisecond precision. |
| `session_id` | `string` | Groups logs from a single application run. |
| `severity` | `Severity` | Log severity level. |
| `type` | `LogType` | Discriminator for log entry content type. |

### Severity Levels

```
debug | info | warning | error | critical
```

### Log Types

```
text | json | html | binary | image | state | group | rpc | session | custom
```

### Optional Metadata Fields

| Field | Type | Description |
|-------|------|-------------|
| `application` | `ApplicationInfo` | Application name, version, environment. |
| `section` | `string` | UI section this log belongs to. Defaults to `"events"`. |
| `tags` | `Record<string, string>` | Arbitrary key-value tags for filtering/searching. |
| `icon` | `IconRef` | Iconify icon reference (e.g., `"mdi:home"`). |

### Content Fields (type-dependent)

| Field | Used When | Type | Description |
|-------|-----------|------|-------------|
| `text` | `type: "text"` | `string` | Plain text content. |
| `json` | `type: "json"` | `unknown` | Arbitrary JSON payload. |
| `html` | `type: "html"` | `string` | HTML string content. |
| `binary` | `type: "binary"` | `string` | Base64-encoded binary data. |
| `image` | `type: "image"` | `ImageData` | Image data (inline base64 or upload reference). |

The `text` field supports ANSI escape codes (SGR sequences). The viewer renders these with syntax-highlighted colors. Use standard `\x1b[...m` sequences for colored output.

### Exception Data

| Field | Type | Description |
|-------|------|-------------|
| `exception` | `ExceptionData` | Exception or error details with stack trace. Can accompany any log type. |

See [ExceptionData](#exceptiondata) under Sub-Schemas for the full shape.

### Group Operations

Groups allow collapsible log sections.

| Field | Type | Description |
|-------|------|-------------|
| `group_id` | `string` | Shared by all entries in a group. |
| `group_action` | `"open" \| "close"` | Opens or closes the group. |
| `group_label` | `string` | Display label (used with `group_action: "open"`). |
| `group_collapsed` | `boolean` | Whether the group starts collapsed. |

### Sticky Pinning

| Field | Type | Description |
|-------|------|-------------|
| `sticky` | `boolean` | When true, this entry pins to the viewport top when scrolled past. |
| `sticky_action` | `"pin" \| "unpin"` | Action to perform: `pin` (default when sticky=true) or `unpin` (remove from sticky). |

### State Operations (`type: "state"`)

| Field | Type | Description |
|-------|------|-------------|
| `state_key` | `string` | State key for upsert. Unique per session. |
| `state_value` | `unknown` | State value. `null` deletes the key. |

**State lifecycle:** Sending a state entry with the same `state_key` and `session_id` upserts the value. Setting `state_value` to `null` removes the key from the session's state store entirely. This is how charts and other stateful UI elements are cleaned up.

### Session Control (`type: "session"`)

| Field | Type | Description |
|-------|------|-------------|
| `session_action` | `"start" \| "end" \| "heartbeat"` | Session lifecycle action. |

### Ordering Hints

| Field | Type | Description |
|-------|------|-------------|
| `after_id` | `string` | Insert this entry visually after the entry with this ID. |
| `before_id` | `string` | Insert this entry visually before the entry with this ID. |

### In-Place Updates

| Field | Type | Description |
|-------|------|-------------|
| `replace` | `boolean` | When true and `id` matches an existing entry, update in place. |

### 2-Way RPC (`type: "rpc"`)

| Field | Type | Description |
|-------|------|-------------|
| `rpc_id` | `string (UUID)` | Unique RPC call ID. |
| `rpc_direction` | `"request" \| "response" \| "error"` | Direction of the RPC message. |
| `rpc_method` | `string` | RPC method name. |
| `rpc_args` | `unknown` | Arguments (request direction). |
| `rpc_response` | `unknown` | Response data (response direction). |
| `rpc_error` | `string` | Error message (error direction). |

**RPC routing:** RPC is session-scoped. The viewer's `rpc_request` message includes a `target_session_id` field that routes the request to the specific client session. There is no multi-server RPC routing — each request targets exactly one session on one server connection.

**RPC flow:** Viewer sends `rpc_request` → Server forwards to client session → Client responds → Server sends `rpc_response` back to viewer. The `rpc_id` correlates request and response.

### Custom Types (`type: "custom"`)

| Field | Type | Description |
|-------|------|-------------|
| `custom_type` | `string` | Custom type discriminator (e.g., `"chart"`, `"progress"`). |
| `custom_data` | `unknown` | Arbitrary data for the custom renderer. |

#### Built-in Custom Renderers

The following `custom_type` values have built-in renderer support. Widget schemas are defined in `packages/shared/src/widget.ts`.

| `custom_type` | Description | Key `custom_data` Fields |
|---------------|-------------|---------------------------|
| `progress` | Progress bar or ring | `value`, `max`, `label`, `sublabel`, `color`, `style` (`bar`\|`ring`) |
| `chart` | Inline chart | `type` (`sparkline`\|`bar`\|`area`\|`dense_bar`), `values`, `labels`, `color`, `height`, `min`/`max`, `title` |
| `table` | Data table | `columns`, `rows`, `highlight_column`, `sortable`, `caption` |
| `kv` | Key-value pairs | `entries` (`[{key, value, icon?, color?}]`), `layout` (`inline`\|`stacked`) |
| `diff` | Side-by-side diff | `before`, `after`, `language` (`json`\|`yaml`\|`sql`\|`text`), `context_lines` |
| `tree` | Collapsible tree | `root` (recursive `TreeNode`), `default_expanded_depth` |
| `timeline` | Event timeline | `events` (`[{label, time, duration_ms?, color?, icon?}]`), `show_duration`, `total_label` |
| `http_request` | HTTP request/response | `method`, `url`, `status`, `duration_ms`, headers, body fields |

Example (progress bar):

```json
{
  "type": "custom",
  "custom_type": "progress",
  "custom_data": {
    "value": 42,
    "max": 100,
    "label": "Uploading files",
    "style": "bar"
  }
}
```

### State Charts

State keys prefixed with `_chart.` are treated specially by the viewer: they are filtered out of the key-value display and rendered as live-updating inline charts in the state view panel.

The `state_value` for a chart key must be an object with the following shape:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `type` | `string` | No | Chart variant: `bar` (default), `sparkline`, `area`, `dense_bar`. |
| `values` | `number[]` | Yes | Data points (minimum 2). |
| `title` | `string` | No | Short label displayed above the chart. |
| `color` | `string` | No | Hex color override for the chart fill. |

Example:

```json
{
  "state_key": "_chart.memory",
  "state_value": {
    "type": "sparkline",
    "values": [120, 135, 128, 142, 150],
    "title": "Heap MB"
  }
}
```

The `dense_bar` variant renders thin vertical bars without gaps, suitable for high-frequency time-series data.

**Chart titles** are truncated with ellipsis (single line, no wrapping). Keep titles short.

**Chart count:** There is no maximum number of charts per session. Charts display in a horizontal scrollable list. Performance is fine since charts are lightweight widgets.

**Chart removal:** Set `state_value` to `null` for the chart key to remove it (see [State Operations](#state-operations-type-state)).

### State Shelf Keys (`_shelf.*`)

State keys prefixed with `_shelf.` are rendered in a secondary "shelf" area below the main state view. Use these for supplementary status data that should be visible but not prominent.

### Timing Metadata

| Field | Type | Description |
|-------|------|-------------|
| `generated_at` | `string (ISO 8601)` | When the log was originally generated. |
| `sent_at` | `string (ISO 8601)` | When the log was sent over the wire. |

## Sub-Schemas

### ApplicationInfo

```json
{
  "name": "my-api-server",
  "version": "1.2.3",
  "environment": "development"
}
```

### ExceptionData

```json
{
  "type": "TypeError",
  "message": "Cannot read property 'x' of undefined",
  "stackTrace": [
    {
      "location": { "uri": "src/handler.ts", "line": 42, "column": 15, "symbol": "handleRequest" },
      "isVendor": false,
      "raw": "    at handleRequest (src/handler.ts:42:15)"
    }
  ],
  "cause": null
}
```

### ImageData

```json
{
  "data": "<base64>",
  "ref": "upload-id-from-post-api",
  "mimeType": "image/png",
  "label": "Screenshot",
  "width": 800,
  "height": 600
}
```

Requires either `data` (inline base64) or `ref` (upload reference from `POST /api/v2/upload`).

### IconRef

```json
{
  "icon": "mdi:home",
  "color": "#FF0000",
  "size": 14
}
```

## Batch Wrapper

Multiple entries can be sent in a single request:

```json
{
  "entries": [ /* 1-1000 LogEntry objects */ ]
}
```

## Transport Endpoints

| Transport | Endpoint | Format |
|-----------|----------|--------|
| HTTP | `POST /api/v2/session` | Session lifecycle JSON body |
| HTTP | `POST /api/v2/events` | Event log entries (single or batch) |
| HTTP | `POST /api/v2/data` | Data/state entries |
| HTTP | `POST /api/v2/upload` | Image upload |
| HTTP | `GET /api/v2/health` | Health check |
| HTTP | `GET /api/v2/sessions` | List active sessions |
| HTTP | `GET /api/v2/query` | Query stored entries |
| UDP | Port 8081 | JSON-encoded entry per datagram |
| TCP | Port 8082 | Newline-delimited JSON entries |
| WebSocket | Port 8082 | `ServerBroadcast` / `ViewerCommand` JSON frames |

## Server Messages (Server → Viewer)

Defined in `shared/src/server-broadcast.ts`:

| Type | Description |
|------|-------------|
| `ack` | Acknowledges received log entry IDs |
| `error` | Error response |
| `log` | Single log entry broadcast |
| `logs` | Batch of log entries |
| `history` | Response to history query |
| `session_list` | List of all sessions |
| `session_update` | Session status change |
| `state_snapshot` | Full state for a session |
| `rpc_request` | RPC request forwarded from client app |
| `rpc_response` | RPC response forwarded from client app |
| `subscribe_ack` | Subscription confirmed |

## Viewer Messages (Viewer → Server)

Defined in `shared/src/viewer-command.ts`:

| Type | Description |
|------|-------------|
| `subscribe` | Subscribe to sessions with optional filters |
| `unsubscribe` | Unsubscribe from sessions |
| `history_query` | Query historical log entries |
| `rpc_request` | Send RPC to a client application |
| `session_list` | Request current session list |
| `state_query` | Request state snapshot for a session |

## Image Upload

Images can be sent inline (base64 in `image.data`) or uploaded separately:

1. `POST /api/v2/upload` with the image file → returns a `ref` ID
2. Use `image.ref` in a subsequent log entry with `type: "image"`

This avoids embedding large base64 payloads in log entries.

## Client SDK Architecture

The TypeScript client SDK (`packages/client/`) exposes a `Logger` class that extends `LoggerBase`. Key design notes:

- **Protected methods:** `enqueue()` and `base()` on `LoggerBase` are `protected`. Subclasses (like session-scoped loggers) override behavior through inheritance. These are not accessible to external consumers.
- **Batching:** The client batches log entries via an internal queue (`packages/client/src/queue.ts`) and flushes periodically or when the batch size threshold is reached.
- **Session lifecycle:** Managed by `LoggerSession` — each session gets a unique `session_id` and handles `start`/`end`/`heartbeat` actions automatically.
