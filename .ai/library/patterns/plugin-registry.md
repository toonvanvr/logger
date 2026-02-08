# Pattern: Plugin Registry (Singleton with Typed Resolution)

**Context**: The Logger Flutter app uses a plugin architecture for extensible renderers, filters, transforms, and tools.

## Implementation

**File**: `app/lib/plugins/plugin_registry.dart`

### Core Design

- **Singleton**: `PluginRegistry.instance` — global, created once
- **Map-based storage**: `Map<String, LoggerPlugin> _plugins` keyed by plugin id
- **O(1) renderer lookup**: Separate `_rendererIndex` maps `customType → pluginId`
- **Typed queries**: `getPlugins<T>()` and `getEnabledPlugins<T>()` use `whereType<T>()`

### Registration Flow

1. Plugins registered before `runApp()` in `main.dart`
2. `register()` rejects duplicate IDs (throws `PluginConflictException`)
3. `RendererPlugin` instances have their `customTypes` indexed for fast resolution
4. Each plugin's `onRegister(registry)` is called on registration

### Plugin Types

| Interface | Purpose | Key Method |
|-----------|---------|------------|
| `LoggerPlugin` | Base | `onRegister()`, `onDispose()` |
| `RendererPlugin` | Custom log rendering | `buildRenderer()`, `customTypes` |
| `FilterPlugin` | Log filtering | `matches()`, `getSuggestions()` |
| `TransformPlugin` | Text transformation | `transform()`, `canTransform()` |
| `ToolPlugin` | UI tool panels | `buildToolPanel()` |

### Enable/Disable

- `EnableablePlugin` mixin provides `_enabled` flag
- `setEnabled()` on registry delegates to the mixin
- Disabled plugins excluded from `getEnabledPlugins<T>()` and `resolveRenderer()`

### Manifest

Each plugin has a `PluginManifest` with:
- `id`, `name`, `version`, `description`
- `tier` (stdlib / community)
- `types` (set of plugin type strings: renderer, filter, transform, tool)

## When to Use

- Any app needing extensible, type-safe plugin dispatch
- When O(1) lookup by custom type key is needed
- When AOT compilation prevents dynamic loading (e.g., Flutter desktop)

## Built-in Plugins

`chart`, `id_uniquifier`, `kv`, `log_type_filter`, `progress`, `smart_search`, `table`
