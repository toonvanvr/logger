# Architecture Decision Records

This directory contains Architecture Decision Records (ADRs) for the Logger project. ADRs document architecturally significant decisions — choices that affect the system's structure, dependencies, interfaces, or key trade-offs.

## Index

| # | Title | Status | Date | Summary |
|---|-------|--------|------|---------|
| [001](001-bun-runtime.md) | Bun as Server Runtime | Accepted | 2026-02-08 | Use Bun instead of Node.js for the server |
| [002](002-flutter-desktop.md) | Flutter for Desktop Viewer | Accepted | 2026-02-08 | Flutter Linux desktop for the viewer app |
| [003](003-loki-persistence.md) | Loki for Log Storage | Accepted | 2026-02-08 | Grafana Loki over Elasticsearch/ClickHouse |
| [004](004-websocket-primary.md) | WebSocket as Primary Transport | Accepted | 2026-02-08 | WebSocket over SSE for viewer communication |
| [005](005-plugin-architecture.md) | Plugin Architecture | Accepted | 2026-02-08 | Registry-based plugin system for viewer extensibility |
| [006](006-zod-source-of-truth.md) | Zod as Schema Source of Truth | Accepted | 2026-02-11 | Zod schemas in packages/shared as single source of truth |
| [007](007-client-batch-queue.md) | Client Batching Queue Strategy | Accepted | 2026-02-11 | Byte-budgeted circular buffer with fixed drain interval |

## Creating a New ADR

1. Copy the template below
2. Number sequentially (next: `008`)
3. Fill in all sections
4. Add to the index table above
5. Commit with the related code change

### Template

```markdown
# ADR-NNN: Title (Short Noun Phrase)

**Status:** Proposed | **Date:** YYYY-MM-DD | **Deciders:** @toonvanvr

## Context

What forces are at play? What problem are we solving?

## Decision

We will [specific decision in active voice].

## Consequences

### Positive
- ...

### Negative
- ...
```

### Rules

- **Numbered sequentially** — numbers are never reused
- **Immutable once accepted** — if reversed, mark as "Superseded by ADR-NNN" and create a new ADR
- **Short** — one page maximum; link to detailed docs if needed
- **Architecturally significant only** — don't ADR minor implementation choices
