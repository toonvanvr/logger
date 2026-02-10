# AGENTS.md

AI agent navigation guide for the Logger repository.

## Project Overview

Logger is a **real-time structured log viewer** for application debugging. Applications push structured logs via a TypeScript client SDK to a Bun-based server, which stores them in an in-memory ring buffer and forwards to Grafana Loki. A Flutter desktop app provides live log viewing with rich rendering, filtering, and bidirectional RPC.

**Key traits:** local-dev tool, not production SaaS. No auth by default. Linux-first desktop app.

## Repository Structure

```
logger/
├── app/              Flutter desktop viewer (Dart)
│   ├── lib/
│   │   ├── main.dart
│   │   ├── models/       Data models (LogEntry, Session, etc.)
│   │   ├── plugins/      Plugin system (registry, types, builtin/)
│   │   ├── screens/      Top-level screens
│   │   ├── services/     WebSocket, state management, connection manager
│   │   ├── theme/        Color system, typography
│   │   └── widgets/      Reusable UI components
│   │       ├── header/       Session button, severity toggle, bookmark
│   │       ├── landing/      Empty landing page
│   │       ├── log_list/     List builder, filter cache, selection actions, sticky headers
│   │       ├── mini_mode/    Dense mini-mode title bar
│   │       ├── renderers/    Log content renderers (ANSI, text, JSON, custom/)
│   │       ├── rpc/          RPC request/response UI
│   │       ├── settings/     Tool groups, connection CRUD, sub-panels
│   │       ├── state_view/   Collapsible persistent state sections
│   │       ├── status_bar/   Connection status, counts, active filters
│   │       └── time_travel/  Time range zoom/pan minimap
│   └── test/             Widget & unit tests
├── packages/         All TypeScript packages
│   ├── client/       TypeScript client SDK
│   │   └── src/
│   │       ├── logger.ts         Client SDK entry point
│   │       ├── logger-session.ts Session lifecycle
│   │       ├── logger-builders.ts  Fluent log builders
│   │       ├── logger-types.ts   Client type definitions
│   │       ├── queue.ts          Batching queue
│   │       └── stack-parser.ts   Stack trace parser
│   ├── server/       Bun-based log server (TypeScript)
│   │   └── src/
│   │       ├── main.ts           Entry point, module wiring
│   │       ├── core/             Config, normalizer, hooks, rate limiter
│   │       ├── modules/          Ring buffer, Loki forwarder, session mgr, RPC bridge, WS hub
│   │       ├── store/            Storage abstractions
│   │       └── transport/        HTTP, WebSocket, UDP, TCP handlers
│   ├── shared/       Shared types & schemas (TypeScript)
│   │   └── src/
│   │       ├── stored-entry.ts     StoredEntry Zod schema (source of truth)
│   │       ├── event-message.ts    Event log input schema
│   │       ├── data-message.ts     Data/state input schema
│   │       ├── session-message.ts  Session lifecycle input schema
│   │       ├── server-broadcast.ts Server→Viewer broadcast messages
│   │       ├── viewer-command.ts   Viewer→Server command messages
│   │       ├── widget.ts           Widget/custom renderer type definitions
│   │       └── constants.ts        Shared constants
│   ├── docker-sidecar/ Docker container log forwarding sidecar
│   ├── mcp/          MCP tool server for AI debugging
│   └── demo/         Demo log generator with scenarios
├── infra/            Infrastructure configs
│   ├── grafana/      Dashboard & datasource configs
│   └── loki/         Loki configuration
├── scripts/          Automation (screenshot capture, etc.)
├── docs/             Documentation hub
│   ├── architecture/ Architecture overview & ADRs
│   ├── guides/       How-to guides
│   ├── reference/    API & config reference
│   ├── design/       UX & visual design specs
│   └── screenshots/  Auto-generated screenshots
└── compose.yml       Docker Compose (Loki + Grafana + Server + Demo)
```

## Key Files

