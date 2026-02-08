import 'package:flutter/foundation.dart';

import '../models/log_entry.dart';

/// In-memory log storage for the viewer.
class LogStore extends ChangeNotifier {
  /// Maximum number of entries before FIFO eviction kicks in.
  static const int maxEntries = 100000;

  final List<LogEntry> _entries = [];
  final Map<String, int> _idIndex = {};
  final Map<String, Map<String, dynamic>> _stateStore = {};
  int _version = 0;

  /// Monotonically increasing version number, incremented on each mutation.
  int get version => _version;

  /// All log entries in insertion order.
  List<LogEntry> get entries => List.unmodifiable(_entries);

  /// Total entry count.
  int get length => _entries.length;

  /// Alias for [length] used by the status bar.
  int get entryCount => _entries.length;

  /// Rough estimate of memory consumed by stored entries (in bytes).
  ///
  /// Uses a heuristic of ~256 bytes per entry for the object overhead plus
  /// the length of the text payload (2 bytes per char for Dart strings).
  int get estimatedMemoryBytes {
    var bytes = 0;
    for (final entry in _entries) {
      bytes += 256; // object overhead estimate
      if (entry.text != null) bytes += entry.text!.length * 2;
    }
    return bytes;
  }

  /// Add a single log entry, handling replace/upsert by id.
  void addEntry(LogEntry entry) {
    // Handle state updates
    if (entry.type == LogType.state && entry.stateKey != null) {
      _stateStore.putIfAbsent(entry.sessionId, () => {});
      if (entry.stateValue == null) {
        _stateStore[entry.sessionId]!.remove(entry.stateKey);
      } else {
        _stateStore[entry.sessionId]![entry.stateKey!] = entry.stateValue;
      }
    }

    // Upsert: replace existing entry with same id
    if (entry.replace == true && _idIndex.containsKey(entry.id)) {
      final index = _idIndex[entry.id]!;
      _entries[index] = entry;
      _version++;
      notifyListeners();
      return;
    }

    // Normal insert
    _idIndex[entry.id] = _entries.length;
    _entries.add(entry);
    _evictIfNeeded();
    _version++;
    notifyListeners();
  }

  /// Add multiple entries at once (batch).
  void addEntries(List<LogEntry> entries) {
    for (final entry in entries) {
      // Handle state updates
      if (entry.type == LogType.state && entry.stateKey != null) {
        _stateStore.putIfAbsent(entry.sessionId, () => {});
        if (entry.stateValue == null) {
          _stateStore[entry.sessionId]!.remove(entry.stateKey);
        } else {
          _stateStore[entry.sessionId]![entry.stateKey!] = entry.stateValue;
        }
      }

      if (entry.replace == true && _idIndex.containsKey(entry.id)) {
        final index = _idIndex[entry.id]!;
        _entries[index] = entry;
      } else {
        _idIndex[entry.id] = _entries.length;
        _entries.add(entry);
      }
    }
    _evictIfNeeded();
    _version++;
    notifyListeners();
  }

  /// Remove oldest entries when the cap is exceeded, rebuilding the id index.
  void _evictIfNeeded() {
    if (_entries.length <= maxEntries) return;
    final excess = _entries.length - maxEntries;
    for (var i = 0; i < excess; i++) {
      _idIndex.remove(_entries[i].id);
    }
    _entries.removeRange(0, excess);
    _idIndex.clear();
    for (var i = 0; i < _entries.length; i++) {
      _idIndex[_entries[i].id] = i;
    }
  }

  /// Clear all stored entries and state.
  void clear() {
    _entries.clear();
    _idIndex.clear();
    _stateStore.clear();
    _version++;
    notifyListeners();
  }

  /// Get the state map for a given session.
  Map<String, dynamic> getState(String sessionId) =>
      _stateStore[sessionId] ?? {};

  /// Merged state across all sessions (later session values win on key conflicts).
  Map<String, dynamic> get mergedState {
    final merged = <String, dynamic>{};
    for (final sessionState in _stateStore.values) {
      merged.addAll(sessionState);
    }
    return merged;
  }

  /// Count of merged state keys.
  int get stateEntryCount => mergedState.length;

  /// Filter entries by optional criteria.
  List<LogEntry> filter({
    Set<String>? sessionIds,
    Severity? minSeverity,
    String? section,
    String? textSearch,
  }) {
    return _entries.where((entry) {
      if (sessionIds != null &&
          sessionIds.isNotEmpty &&
          !sessionIds.contains(entry.sessionId)) {
        return false;
      }
      if (minSeverity != null && entry.severity.index < minSeverity.index) {
        return false;
      }
      if (section != null && entry.section != section) return false;
      if (textSearch != null && textSearch.isNotEmpty) {
        final query = textSearch.toLowerCase();
        final text = entry.text?.toLowerCase() ?? '';
        if (!text.contains(query)) return false;
      }
      return true;
    }).toList();
  }
}
