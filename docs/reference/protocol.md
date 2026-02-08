# Log Entry Protocol Reference

The Logger protocol uses a unified `LogEntry` schema for all transports (HTTP, UDP, TCP, WebSocket). The schema is defined in Zod at `shared/src/log-entry.ts` — that file is the **single source of truth**.

## LogEntry Schema

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

### State Operations (`type: "state"`)

| Field | Type | Description |
|-------|------|-------------|
| `state_key` | `string` | State key for upsert. Unique per session. |
| `state_value` | `unknown` | State value. `null` deletes the key. |

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

### Custom Types (`type: "custom"`)

| Field | Type | Description |
|-------|------|-------------|
| `custom_type` | `string` | Custom type discriminator (e.g., `"chart"`, `"progress"`). |
| `custom_data` | `unknown` | Arbitrary data for the custom renderer. |

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

Requires either `data` (inline base64) or `ref` (upload reference from `POST /api/v1/upload`).

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
| HTTP | `POST /api/v1/log` | Single `LogEntry` JSON body |
| HTTP | `POST /api/v1/logs` | `LogBatch` JSON body |
| UDP | Port 8081 | JSON-encoded `LogEntry` per datagram |
| TCP | Port 8082 | Newline-delimited JSON `LogEntry` |
| WebSocket | Port 8082 | `ServerMessage` / `ViewerMessage` JSON frames |

## Server Messages (Server → Viewer)

Defined in `shared/src/server-message.ts`:

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

Defined in `shared/src/viewer-message.ts`:

| Type | Description |
|------|-------------|
| `subscribe` | Subscribe to sessions with optional filters |
| `unsubscribe` | Unsubscribe from sessions |
| `history_query` | Query historical log entries |
| `rpc_request` | Send RPC to a client application |
| `session_list` | Request current session list |
| `state_query` | Request state snapshot for a session |
