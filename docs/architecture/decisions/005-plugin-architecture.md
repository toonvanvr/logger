# ADR-005: Plugin Architecture for Viewer Extensibility

**Status:** Accepted | **Date:** 2026-02-08 | **Deciders:** @toonvanvr

## Context

The Logger viewer needs to render diverse log content types beyond plain text: progress bars, tables, key-value pairs, charts, and potentially user-defined custom types. The rendering system must be:

- Extensible without modifying core viewer code
- Type-safe with clear interfaces
- Performant with O(1) renderer lookup
- Discoverable — plugins declare their capabilities via manifests

A monolithic renderer switch statement would grow unwieldy and prevent third-party extensions.

## Decision

We will use a **registry-based plugin architecture** with typed abstract interfaces for different plugin capabilities.

The system defines four plugin types:
- **RendererPlugin** — renders custom log entry types (maps `custom_type` string → widget)
- **FilterPlugin** — provides custom filtering logic with autocomplete
- **TransformPlugin** — transforms log entry display text
- **ToolPlugin** — adds tool panels to the UI

Plugins register with a global `PluginRegistry` singleton. Renderer plugins are indexed by `custom_type` for O(1) lookup. Each plugin carries a `PluginManifest` with identity (id, name, version) and tier (stdlib/community).

## Consequences

### Positive
- **Open/closed principle** — new renderers added without changing core code
- **O(1) lookup** — renderer index maps `custom_type` → plugin directly
- **Type safety** — abstract Dart classes enforce plugin contracts at compile time
- **Discoverability** — manifests enable future plugin management UI
- **Separation** — built-in plugins in `plugins/builtin/` use the same API as future community plugins

### Negative
- **Singleton pattern** — global registry couples plugin access to a single instance (acceptable for a desktop app)
- **No hot-loading** — plugins must be compiled into the app (no runtime plugin loading)
- **Interface evolution** — changing plugin interfaces requires updating all implementations
- **Discovery limited** — no plugin marketplace; community plugins require source integration
