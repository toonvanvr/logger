/// Base interfaces and abstract classes for all plugin types.
library;

import 'package:flutter/material.dart';

import '../models/log_entry.dart';
import '../models/status_bar_item.dart';
import 'plugin_manifest.dart';
import 'plugin_registry.dart';

// ─── Base Plugin ─────────────────────────────────────────────────────

/// Base interface that all plugins implement.
abstract class LoggerPlugin {
  /// Reverse-domain unique identifier.
  String get id;

  /// Human-readable display name.
  String get name;

  /// SemVer version string.
  String get version;

  /// Short description of the plugin's purpose.
  String get description;

  /// Whether this plugin is currently enabled.
  bool get enabled;

  /// Full manifest metadata.
  PluginManifest get manifest;

  /// Called when the plugin is registered with the registry.
  void onRegister(PluginRegistry registry);

  /// Called before the plugin is removed or the app shuts down.
  void onDispose();
}

// ─── Renderer Plugin ─────────────────────────────────────────────────

/// A plugin that renders custom log entry types.
abstract class RendererPlugin extends LoggerPlugin {
  /// The set of `customType` strings this renderer handles.
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

// ─── Filter Plugin ───────────────────────────────────────────────────

/// A plugin that provides custom log filtering logic.
abstract class FilterPlugin extends LoggerPlugin {
  /// Label shown in the filter UI.
  String get filterLabel;

  /// Icon shown in the filter UI.
  IconData get filterIcon;

  /// Returns true if [entry] matches the given [query].
  bool matches(LogEntry entry, String query);

  /// Returns autocomplete suggestions for a partial query.
  List<String> getSuggestions(String partialQuery, List<LogEntry> entries);
}

// ─── Transform Plugin ────────────────────────────────────────────────

/// A plugin that transforms log entry display text.
abstract class TransformPlugin extends LoggerPlugin {
  /// Label shown in the transform picker.
  String get displayName;

  /// Transform the input string.
  String transform(String input);

  /// Returns true if this transform can handle the input.
  bool canTransform(String input);
}

// ─── Tool Plugin ─────────────────────────────────────────────────────

/// A plugin that provides a tool panel in the UI.
abstract class ToolPlugin extends LoggerPlugin {
  /// Label displayed for the tool.
  String get toolLabel;

  /// Icon displayed for the tool.
  IconData get toolIcon;

  /// Build the tool panel widget.
  Widget buildToolPanel(BuildContext context);

  /// Optional configuration panel for settings.
  Widget? buildConfigPanel(BuildContext context) => null;

  /// Status bar items contributed by this tool.
  List<StatusBarItem> get statusBarItems => const [];
}

// ─── Row Action Plugin ────────────────────────────────────────────────

/// Data class representing a single action in the hover icon bar.
class RowAction {
  final String id;
  final IconData icon;
  final String tooltip;
  final void Function(LogEntry) onTap;
  final bool Function(LogEntry)? isActive;

  const RowAction({
    required this.id,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.isActive,
  });
}

/// Standard tool group identifiers for the settings panel.
abstract class ToolGroups {
  static const connections = 'Connections';
  static const searchFilter = 'Search & Filter';
  static const renderers = 'Renderers';
  static const transforms = 'Transforms';
  static const tools = 'Tools';
  static const groupOrder = [
    connections,
    searchFilter,
    renderers,
    transforms,
    tools,
  ];
}
