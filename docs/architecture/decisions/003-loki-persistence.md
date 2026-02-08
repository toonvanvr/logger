# ADR-003: Loki for Log Storage

**Status:** Accepted | **Date:** 2026-02-08 | **Deciders:** @toonvanvr

## Context

Logger needs a persistent storage backend for log entries that supports:

- Time-series log storage with label-based indexing
- Integration with a dashboard system for aggregate views
- Low resource usage suitable for local development
- Simple deployment via Docker

Alternatives considered:
- **Elasticsearch** — powerful full-text search but heavy (2GB+ RAM), complex to operate
- **ClickHouse** — excellent for analytics but overkill for local dev, complex schema management
- **SQLite** — simple but no built-in time-series optimization or dashboard integration
- **Plain files** — no query capability

## Decision

We will use **Grafana Loki** as the persistent log storage backend.

Loki is designed for log storage with label-based indexing (not full-text indexing), which keeps resource usage low. It pairs natively with Grafana for dashboards, uses a simple HTTP push API, and runs well in a Docker container with modest resource requirements.

## Consequences

### Positive
- **Low resource usage** — indexes labels only, not full log content; runs in ~256MB RAM
- **Grafana integration** — pre-built dashboards with LogQL queries out of the box
- **Simple API** — HTTP push endpoint, no client library needed
- **Docker-friendly** — single container with straightforward configuration
- **LogQL** — powerful query language for log exploration

### Negative
- **No full-text indexing** — can't do arbitrary substring search efficiently in Loki (server-side ring buffer handles real-time search)
- **Label cardinality** — high-cardinality labels (like unique session IDs) can impact performance; mitigated by careful label design
- **Not a real-time store** — write path has inherent latency; the in-memory ring buffer serves real-time needs
- **Single-tenant** — adequate for local dev, would need rethinking for multi-tenant production
