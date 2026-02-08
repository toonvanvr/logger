# ADR-002: Flutter for Desktop Viewer

**Status:** Accepted | **Date:** 2026-02-08 | **Deciders:** @toonvanvr

## Context

The Logger viewer is a desktop application that displays real-time streaming logs with rich rendering (progress bars, tables, charts, stack traces), custom dark theme, and responsive layout. Requirements:

- Linux-native desktop application (not Electron)
- Rich widget system for custom log renderers
- High-performance scrolling for potentially millions of log entries
- Custom theming with precise color control
- Plugin architecture for extensible rendering

Alternatives considered:
- **Electron/React** — heavy runtime, large memory footprint, web rendering overhead
- **Tauri/Svelte** — lighter than Electron but web rendering still limited for complex widgets
- **GTK/Qt native** — powerful but high development cost, no cross-platform widget abstraction
- **Terminal UI (TUI)** — too limited for rich rendering needs

## Decision

We will use **Flutter for Linux desktop** as the viewer application framework.

Flutter provides a rich widget system with composition-based UI, GPU-accelerated rendering via Skia/Impeller, precise control over theming and layout, and a mature plugin/package ecosystem. The `flutter build linux` target produces a native GTK application.

## Consequences

### Positive
- **Rich widget system** — composition-based widgets ideal for custom log renderers
- **GPU-accelerated rendering** — smooth scrolling even with large log volumes
- **Single codebase** — could extend to macOS/Windows in the future
- **Hot reload** — fast UI development iteration
- **Strong theming** — full control over colors, typography, spacing

### Negative
- **Dart language** — different from the TypeScript server/client; two languages in the project
- **Desktop maturity** — Flutter desktop is less mature than mobile
- **Binary size** — larger than a native GTK app (~20MB)
- **No web viewer** — can't open in a browser (acceptable for local-dev use case)
