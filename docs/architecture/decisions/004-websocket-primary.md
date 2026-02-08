# ADR-004: WebSocket as Primary Viewer Transport

**Status:** Accepted | **Date:** 2026-02-08 | **Deciders:** @toonvanvr

## Context

The Flutter viewer needs to receive real-time log entries from the server and send commands back (subscribe/unsubscribe, history queries, RPC requests). The transport must support:

- Real-time streaming with sub-second latency
- Bidirectional communication (server→viewer and viewer→server)
- Subscription management (filter by session, severity, section)
- RPC bridging between viewer and client applications

Alternatives considered:
- **Server-Sent Events (SSE)** — server→client only; viewer→server requires separate HTTP requests
- **HTTP polling** — high latency, wasteful for real-time streaming
- **gRPC** — bidirectional but complex setup, requires protobuf, poor Flutter desktop support

## Decision

We will use **WebSocket** as the primary transport between the server and viewer (and MCP server).

WebSocket provides full-duplex communication over a single TCP connection, enabling real-time log streaming server→viewer and control messages viewer→server. The protocol uses JSON-serialized messages defined by Zod schemas in `shared/src/`.

## Consequences

### Positive
- **Full duplex** — single connection for both streaming and commands
- **Low latency** — no HTTP overhead per message after handshake
- **Native Bun support** — `Bun.serve()` has built-in WebSocket upgrade
- **Subscription model** — viewer sends subscribe/unsubscribe messages to control what it receives
- **RPC bridging** — enables bidirectional communication between viewer and client apps through the server

### Negative
- **Connection management** — must handle reconnection, buffering during disconnects
- **No HTTP caching** — can't leverage CDN or browser cache (not relevant for local dev)
- **Debugging** — WebSocket traffic is harder to inspect than HTTP (mitigated by structured JSON messages)
- **Firewall traversal** — some corporate firewalls block WebSocket (acceptable for local dev)
