/// Singleton plugin registry with O(1) type lookup for renderers.
library;

import 'plugin_manifest.dart';
import 'plugin_types.dart';

class PluginRegistry {
  PluginRegistry._();

  /// Global singleton instance.
  static final PluginRegistry instance = PluginRegistry._();

  /// All registered plugins, keyed by id.
  final Map<String, LoggerPlugin> _plugins = {};

  /// Renderer index: customType → plugin id.
  final Map<String, String> _rendererIndex = {};

  // ─── Registration ────────────────────────────────────────────────

  /// Register a plugin. Rejects duplicate ids.
  ///
  /// For [RendererPlugin]s, each custom type is indexed for O(1) lookup.
  /// If two renderers claim the same custom type, the last registration wins.
  void register(LoggerPlugin plugin) {
    if (_plugins.containsKey(plugin.id)) {
      throw PluginConflictException(
        'Plugin "${plugin.id}" is already registered.',
      );
    }

    _plugins[plugin.id] = plugin;
    plugin.onRegister(this);

    if (plugin is RendererPlugin) {
      for (final type in plugin.customTypes) {
        _rendererIndex[type] = plugin.id;
      }
    }
  }

  /// Unregister a plugin by id.
  void unregister(String pluginId) {
    final plugin = _plugins.remove(pluginId);
    if (plugin == null) return;

    plugin.onDispose();

    if (plugin is RendererPlugin) {
      _rendererIndex.removeWhere((_, id) => id == pluginId);
    }
  }

  // ─── Queries ─────────────────────────────────────────────────────

  /// Resolve the renderer for a given [customType]. Returns null if none.
  RendererPlugin? resolveRenderer(String customType) {
    final pluginId = _rendererIndex[customType];
    if (pluginId == null) return null;

    final plugin = _plugins[pluginId];
    if (plugin is RendererPlugin && plugin.enabled) return plugin;
    return null;
  }

  /// Get all registered plugins of a specific type [T].
  List<T> getPlugins<T extends LoggerPlugin>() {
    return _plugins.values.whereType<T>().toList(growable: false);
  }

  /// Get all enabled plugins of a specific type [T].
  List<T> getEnabledPlugins<T extends LoggerPlugin>() {
    return _plugins.values
        .whereType<T>()
        .where((p) => p.enabled)
        .toList(growable: false);
  }

  /// Look up a plugin by id.
  LoggerPlugin? getPlugin(String pluginId) => _plugins[pluginId];

  /// All registered manifests.
  List<PluginManifest> get manifests =>
      _plugins.values.map((p) => p.manifest).toList(growable: false);

  // ─── Enable / Disable ────────────────────────────────────────────

  /// Enable or disable a plugin by id.
  void setEnabled(String pluginId, bool enabled) {
    final plugin = _plugins[pluginId];
    if (plugin is EnableablePlugin) {
      plugin.setEnabled(enabled);
    }
  }

  // ─── Lifecycle ───────────────────────────────────────────────────

  /// Dispose all plugins and clear the registry.
  void disposeAll() {
    for (final plugin in _plugins.values) {
      plugin.onDispose();
    }
    _plugins.clear();
    _rendererIndex.clear();
  }

  /// Number of registered plugins.
  int get length => _plugins.length;
}

// ─── Mixin for enable/disable support ────────────────────────────────

/// Mixin that provides a mutable [enabled] flag for plugin implementations.
mixin EnableablePlugin on LoggerPlugin {
  bool _enabled = true;

  @override
  bool get enabled => _enabled;

  void setEnabled(bool value) {
    _enabled = value;
  }
}

// ─── Exceptions ──────────────────────────────────────────────────────

class PluginConflictException implements Exception {
  final String message;
  const PluginConflictException(this.message);

  @override
  String toString() => 'PluginConflictException: $message';
}
