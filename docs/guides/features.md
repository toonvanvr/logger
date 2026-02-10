# Features

An overview of the Logger viewer's capabilities.

## Severity Levels

Log entries are categorised by severity: `debug`, `info`, `warning`, `error`, `critical`. Each level has a distinct colour in the viewer for quick visual scanning.

## Custom Renderers

![Custom Renderers](../screenshots/02-custom-renderers.png)

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

![Error with Stack Trace](../screenshots/03-error-stack-trace.png)

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

![Session Selection](../screenshots/04-session-selection.png)

Every log entry belongs to a session. The sidebar lists all active and historical sessions, and clicking a session filters the log view to only that session's entries.

## Filtering

![Filter Bar](../screenshots/05-filter-bar.png)

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

Group headers automatically pin to the top of the viewport when scrolled past, providing persistent context while browsing related entries below. Users can also manually pin selected entries via the selection context menu. This is especially useful for group headers and important state changes.

Sticky headers are rendered from group entries. The viewer automatically pins group headers to the viewport top when their content is scrolled past.

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

Log entries with `widget.type: "chart"` are rendered as inline visualizations. The chart plugin supports various chart types via the widget payload: sparkline, bar, area, and dense_bar.

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

## Historical Log Access

The viewer can retrieve historical logs from Loki when scrolling back beyond the in-memory ring buffer. This provides seamless access to older log entries without losing real-time streaming for new entries.

## HTTP Request Tracking

![HTTP Requests](../screenshots/08-http-requests.png)

Log entries with `widget.type: "http_request"` are rendered as expandable HTTP request/response panels in HAR-inspired format. The HTTP request plugin displays method, URL, status code, headers, and body with syntax highlighting.

## Secondary State Shelves

State keys can be organized into named shelves for grouping related state. Shelf cards appear as collapsible sections in the state view panel, keeping the state view organized when applications track many keys.

## Empty Landing Page

When no sessions are active, the viewer displays a friendly landing page with connection status and quick-start guidance instead of a blank screen.

## Mini Mode

Logger launches in mini mode by default — a compact window designed to sit alongside your editor or dashboard as a monitoring companion rather than a primary application. Mini mode provides:

- **Icon-only controls** at 32dp for comfortable targeting
- **Severity bar scanning** — see error patterns at a glance without expanding
- **Always-on-top pinning** — keep Logger visible while working in other windows
- **Draggable title bar** — reposition freely without a system title bar

Resize or double-click the title bar to expand into compact or full mode for detailed investigation, then shrink back to mini mode when done.

## Filter Stack

Interactive elements throughout the UI act as filter shortcuts. Clicking a state tag, session badge, or severity indicator adds a filter — no typing required.

- **Click to add** — click any state tag or badge to add it as a filter; the filter bar appears automatically
- **Visual pills** — each active filter shows as a removable pill in the filter bar
- **Stacking** — filters combine with AND logic (like `grep A | grep B`); add more to narrow results
- **Click to remove** — click the × on any pill to remove that filter without clearing others
- **Clear all** — the live pill button clears the entire filter stack in one click
- **Visual feedback** — filtered source elements show an accent indicator so you can see what's active

## URI Scheme

Logger registers a `logger://` URI scheme for automation and sharing. URIs can be used in shell scripts, Makefiles, CI annotations, Slack messages, and runbook links.

**Examples:**

| URI | Action |
|-----|--------|
| `logger://connect?host=localhost&port=8080` | Open Logger and connect to a server |
| `logger://filter?severity=error` | Set the severity filter to error and above |
| `logger://clear` | Clear the current log view |

On Linux, the URI scheme requires a `.desktop` file to be registered (included in release builds). From a shell: `xdg-open 'logger://connect?host=staging&port=8080'`.

## Self-Logging

The server can log its own internal events (startup, connections, errors) as structured log entries visible in the viewer. This aids in debugging the Logger infrastructure itself.