| File | Purpose |
|------|---------|
| `packages/shared/src/stored-entry.ts` | **StoredEntry Zod schema** — single source of truth for the log protocol |
| `packages/shared/src/server-broadcast.ts` | Server→Viewer WebSocket broadcast messages |
| `packages/shared/src/viewer-command.ts` | Viewer→Server WebSocket command messages |
| `packages/server/src/main.ts` | Server entry point — wires all modules together |
| `packages/server/src/core/config.ts` | All server configuration via env vars |
| `packages/server/src/transport/http.ts` | HTTP route definitions (`/api/v2/` — ingestion, health, upload) |
| `packages/server/src/transport/ws.ts` | WebSocket handler for viewer connections |
| `packages/server/src/transport/ingest.ts` | Log ingestion pipeline (single `ingest()` function) |
| `packages/server/src/core/normalizer.ts` | Normalizes input messages to StoredEntry |
| `packages/server/src/modules/ring-buffer.ts` | In-memory log storage with eviction |
| `packages/server/src/modules/loki-forwarder.ts` | Async batch forwarding to Loki |
| `packages/server/src/modules/session-manager.ts` | Session lifecycle tracking |
| `packages/server/src/modules/rpc-bridge.ts` | Bidirectional RPC between viewer and clients |
| `packages/client/src/logger.ts` | Client SDK — main Logger class |
| `app/lib/main.dart` | Flutter app entry point |
| `app/lib/plugins/plugin_registry.dart` | Plugin registry singleton |
| `app/lib/plugins/plugin_types.dart` | Plugin base interfaces (Renderer, Filter, Transform, Tool) |
| `app/lib/services/connection_manager.dart` | Multi-server connection management with auto-reconnect |
| `app/lib/services/time_range_service.dart` | Time range zoom/pan state management |
| `app/lib/services/log_store.dart` | In-memory log storage with filtering |
| `app/lib/services/log_store_stacking.dart` | Entry stacking (version history) logic |
| `app/lib/screens/log_viewer_keyboard.dart` | Keyboard shortcut handler for log viewer |
| `app/lib/widgets/header/filter_bar.dart` | Search/filter bar with autocomplete |
| `app/lib/widgets/log_list/log_list_view.dart` | Scrollable log list with live mode |
| `app/lib/widgets/state_view/state_view_section.dart` | Persistent state key-value view section |
| `app/lib/widgets/state_view/shelf_card.dart` | Secondary state shelf card |
| `app/lib/widgets/landing/empty_landing_page.dart` | Empty landing page when no sessions |
| `app/lib/plugins/builtin/http_request_plugin.dart` | HTTP request tracking renderer plugin |
| `app/lib/widgets/renderers/cause_chain_renderer.dart` | Exception cause chain renderer |
| `app/lib/widgets/renderers/stack_frame_list.dart` | Stack frame list widget |
| `app/lib/theme/constants.dart` | Theme dimension constants |
| `packages/server/src/store/index.ts` | Store abstraction layer |
| `packages/server/src/store/adapters/loki-adapter.ts` | Loki storage adapter |
| `packages/server/src/store/adapters/memory-adapter.ts` | In-memory storage adapter |
| `packages/server/src/modules/self-logger.ts` | Server self-logging module |
| `packages/docker-sidecar/src/main.ts` | Docker container log forwarding sidecar |

## Build, Test, Run

### Full Stack (Docker)

```bash
docker compose up -d          # Starts Loki, Grafana, Server, Demo
cd app && flutter build linux  # Build viewer
./build/linux/x64/release/bundle/app  # Launch viewer
```

### Tests

```bash
cd packages/server && bun test          # Server tests
cd packages/client && bun test          # Client SDK tests
cd packages/shared && bun test          # Shared schema tests
cd packages/mcp && bun test             # MCP server tests
cd app && flutter test                  # Flutter widget & unit tests
```

### Individual Services

```bash
cd packages/server && bun run src/main.ts   # Server standalone
cd packages/demo && bun run src/main.ts     # Demo log generator
cd app && flutter run -d linux              # Flutter app (dev mode)
```

