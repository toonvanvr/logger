# ADR-007: Client Batching Queue Strategy

**Status:** Accepted | **Date:** 2026-02-11 | **Deciders:** @toonvanvr

## Context

The Logger client SDK sends structured log entries to the server via HTTP, WebSocket, or UDP. Sending each entry individually would create excessive network overhead — especially over HTTP where each entry incurs a full request/response cycle. The client needs a strategy that balances latency (entries visible quickly) with efficiency (few network calls).

Key constraints:
- Log volume ranges from occasional messages to thousands per second (e.g., progress bars)
- HTTP is the default transport — must minimize request count
- The client runs in application processes — memory usage must be bounded
- Log delivery is best-effort — dropped entries are acceptable under backpressure

## Decision

We will use a **byte-budgeted circular buffer** (`LogQueue`) that drains on a fixed timer interval.

- **Queue**: Entries accumulate in an array. Each entry's byte cost is estimated via `JSON.stringify(entry).length * 2`.
- **Byte budget**: Default 8 MB. When the budget is exceeded, new entries are silently dropped (`push()` returns `false`).
- **Drain cycle**: A 100ms `setInterval` timer calls `drain()`, which splices up to 100 entries from the front of the queue and sends them as a batch via the active transport.
- **Flush on close**: `logger.close()` performs a final drain before closing the transport.

## Consequences

### Positive
- **Bounded memory** — byte-budget cap prevents unbounded growth in high-throughput scenarios
- **Low latency** — 100ms drain interval means entries reach the server within ~100ms
- **Batch efficiency** — up to 100 entries per HTTP request; reduces overhead by ~100×
- **Backpressure resilience** — failed sends re-enqueue entries for retry on next drain cycle
- **Simple implementation** — ~65 lines, no external dependencies

### Negative
- **Estimated sizing** — `JSON.stringify().length * 2` is approximate; actual serialized size may differ
- **Fixed interval** — no adaptive flushing based on entry volume or severity
- **Silent drops** — entries dropped under backpressure produce no warning (acceptable for a dev tool)
- **No persistence** — queue is in-memory only; entries lost on process crash
