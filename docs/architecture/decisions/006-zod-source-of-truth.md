# ADR-006: Zod as Schema Source of Truth

**Status:** Accepted | **Date:** 2026-02-11 | **Deciders:** @toonvanvr

## Context

The Logger system has three TypeScript packages (server, client, MCP) that all handle the same wire protocol — `StoredEntry`, event messages, data messages, session messages, and WebSocket broadcast/command types. Without a shared, validated schema:

- Type definitions drift between packages over time
- Runtime validation is ad-hoc or absent — malformed messages cause silent bugs
- Adding a field requires changes in multiple places with no compile-time guarantee of consistency

The schema language must provide both TypeScript types (for compile-time safety) and runtime validation (for ingestion).

## Decision

We will use **Zod schemas in `packages/shared/`** as the single source of truth for all wire protocol types. The `StoredEntry` schema in `stored-entry.ts` defines every field, its type, optionality, and default value. Server, client, and MCP packages import from `@logger/shared` — they never define their own copies of protocol types.

Runtime validation happens at the server ingestion boundary: incoming messages are parsed through Zod schemas in the normalizer, which rejects invalid data and applies defaults. Downstream code operates on typed, validated objects.

## Consequences

### Positive
- **Single source of truth** — one schema definition consumed by all packages via Bun workspace imports
- **Runtime + compile-time safety** — Zod provides both `z.infer<typeof Schema>` types and `.parse()` validation
- **Self-documenting** — schema files serve as protocol reference, with defaults visible inline
- **Incremental adoption** — new fields get a `.default()` value, so existing clients don't break

### Negative
- **Zod dependency** — all TypeScript packages depend on Zod (acceptable; it's already a core dependency)
- **Schema complexity** — `StoredEntry` is a wide union-like object (fields for event/data/session kinds); this is intentional to keep a single storage format
- **No cross-language generation** — the Dart viewer manually mirrors the Zod schema; changes require updating both (mitigated by tests)
