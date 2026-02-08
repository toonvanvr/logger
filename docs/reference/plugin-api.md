# Plugin API Reference

The Logger viewer supports a plugin architecture for extending rendering, filtering, transformation, and tooling capabilities. All plugin interfaces are defined in `app/lib/plugins/plugin_types.dart`.

## Plugin Types

| Type | Interface | Purpose |
|------|-----------|---------|
| **Renderer** | `RendererPlugin` | Renders custom log entry types as widgets |
| **Filter** | `FilterPlugin` | Custom filtering logic with autocomplete |
| **Transform** | `TransformPlugin` | Text transformations on log content |
| **Tool** | `ToolPlugin` | Adds tool panels to the UI |

## Base Interface: `LoggerPlugin`

All plugins implement this base interface:

```dart
abstract class LoggerPlugin {
  String get id;           // Reverse-domain unique identifier
  String get name;         // Human-readable display name
  String get version;      // SemVer version string
  String get description;  // Short description
  bool get enabled;        // Whether currently enabled
  PluginManifest get manifest;  // Full metadata

  void onRegister(PluginRegistry registry);  // Called on registration
  void onDispose();                          // Called on removal
}
```

## RendererPlugin

Renders custom log entry types. The viewer's `custom_type` field on a `LogEntry` is matched against the plugin's `customTypes` set.

```dart
abstract class RendererPlugin extends LoggerPlugin {
  /// The set of custom_type strings this renderer handles.
  Set<String> get customTypes;

  /// Build the full renderer widget for the given entry.
  Widget buildRenderer(
    BuildContext context,
    Map<String, dynamic> data,
    LogEntry entry,
  );

  /// Optional compact preview widget. Returns null if not supported.
  Widget? buildPreview(Map<String, dynamic> data) => null;
}
```

**How it works:** When the viewer encounters a `LogEntry` with `type: "custom"` and a `custom_type` field, it calls `PluginRegistry.instance.resolveRenderer(customType)` to find the matching plugin (O(1) lookup via index), then calls `buildRenderer()` to produce the widget.

## FilterPlugin

Provides custom filtering logic that appears in the filter UI.

```dart
abstract class FilterPlugin extends LoggerPlugin {
  String get filterLabel;   // Label shown in filter UI
  IconData get filterIcon;  // Icon shown in filter UI

  /// Returns true if entry matches the query.
  bool matches(LogEntry entry, String query);

  /// Returns autocomplete suggestions for a partial query.
  List<String> getSuggestions(String partialQuery, List<LogEntry> entries);
}
```

## TransformPlugin

Transforms log entry display text (e.g., formatting, redaction).

```dart
abstract class TransformPlugin extends LoggerPlugin {
  String get displayName;  // Label in the transform picker

  /// Transform the input string.
  String transform(String input);

  /// Returns true if this transform can handle the input.
  bool canTransform(String input);
}
```

## ToolPlugin

Adds a tool panel to the viewer UI.

```dart
abstract class ToolPlugin extends LoggerPlugin {
  String get toolLabel;   // Display label
  IconData get toolIcon;  // Display icon

  /// Build the tool panel widget.
  Widget buildToolPanel(BuildContext context);
}
```

## Plugin Manifest

Every plugin carries a `PluginManifest`:

```dart
class PluginManifest {
  final String id;          // Unique identifier
  final String name;        // Display name
  final String version;     // SemVer
  final String description; // Short description
  final List<String> types; // Plugin type tags
  final PluginTier tier;    // stdlib or community
}
```

**Tiers:**
- `PluginTier.stdlib` — Built-in plugins shipped with Logger
- `PluginTier.community` — Third-party plugins

## Plugin Registry

Plugins register with the global singleton:

```dart
PluginRegistry.instance.register(myPlugin);
```

### Key Methods

