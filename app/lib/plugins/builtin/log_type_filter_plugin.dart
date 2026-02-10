import 'package:flutter/material.dart';

import '../../models/log_entry.dart';
import '../plugin_manifest.dart';
import '../plugin_registry.dart';
import '../plugin_types.dart';

/// Filter plugin that restricts visible entries to specific log types.
///
/// When no types are selected, all entries pass through (no filtering).
/// The suggestion list is dynamically built from the current log data.
class LogTypeFilterPlugin extends FilterPlugin with EnableablePlugin {
  final Set<String> _activeTypes = {};

  // ─── Identity ──────────────────────────────────────────────────────

  @override
  String get id => 'dev.logger.log-type-filter';

  @override
  String get name => 'Log Type Filter';

  @override
  String get version => '1.0.0';

  @override
  String get description => 'Filters entries by log type (text, json, etc.).';

  @override
  PluginManifest get manifest => const PluginManifest(
    id: 'dev.logger.log-type-filter',
    name: 'Log Type Filter',
    version: '1.0.0',
    description: 'Filters entries by log type (text, json, etc.).',
    types: ['filter'],
  );

  @override
  String get filterLabel => 'Type';

  @override
  IconData get filterIcon => Icons.category;

  // ─── Active types management ───────────────────────────────────────

  /// The currently active type filters. Empty means no filtering.
  Set<String> get activeTypes => Set.unmodifiable(_activeTypes);

  /// Set the active type filters.
  void setActiveTypes(Set<String> types) {
    _activeTypes
      ..clear()
      ..addAll(types);
  }

  /// Toggle a single type on or off.
  void toggleType(String type) {
    if (_activeTypes.contains(type)) {
      _activeTypes.remove(type);
    } else {
      _activeTypes.add(type);
    }
  }

  /// Clear all active type filters.
  void clearTypes() {
    _activeTypes.clear();
  }

  // ─── FilterPlugin interface ────────────────────────────────────────

  @override
  bool matches(LogEntry entry, String query) {
    if (_activeTypes.isEmpty) return true;
    return _activeTypes.contains(_entryTypeString(entry));
  }

  @override
  List<String> getSuggestions(String partialQuery, List<LogEntry> entries) {
    final available = entries.map(_entryTypeString).toSet().toList()..sort();
    if (partialQuery.isEmpty) return available;
    final lower = partialQuery.toLowerCase();
    return available.where((t) => t.contains(lower)).toList();
  }

  /// Map a v2 entry to a human-readable type string.
  static String _entryTypeString(LogEntry entry) => switch (entry.kind) {
    EntryKind.session => 'session',
    EntryKind.data => 'data',
    EntryKind.event => entry.widget?.type ?? 'text',
  };

  // ─── Lifecycle ─────────────────────────────────────────────────────

  @override
  void onRegister(PluginRegistry registry) {}

  @override
  void onDispose() {
    _activeTypes.clear();
  }
}
