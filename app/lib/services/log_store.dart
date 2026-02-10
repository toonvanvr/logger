import 'package:flutter/foundation.dart';

import '../models/log_entry.dart';
import 'log_store_stacking.dart';

/// In-memory log storage for the viewer.
class LogStore extends ChangeNotifier {
  /// Maximum number of entries before FIFO eviction kicks in.
  static const int maxEntries = 100000;

  final List<LogEntry> _entries = [];
  final Map<String, int> _idIndex = {};
  final Map<String, Map<String, dynamic>> _stateStore = {};
  final StackManager _stacking = StackManager();
  int _version = 0;

  /// Monotonically increasing version number, incremented on each mutation.
  int get version => _version;

  /// All log entries in insertion order.
  List<LogEntry> get entries => List.unmodifiable(_entries);

  /// Total entry count.
  int get length => _entries.length;

  /// Alias for [length] used by the status bar.
  int get entryCount => length;

  /// Rough estimate of memory consumed by stored entries (in bytes).
  int get estimatedMemoryBytes =>
      _entries.fold(0, (sum, e) => sum + 256 + (e.message?.length ?? 0) * 2);

  /// Maximum stack depth before oldest versions are trimmed.
  static const int maxStackDepth = StackManager.maxStackDepth;

  /// Compute the stack key for an entry, or null if not stackable.
  String? stackKeyFor(LogEntry entry) => _stacking.stackKeyFor(entry);

  /// Number of versions in the stack for the given entry id.
  int stackDepth(String entryId) => _stacking.stackDepth(entryId);

  /// Full version list (oldest->newest) for the given entry id.
  List<LogEntry> getStack(String entryId) =>
      _stacking.getStack(entryId, _entries, _idIndex);

  /// Add a single log entry, handling replace/upsert by id and stacking.
  void addEntry(LogEntry entry) {
    _updateState(entry);

    // Stacking: delegate to StackManager
    final stackResult = _stacking.processEntry(entry, _entries, _idIndex);
    if (stackResult != null) {
      _version++;
      notifyListeners();
      return;
    }

    // Upsert: replace existing entry with same id (non-stacked)
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
      _updateState(entry);

      final stackResult = _stacking.processEntry(entry, _entries, _idIndex);
      if (stackResult != null) continue;

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

  /// Insert historical entries WITHOUT triggering live scroll.
  /// Deduplicates by ID, inserts at beginning sorted by timestamp.
  /// Returns the number of entries actually inserted.
  int insertHistorical(List<LogEntry> entries) {
    final toInsert = <LogEntry>[];
    for (final entry in entries) {
      if (_idIndex.containsKey(entry.id)) continue;
      if (_stacking.processHistorical(entry)) continue;
      toInsert.add(entry);
    }
    if (toInsert.isEmpty) return 0;

    toInsert.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    _entries.insertAll(0, toInsert);
    _rebuildIdIndex();
    _stacking.initHistoricalStacks(toInsert);

    for (final entry in toInsert) {
      _updateState(entry);
    }

    _evictIfNeeded();
    _version++;
    notifyListeners();
    return toInsert.length;
  }

  /// Handle state updates for a single entry.
  void _updateState(LogEntry entry) {
    if (entry.kind == EntryKind.data && entry.key != null) {
      _stateStore.putIfAbsent(entry.sessionId, () => {});
      if (entry.value == null) {
        _stateStore[entry.sessionId]!.remove(entry.key);
      } else {
        _stateStore[entry.sessionId]![entry.key!] = entry.value;
      }
    }
  }

  /// Remove oldest entries when the cap is exceeded, rebuilding the id index.
  void _evictIfNeeded() {
    if (_entries.length <= maxEntries) return;
    final excess = _entries.length - maxEntries;
    for (var i = 0; i < excess; i++) {
      final evictedId = _entries[i].id;
      _idIndex.remove(evictedId);
      _stacking.removeStackForEntry(evictedId);
    }
    _entries.removeRange(0, excess);
    _rebuildIdIndex();
  }

  /// Rebuild the id->index map after list mutations.
  void _rebuildIdIndex() {
    _idIndex
      ..clear()
      ..addAll({for (var i = 0; i < _entries.length; i++) _entries[i].id: i});
  }

  /// Clear all stored entries and state.
  void clear() {
    _entries.clear();
    _idIndex.clear();
    _stateStore.clear();
    _stacking.clear();
    _version++;
    notifyListeners();
  }

  /// Get the state map for a given session.
  Map<String, dynamic> getState(String sessionId) =>
      _stateStore[sessionId] ?? {};

  /// Merged state across all sessions (later values win on key conflicts).
  Map<String, dynamic> get mergedState => {
    for (final s in _stateStore.values) ...s,
  };

  /// Count of merged state keys.
  int get stateEntryCount => mergedState.length;

  /// Filter entries by optional criteria.
  List<LogEntry> filter({
    Set<String>? sessionIds,
    Severity? minSeverity,
    String? tag,
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
      if (tag != null && entry.tag != tag) return false;
      if (textSearch != null && textSearch.isNotEmpty) {
        final query = textSearch.toLowerCase();
        final text = entry.message?.toLowerCase() ?? '';
        if (!text.contains(query)) return false;
      }
      return true;
    }).toList();
  }
}