## Architecture Decisions

Key choices documented in `docs/architecture/decisions/`:

| ADR | Decision |
|-----|----------|
| 001 | **Bun** over Node.js — native TS, fast startup, built-in test runner |
| 002 | **Flutter desktop** — single codebase, rich widget system, Linux-native |
| 003 | **Grafana Loki** — label-based log storage, pairs with Grafana dashboards |
| 004 | **WebSocket** as primary viewer transport — bidirectional, low latency |
| 005 | **Plugin architecture** — extensible renderers, filters, transforms via registry |

## Conventions & Patterns

### TypeScript (server, client, shared, mcp, demo)
- **Runtime:** Bun (not Node.js) — use `Bun.serve()`, `Bun.udpSocket()`, etc.
- **Schemas:** Zod in `packages/shared/` — single source of truth consumed by server + client
- **Tests:** Colocated — `foo.test.ts` next to `foo.ts`, run with `bun test`
- **No ORM:** Direct HTTP to Loki push API
- **Modules:** Each server module is a class with clear init/dispose lifecycle

### Flutter (app)
- **State:** Provider pattern
- **Theme:** Custom color system inspired by Ayu Dark (see `docs/design/color-system.md`)
- **Fonts:** JetBrains Mono (log content) + Inter (UI chrome), bundled as assets
- **Plugin system:** Registry pattern with typed interfaces (Renderer, Filter, Transform, Tool)
- **Tests:** `test/` mirrors `lib/` structure

### General
- **File size:** Target 150 lines, hard max 300 lines per file
- **Testing:** Tests alongside implementation; balanced code-first + test-driven
- **No secrets in code:** API keys via env vars only

### Vibe Coding (AI-assisted development)
- **Branch:** `vibe/` prefix (e.g., `vibe/feature-name`)
- **Commits:** `vibe(subject): description` format
- **Workflow:** Agents commit on `vibe/` branch, human reviews and merges to `main`
- **Tools:** Use `git checkout -b vibe/<topic>` before making changes
- **Automation:** CI runs on all branches; release only from `main`

## Plugin System

The viewer app has a plugin architecture for extensibility:

- **`RendererPlugin`** — Renders custom log entry types (e.g., chart, table, progress bar)
- **`FilterPlugin`** — Custom filtering logic with autocomplete
- **`TransformPlugin`** — Text transformations on log content
- **`ToolPlugin`** — Adds tool panels to the UI

Plugins register with `PluginRegistry.instance.register(plugin)`. Each plugin has a `PluginManifest` with id, name, version, and tier (stdlib/community).

Built-in plugins: `chart`, `docker_logs`, `id_uniquifier`, `kv` (key-value), `log_type_filter`, `progress`, `smart_search`, `table`, `theme`.

See `docs/reference/plugin-api.md` for the full API.

## Documentation

| Document | Content |
|----------|---------|
| `docs/README.md` | Project overview, quick start, feature summary |
| `docs/architecture/README.md` | System architecture with Mermaid diagrams |
| `docs/architecture/decisions/` | Architecture Decision Records (ADRs) |
| `docs/guides/getting-started.md` | Step-by-step setup tutorial |
| `docs/guides/features.md` | Feature overview for the viewer |
| `docs/reference/configuration.md` | All `LOGGER_*` env vars |
| `docs/reference/protocol.md` | StoredEntry schema reference |
| `docs/reference/plugin-api.md` | Plugin development guide |
| `docs/design/ux-principles.md` | Core UX design principles |
| `docs/design/color-system.md` | Color token reference |

## Ports (Default)

| Port | Service | Protocol |
|------|---------|----------|
| 8080 | Server HTTP API | HTTP |
| 8081 | Server UDP ingest | UDP |
| 8082 | Server TCP/WebSocket | TCP |
| 3000 | Grafana | HTTP |
| 3100 | Loki (internal) | HTTP |
