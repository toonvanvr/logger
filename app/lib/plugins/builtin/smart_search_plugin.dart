import 'package:flutter/material.dart';

import '../../models/log_entry.dart';
import '../plugin_manifest.dart';
import '../plugin_registry.dart';
import '../plugin_types.dart';

/// Smart search plugin that detects common data patterns (UUID, URL, email,
/// IP, errors, HTTP status codes) and provides prefix-based autocomplete
/// suggestions from the current log data.
class SmartSearchPlugin extends FilterPlugin with EnableablePlugin {
  // ─── Known patterns for autocomplete ─────────────────────────────

  static final _searchPatterns = <String, RegExp>{
    'uuid:': RegExp(
      r'[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}',
      caseSensitive: false,
    ),
    'url:': RegExp(r'https?://\S+'),
    'email:': RegExp(r'[\w.+-]+@[\w-]+\.[\w.]+'),
    'ip:': RegExp(r'\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}'),
    'error:': RegExp(r'Error|Exception|Failed|FATAL', caseSensitive: false),
    'status:': RegExp(r'\b[1-5]\d{2}\b'),
  };

  // ─── Identity ────────────────────────────────────────────────────

  @override
  String get id => 'dev.logger.smart-search';

  @override
  String get name => 'Smart Search';

  @override
  String get version => '1.0.0';

  @override
  String get description =>
      'Pattern-aware search with prefix autocomplete for UUIDs, URLs, '
      'emails, IPs, errors, and HTTP status codes.';

  @override
  PluginManifest get manifest => const PluginManifest(
    id: 'dev.logger.smart-search',
    name: 'Smart Search',
    version: '1.0.0',
    description:
        'Pattern-aware search with prefix autocomplete for UUIDs, URLs, '
        'emails, IPs, errors, and HTTP status codes.',
    types: ['filter'],
  );

  @override
  String get filterLabel => 'Smart Search';

  @override
  IconData get filterIcon => Icons.search;

  // ─── FilterPlugin interface ──────────────────────────────────────

  @override
  bool matches(LogEntry entry, String query) {
    if (query.isEmpty) return true;

    for (final prefix in _searchPatterns.keys) {
      if (query.startsWith(prefix)) {
        final value = query.substring(prefix.length).trim();
        if (value.isEmpty) return true;
        final content = _entryText(entry);
        final pattern = _searchPatterns[prefix]!;
        final matches = pattern.allMatches(content);
        final lower = value.toLowerCase();
        return matches.any((m) => m.group(0)!.toLowerCase().contains(lower));
      }
    }

    // Fallback: fuzzy match across all text
    final lower = query.toLowerCase();
    return _entryText(entry).toLowerCase().contains(lower);
  }

  @override
  List<String> getSuggestions(String partialQuery, List<LogEntry> entries) {
    for (final prefix in _searchPatterns.keys) {
      if (partialQuery.startsWith(prefix)) {
        final value = partialQuery.substring(prefix.length).trim();
        return _extractValues(prefix, value, entries);
      }
    }

    if (partialQuery.isEmpty) {
      return _searchPatterns.keys.toList();
    }

    final lower = partialQuery.toLowerCase();
    final prefixMatches = _searchPatterns.keys
        .where((p) => p.startsWith(lower))
        .toList();
    if (prefixMatches.isNotEmpty) return prefixMatches;

    final results = <String>{};
    for (final entry in entries) {
      final text = entry.message ?? '';
      if (text.toLowerCase().contains(lower) && text.length <= 120) {
        results.add(text);
        if (results.length >= 8) break;
      }
    }
    return results.toList();
  }

  // ─── Lifecycle ───────────────────────────────────────────────────

  @override
  void onRegister(PluginRegistry registry) {}

  @override
  void onDispose() {}

  // ─── Internals ───────────────────────────────────────────────────

  /// Gather all searchable text from an entry.
  static String _entryText(LogEntry entry) {
    final buf = StringBuffer();
    if (entry.message != null) buf.write(entry.message);
    if (entry.tag != null) {
      buf
        ..write(' ')
        ..write(entry.tag);
    }
    if (entry.exception != null) {
      buf
        ..write(' ')
        ..write(entry.exception!.message);
      if (entry.exception!.stackTrace != null) {
        buf
          ..write(' ')
          ..write(entry.exception!.stackTrace);
      }
    }
    return buf.toString();
  }

  /// Extract unique values matching [prefix]'s pattern from entry text,
  /// optionally filtered by a partial [value].
  static List<String> _extractValues(
    String prefix,
    String value,
    List<LogEntry> entries,
  ) {
    final pattern = _searchPatterns[prefix]!;
    final results = <String>{};
    final lower = value.toLowerCase();

    for (final entry in entries) {
      final text = _entryText(entry);
      for (final match in pattern.allMatches(text)) {
        final matched = match.group(0)!;
        if (value.isEmpty || matched.toLowerCase().contains(lower)) {
          results.add('$prefix$matched');
          if (results.length >= 8) return results.toList();
        }
      }
    }

    return results.toList();
  }
}
