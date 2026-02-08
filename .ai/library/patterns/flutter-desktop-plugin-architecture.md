# Pattern: Flutter Desktop Plugin Architecture (AOT-Compatible)

**Context**: Flutter desktop apps are AOT-compiled — no `dart:mirrors`, no dynamic Dart code loading, no hot-loading of `.dart` files at runtime.

## Solution: Tiered Plugin Architecture

### Tier 1: Compiled Plugins (Full Power)
- Implemented as Dart classes implementing abstract plugin interfaces
- Registered at startup before `runApp()`
- Full Widget-level power (can return any Flutter widget)
- Distribution: compiled into the binary (stdlib) or via "extension packs" (pre-built binaries)

### Tier 2: Declarative Plugins (Community-Distributable)
- JSON manifest + optional scripting (Lua via `lua_dardo`)
- Installed to `~/.config/{app}/plugins/{id}/`
- Cannot return Widgets — limited to data transforms, filters, search, actions
- Sandboxed: no filesystem/network access from scripts

### Key Interfaces
- `LoggerPlugin` base with `initialize()`, `activate()`, `deactivate()`, `dispose()`
- `PluginContext` provided during init — read-only access to app state + registration methods
- `PluginRegistry` singleton with type system, O(1) lookup, conflict resolution
- `PluginManifest` JSON schema for metadata, settings, integrity hashes

### Plugin Type Extensibility
The type registry itself is extensible — a plugin can register new plugin types via `registerType()`. This prevents the registry from becoming a bottleneck as the system grows.

### Distribution with Integrity
URL format: `https://example.com/plugin.zip#sha256=...` — hash in URL fragment, parsed automatically. Hash verification mandatory for security; unverified plugins require explicit user confirmation.

## When to Use
- Any Flutter desktop app that needs community extensibility
- When AOT compilation prevents traditional dynamic plugin loading
- When you need both powerful compiled extensions and lightweight community scripts

## Trade-off
Community plugins cannot add visual widgets without recompilation. This is an inherent Flutter AOT limitation. Mitigate with a comprehensive stdlib.