| Method | Description |
|--------|-------------|
| `register(plugin)` | Register a plugin. Rejects duplicate IDs. |
| `unregister(pluginId)` | Remove a plugin by ID. |
| `resolveRenderer(customType)` | Find the renderer for a custom type (O(1)). |
| `getPlugins<T>()` | Get all registered plugins of type `T`. |
| `getEnabledPlugins<T>()` | Get all enabled plugins of type `T`. |
| `getPlugin(pluginId)` | Look up a plugin by ID. |

## Built-in Plugins

| Plugin | Type | Custom Types | Description |
|--------|------|-------------|-------------|
| `chart_plugin` | Renderer | `chart` | Renders chart visualizations |
| `progress_plugin` | Renderer | `progress` | Renders progress bars |
| `table_plugin` | Renderer | `table` | Renders tabular data |
| `kv_plugin` | Renderer | `kv` | Renders key-value pairs |
| `id_uniquifier_plugin` | Transform | — | Adds unique identifiers to ambiguous entries |
| `smart_search_plugin` | Filter | — | Smart search with autocomplete |
| `log_type_filter_plugin` | Filter | — | Filter by log type |

## ChartPainter

The `ChartPainter` class is a `CustomPainter` used by the chart plugin and the state chart strip. It supports multiple chart variants and optional tick marks.

### Constructor Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `variant` | `String` | — | Chart type: `bar`, `sparkline`, `area`, `dense_bar`. |
| `values` | `List<num>` | — | Data points to render. |
| `labels` | `List<String>?` | `null` | Optional labels for each data point. |
| `color` | `Color` | — | Fill color for the chart. |
| `textColor` | `Color` | — | Color for labels and axis text. |
| `showTicks` | `bool` | `false` | When `true`, renders horizontal tick lines behind the chart. |
| `tickColor` | `Color?` | `null` | Override color for tick lines (defaults to `textColor` at 40% opacity). |

### Chart Variants

| Variant | Description |
|---------|-------------|
| `bar` | Standard bar chart with gaps between bars (default). |
| `sparkline` | Connected line chart without axes. |
| `area` | Filled area chart under a sparkline. |
| `dense_bar` | Thin vertical bars without gaps, suited for high-frequency time-series. |

### Example Usage

```dart
CustomPaint(
  painter: ChartPainter(
    variant: 'dense_bar',
    values: [10, 20, 15, 30, 25],
    color: Colors.blue,
    textColor: Colors.white70,
    showTicks: true,
  ),
  size: const Size(160, 60),
)
```

## Writing a New Plugin

1. Create a new file in `app/lib/plugins/builtin/` (or a separate package for community plugins).
2. Extend the appropriate abstract class (`RendererPlugin`, `FilterPlugin`, etc.).
3. Implement all required getters and methods.
4. Register in the app initialization code:

```dart
import 'package:app/plugins/plugin_registry.dart';
import 'my_custom_plugin.dart';

// During app startup:
PluginRegistry.instance.register(MyCustomPlugin());
```

### Example: Minimal Renderer Plugin

```dart
class MyRendererPlugin extends RendererPlugin {
  @override String get id => 'com.example.my-renderer';
  @override String get name => 'My Renderer';
  @override String get version => '1.0.0';
  @override String get description => 'Renders my custom type';
  @override bool get enabled => true;
  @override PluginManifest get manifest => PluginManifest(
    id: id, name: name, version: version,
    description: description, types: ['renderer'],
  );

  @override Set<String> get customTypes => {'my_type'};

  @override void onRegister(PluginRegistry registry) {}
  @override void onDispose() {}

  @override
  Widget buildRenderer(BuildContext context, Map<String, dynamic> data, LogEntry entry) {
    return Text(data['message'] ?? 'No message');
  }
}
```

### Sending Custom-Typed Logs

From the client SDK:

```typescript
logger.log({
  type: 'custom',
  custom_type: 'my_type',
  custom_data: { message: 'Hello from custom renderer' },
});
```
