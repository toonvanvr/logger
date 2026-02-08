# ADR-001: Bun as Server Runtime

**Status:** Accepted | **Date:** 2026-02-08 | **Deciders:** @toonvanvr

## Context

The Logger server is a TypeScript application that needs to handle high-throughput log ingestion via HTTP, UDP, TCP, and WebSocket transports simultaneously. The runtime must support:

- Native TypeScript execution (no transpilation step)
- Built-in HTTP server with WebSocket upgrade
- UDP and TCP socket APIs
- Fast startup for development iteration
- Built-in test runner for colocated tests

Node.js requires transpilation (via tsc or tsx), has no native UDP socket API in the standard HTTP server, and needs external test runners (Jest, Vitest).

## Decision

We will use **Bun** as the server runtime instead of Node.js.

Bun provides native TypeScript execution, `Bun.serve()` with built-in WebSocket upgrade, `Bun.udpSocket()` for UDP, fast startup (~50ms), and a built-in test runner compatible with Jest syntax. This eliminates the need for transpilation, bundling, and external test dependencies.

## Consequences

### Positive
- **Zero build step** — TypeScript runs directly, faster dev iteration
- **Unified APIs** — `Bun.serve()` handles HTTP + WebSocket; `Bun.udpSocket()` for UDP
- **Built-in test runner** — `bun test` with Jest-compatible API, no extra dependencies
- **Fast startup** — sub-100ms cold start, good for development
- **Single binary** — simpler Docker images

### Negative
- **Smaller ecosystem** — some Node.js packages may not be compatible
- **Less mature** — Bun is newer than Node.js; edge cases may exist
- **Team familiarity** — contributors may need to learn Bun-specific APIs
- **No native Windows support** — Bun's Windows support is less mature (acceptable since Logger is Linux-first)
