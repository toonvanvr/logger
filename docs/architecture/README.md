# Architecture Overview

Logger's architecture follows a **hub-and-spoke** pattern: a central server receives logs from multiple client applications and fans them out to viewers and storage backends.

## System Diagram

```mermaid
graph TB
    subgraph "Client Applications"
        A1[App 1] -->|HTTP/UDP/TCP| SDK1[Logger Client SDK]
        A2[App 2] -->|HTTP/UDP/TCP| SDK2[Logger Client SDK]
    end

    subgraph "Logger Server (Bun)"
        direction TB
        HTTP[HTTP Transport<br/>:8080]
        UDP[UDP Transport<br/>:8081]
        TCP[TCP/WS Transport<br/>:8082]
        
        HTTP --> Ingest[Ingest Pipeline]
        UDP --> Ingest
        TCP --> Ingest
        
        Ingest --> RB[Ring Buffer<br/>In-Memory Store]
        Ingest --> SM[Session Manager]
        Ingest --> LF[Loki Forwarder]
        
        RB --> WSHub[WebSocket Hub]
        SM --> WSHub
        RPC[RPC Bridge] <--> WSHub
    end

    subgraph "Storage"
        LF -->|Push API| Loki[(Grafana Loki)]
        Loki --> Grafana[Grafana Dashboards]
    end

    subgraph "Viewers"
        WSHub <-->|WebSocket| FV[Flutter Viewer]
        WSHub <-->|WebSocket| MCP[MCP Server]
    end

    SDK1 --> HTTP
    SDK1 --> UDP
    SDK2 --> HTTP
    SDK2 --> TCP

    style HTTP fill:#00b894,color:#fff
    style UDP fill:#00b894,color:#fff
    style TCP fill:#00b894,color:#fff
    style RB fill:#6c5ce7,color:#fff
    style Loki fill:#fdcb6e,color:#000
    style FV fill:#e17055,color:#fff
    style Grafana fill:#fdcb6e,color:#000
```

## Component Overview

### Server (`packages/server/src/`)

The server is a Bun-based TypeScript application with modular architecture:

| Module | File | Responsibility |
|--------|------|----------------|
| **HTTP Transport** | `transport/http.ts` | REST API for log ingestion, health checks, image upload |
| **UDP Transport** | `transport/udp.ts` | High-throughput UDP log ingestion |
| **TCP Transport** | `transport/tcp.ts` | TCP + WebSocket for viewer connections |
| **Ingest Pipeline** | `transport/ingest.ts` | Validates, timestamps, routes incoming logs |
| **Ring Buffer** | `modules/ring-buffer.ts` | In-memory log storage with size-based eviction |
| **Session Manager** | `modules/session-manager.ts` | Tracks active sessions, heartbeats, lifecycle |
| **Loki Forwarder** | `modules/loki-forwarder.ts` | Async batch push to Grafana Loki |
| **WebSocket Hub** | `modules/ws-hub.ts` | Manages viewer connections, subscriptions, broadcasting |
| **RPC Bridge** | `modules/rpc-bridge.ts` | Bidirectional RPC between viewers and client apps |
| **File Store** | `modules/file-store.ts` | Disk-based storage for uploaded images |

### Client SDK (`packages/client/src/`)

Lightweight TypeScript library for sending structured logs:

| File | Responsibility |
|------|----------------|
| `logger.ts` | Main `Logger` class — configuration, transport selection |
| `logger-session.ts` | Session lifecycle (start, heartbeat, end) |
| `logger-builders.ts` | Fluent API for building log entries |
| `queue.ts` | Batching queue with configurable flush interval |
| `stack-parser.ts` | Cross-runtime stack trace parsing |

### Viewer (`app/lib/`)

Flutter desktop application (Linux-first):

| Directory | Responsibility |
|-----------|----------------|
| `models/` | Dart data models mirroring shared schemas |
| `plugins/` | Plugin system — registry, types, built-in plugins |
| `screens/` | Top-level screen widgets |
| `services/` | WebSocket client, state management services |
| `theme/` | Custom dark theme, color tokens, typography |
| `widgets/` | Reusable UI components (log list, renderers, filters) |

### Shared (`packages/shared/src/`)

Zod schemas that serve as the **single source of truth** for the protocol:

- `log-entry.ts` — `LogEntry` schema with all fields and types
- `server-message.ts` — Messages from server to viewer
- `viewer-message.ts` — Messages from viewer to server
- `custom-renderers.ts` — Custom renderer type definitions

## Data Flow

### Log Ingestion

```mermaid
sequenceDiagram
    participant App as Client App
    participant SDK as Logger SDK
    participant Srv as Server
    participant RB as Ring Buffer
    participant LF as Loki Forwarder
    participant WS as WebSocket Hub

    App->>SDK: logger.info("message", data)
    SDK->>SDK: Build LogEntry (id, timestamp, session_id)
    SDK->>Srv: POST /api/v1/log (or UDP/TCP)
    Srv->>Srv: Validate via Zod schema
    Srv->>RB: Store in ring buffer
    Srv->>WS: Broadcast to subscribed viewers
    Srv->>LF: Queue for Loki push
    LF-->>LF: Batch accumulate
    LF->>LF: Flush to Loki (async)
```

### Viewer Connection

```mermaid
sequenceDiagram
    participant V as Flutter Viewer
    participant WS as WebSocket Hub
    participant SM as Session Manager
    participant RB as Ring Buffer

    V->>WS: Connect WebSocket (:8082)
    WS->>SM: Get active sessions
    SM-->>WS: Session list
    WS-->>V: session_list message
    V->>WS: subscribe {session_ids, min_severity}
    WS->>RB: Fetch history for sessions
    RB-->>WS: Historical entries
    WS-->>V: history message
    Note over WS,V: Live streaming begins
    WS-->>V: log messages (real-time)
```

## Key Design Decisions

See [Architecture Decision Records](decisions/) for detailed rationale:

- [ADR-001: Bun Runtime](decisions/001-bun-runtime.md) — Why Bun over Node.js
- [ADR-002: Flutter Desktop](decisions/002-flutter-desktop.md) — Why Flutter for the viewer
- [ADR-003: Loki Persistence](decisions/003-loki-persistence.md) — Why Grafana Loki
- [ADR-004: WebSocket Primary](decisions/004-websocket-primary.md) — Why WebSocket for viewer comms
- [ADR-005: Plugin Architecture](decisions/005-plugin-architecture.md) — Plugin extensibility approach

## Deployment

Logger runs entirely via Docker Compose for local development:

```
docker compose up -d
```

Services: Loki (log storage), Grafana (dashboards), Server (log ingestion), Demo (sample traffic). The Flutter viewer runs natively on the host machine.

See [Configuration Reference](../reference/configuration.md) for all environment variables.
