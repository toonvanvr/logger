# Features

An overview of the Logger viewer's capabilities.

## Severity Levels

Log entries are categorised by severity: `trace`, `debug`, `info`, `warn`, `error`, `fatal`. Each level has a distinct colour in the viewer for quick visual scanning.

## Custom Renderers

The viewer detects structured content types and renders them with purpose-built widgets:

- **Progress** — renders a progress bar with percentage
- **Table** — displays tabular data with headers and rows
- **Key-Value** — shows structured metadata as aligned pairs
- **Stack Trace** — collapsible, syntax-highlighted error traces with source links

## ANSI Color Support

Log text containing ANSI SGR escape codes is parsed and rendered with the corresponding colors and styles. Supported attributes include foreground/background colors (standard, bright, 256-color, and 24-bit RGB), bold, dim, italic, and underline.

The client SDK provides a `color` namespace with helper functions:

```typescript
import { red, bold, rgb, strip } from "@logger/client/color";

logger.info(red("Connection lost"));
logger.info(bold(rgb(255, 165, 0, "custom orange")));
```

Available helpers: `red`, `green`, `yellow`, `blue`, `magenta`, `cyan`, `white`, `gray`, `bold`, `dim`, `italic`, `underline`, `rgb`, `bgRgb`, `color256`, `strip`.

## Text Selection

Text in log rows is selectable via mouse drag. Click and drag across log entries to select text for copying. The selection works across multiple log rows.

## Copy Overlay

Hovering over a log row reveals a gradient overlay on the right edge with a copy icon. Clicking the icon copies the row's text content to the clipboard.

## Stack Trace Expansion

Stack traces support incremental expansion. Instead of toggling the full trace, controls let you:

- **Expand 5 more** — reveal the next 5 frames
- **Expand all** — show the entire trace

Cause chains are visually separated with a left-border indicator. Expand/collapse transitions use `AnimatedSize` for smooth animation.

## State Charts

State keys prefixed with `_chart.` are rendered as live-updating inline charts in the state view panel. Charts appear in a horizontal scrollable strip above the key-value list.

To push chart data from the client SDK:

```typescript
logger.state("_chart.cpu", {
  type: "sparkline",
  values: [12, 45, 33, 67, 55],
  title: "CPU %",
});
```

Supported chart types: `bar`, `sparkline`, `area`, `dense_bar`. See the [Protocol Reference](../reference/protocol.md#state-charts) for the full schema.

## Session Management

Every log entry belongs to a session. The sidebar lists all active and historical sessions, and clicking a session filters the log view to only that session's entries.

## Filtering

The filter bar at the top of the viewer supports:

- **Severity filter** — show only entries at or above a chosen level
- **Text search** — free-text filter across all entry fields
- **Source filter** — filter by originating module
- **Tag filter** — filter by metadata tags

## Real-Time Updates

Logs stream over a WebSocket connection with sub-second latency. New entries appear at the bottom of the scrolling view. The viewer auto-scrolls when viewing the latest entries but pauses auto-scroll when the user scrolls up to review history.

## Grafana Integration

Pre-built Grafana dashboards provide aggregate views:

- **Logger Overview** — volume, severity distribution, top sources
- **Server Health** — ingestion rate, connection count, memory
- **Session Detail** — per-session timeline and statistics

## Sticky Functionality

Log entries and group headers can be marked as `sticky`. When scrolled past, sticky entries pin to the top of the viewport, providing persistent context while browsing related entries below. This is especially useful for group headers and important state changes.

To mark an entry as sticky from the client SDK:

```typescript
logger.log({ sticky: true, text: "Request context", ... });
```

## Plugin System

The viewer uses a plugin architecture for extensible rendering and filtering. Plugins register with a global `PluginRegistry` and are discovered automatically.

**Plugin types:**
- **Renderer** — renders custom log entry types (chart, progress, table, key-value)
- **Filter** — custom filtering logic with autocomplete
- **Transform** — text transformations on log content
- **Tool** — adds tool panels to the UI

Built-in plugins: chart, progress, table, key-value, smart search, log type filter, ID uniquifier.

See the [Plugin API Reference](../reference/plugin-api.md) for details on writing custom plugins.

## ID Uniquifier

The ID Uniquifier plugin detects ambiguous or duplicate log entry IDs and appends suffixes to make them visually distinguishable. This helps when multiple entries share the same base ID pattern.

## Smart Search

The Smart Search plugin provides intelligent log filtering with:
- Autocomplete suggestions based on current log content
- Fuzzy matching across all entry fields
- Search history

## Chart Renderer

Log entries with `type: "custom"` and `custom_type: "chart"` are rendered as inline visualizations. The chart plugin supports data passed via the `custom_data` field.

## Entry Highlight

Newly arrived log entries briefly highlight to draw attention, then fade quickly so they don't distract from reading.

## Tab Simplification

When a session has only one section, the section tab bar is hidden automatically to reduce visual clutter.

## Status Bar

The viewer includes a status bar showing:
- Connection status (connected/disconnected/reconnecting)
- Current session count
- Log entry count
- Active filters
