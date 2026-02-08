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
│   │       ├── log_list/     List builder, filter cache, selection actions, sticky headers
│   │       ├── mini_mode/    Dense mini-mode title bar
│   │       ├── settings/     Tool groups, connection CRUD, sub-panels
│   │       └── state_view/   Collapsible persistent state sections
│   └── test/             Widget & unit tests
├── client/           TypeScript client SDK
│   └── src/
│       ├── logger.ts         Client SDK entry point
│       ├── logger-session.ts Session lifecycle
│       ├── logger-builders.ts  Fluent log builders
│       ├── logger-types.ts   Client type definitions
│       ├── queue.ts          Batching queue
│       └── stack-parser.ts   Stack trace parser
├── server/           Bun-based log server (TypeScript)
│   └── src/
│       ├── main.ts           Entry point, module wiring
│       ├── core/             Config, shared utilities
│       ├── modules/          Ring buffer, Loki forwarder, session mgr, RPC bridge, WS hub
│       ├── schema/           Zod validation schemas
│       ├── store/            Storage abstractions
│       └── transport/        HTTP, WebSocket, UDP, TCP handlers
├── shared/           Shared types & schemas (TypeScript)
│   └── src/
│       ├── log-entry.ts      LogEntry Zod schema (source of truth)
│       ├── server-message.ts Server→Viewer messages
│       ├── viewer-message.ts Viewer→Server messages
│       ├── custom-renderers.ts  Custom renderer type definitions
│       └── constants.ts      Shared constants
├── mcp/              MCP tool server for AI debugging
├── demo/             Demo log generator with scenarios
├── grafana/          Dashboard & datasource configs
├── loki/             Loki configuration
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
| `shared/src/log-entry.ts` | **LogEntry Zod schema** — single source of truth for the log protocol |
| `shared/src/server-message.ts` | Server→Viewer WebSocket message schema |
| `shared/src/viewer-message.ts` | Viewer→Server WebSocket message schema |
| `server/src/main.ts` | Server entry point — wires all modules together |
| `server/src/core/config.ts` | All server configuration via env vars |
| `server/src/transport/http.ts` | HTTP route definitions (log ingestion, health, upload) |
| `server/src/transport/ws.ts` | WebSocket handler for viewer connections |
| `server/src/transport/ingest.ts` | Log processing pipeline |
| `server/src/modules/ring-buffer.ts` | In-memory log storage with eviction |
| `server/src/modules/loki-forwarder.ts` | Async batch forwarding to Loki |
| `server/src/modules/session-manager.ts` | Session lifecycle tracking |
| `server/src/modules/rpc-bridge.ts` | Bidirectional RPC between viewer and clients |
| `client/src/logger.ts` | Client SDK — main Logger class |
| `app/lib/main.dart` | Flutter app entry point |
| `app/lib/plugins/plugin_registry.dart` | Plugin registry singleton |
| `app/lib/plugins/plugin_types.dart` | Plugin base interfaces (Renderer, Filter, Transform, Tool) |
| `app/lib/services/connection_manager.dart` | Multi-server connection management with auto-reconnect |
| `app/lib/widgets/state_view/state_view_section.dart` | Persistent state key-value view section |

## Build, Test, Run

### Full Stack (Docker)

```bash
docker compose up -d          # Starts Loki, Grafana, Server, Demo
cd app && flutter build linux  # Build viewer
./build/linux/x64/release/bundle/app  # Launch viewer
```

### Tests

```bash
cd server && bun test          # Server tests
cd client && bun test          # Client SDK tests
cd shared && bun test          # Shared schema tests
cd mcp && bun test             # MCP server tests
cd app && flutter test          # Flutter widget & unit tests
```

### Individual Services

```bash
cd server && bun run src/main.ts   # Server standalone
cd demo && bun run src/main.ts     # Demo log generator
cd app && flutter run -d linux     # Flutter app (dev mode)
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
- **Schemas:** Zod in `shared/` — single source of truth consumed by server + client
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
| `docs/reference/protocol.md` | LogEntry schema reference |
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
