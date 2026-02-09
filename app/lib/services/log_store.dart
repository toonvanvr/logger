import 'package:flutter/foundation.dart';

import '../models/log_entry.dart';

/// In-memory log storage for the viewer.
class LogStore extends ChangeNotifier {
  /// Maximum number of entries before FIFO eviction kicks in.
  static const int maxEntries = 100000;

  /// Maximum number of versions retained per stack.
  static const int maxStackDepth = 500;

  final List<LogEntry> _entries = [];
  final Map<String, int> _idIndex = {};
  final Map<String, Map<String, dynamic>> _stateStore = {};
  final Map<String, List<LogEntry>> _stacks = {};
  final Map<String, String> _idToStack = {};
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
      if (entry.message != null) bytes += entry.message!.length * 2;
    }
    return bytes;
  }

  /// Compute the stack key for an entry, or null if not stackable.
  String? stackKeyFor(LogEntry entry) {
    if (entry.kind == EntryKind.event && entry.replace) {
      return '${entry.sessionId}::${entry.id}';
    }
    if (entry.kind == EntryKind.data && entry.key != null && entry.override_) {
      return '${entry.sessionId}::data::${entry.key}';
    }
    return null;
  }

  /// Number of versions in the stack for the given entry id.
  int stackDepth(String entryId) {
    final key = _idToStack[entryId];
    if (key == null) return 1;
    return _stacks[key]?.length ?? 1;
  }

  /// Full version list (oldest→newest) for the given entry id.
  List<LogEntry> getStack(String entryId) {
    final key = _idToStack[entryId];
    if (key != null && _stacks.containsKey(key)) {
      return List.unmodifiable(_stacks[key]!);
    }
    final idx = _idIndex[entryId];
    if (idx != null && idx < _entries.length) {
      return [_entries[idx]];
    }
    return [];
  }

  /// Add a single log entry, handling replace/upsert by id and stacking.
  void addEntry(LogEntry entry) {
    // Handle state updates
    if (entry.kind == EntryKind.data && entry.key != null) {
      _stateStore.putIfAbsent(entry.sessionId, () => {});
      if (entry.value == null) {
        _stateStore[entry.sessionId]!.remove(entry.key);
      } else {
        _stateStore[entry.sessionId]![entry.key!] = entry.value;
      }
    }

    // Stacking: compute stack key and handle existing stacks
    final stackKey = stackKeyFor(entry);
    if (stackKey != null && _stacks.containsKey(stackKey)) {
      final stack = _stacks[stackKey]!;
      final oldHead = stack.last;
      stack.add(entry);
      _idToStack[entry.id] = stackKey;
      while (stack.length > maxStackDepth) {
        final removed = stack.removeAt(0);
        if (removed.id != entry.id) {
          _idToStack.remove(removed.id);
        }
      }
      if (_idIndex.containsKey(oldHead.id)) {
        final index = _idIndex[oldHead.id]!;
        _entries[index] = entry;
        if (oldHead.id != entry.id) {
          _idIndex.remove(oldHead.id);
          _idIndex[entry.id] = index;
        }
      }
      _version++;
      notifyListeners();
      return;
    }

    // New stack for stackable entries
    if (stackKey != null) {
      _stacks[stackKey] = [entry];
      _idToStack[entry.id] = stackKey;
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
      // Handle state updates
      if (entry.kind == EntryKind.data && entry.key != null) {
        _stateStore.putIfAbsent(entry.sessionId, () => {});
        if (entry.value == null) {
          _stateStore[entry.sessionId]!.remove(entry.key);
        } else {
          _stateStore[entry.sessionId]![entry.key!] = entry.value;
        }
      }

      final stackKey = stackKeyFor(entry);
      if (stackKey != null && _stacks.containsKey(stackKey)) {
        final stack = _stacks[stackKey]!;
        final oldHead = stack.last;
        stack.add(entry);
        _idToStack[entry.id] = stackKey;
        while (stack.length > maxStackDepth) {
          final removed = stack.removeAt(0);
          if (removed.id != entry.id) {
            _idToStack.remove(removed.id);
          }
        }
        if (_idIndex.containsKey(oldHead.id)) {
          final index = _idIndex[oldHead.id]!;
          _entries[index] = entry;
          if (oldHead.id != entry.id) {
            _idIndex.remove(oldHead.id);
            _idIndex[entry.id] = index;
          }
        }
        continue;
      }

      if (stackKey != null) {
        _stacks[stackKey] = [entry];
        _idToStack[entry.id] = stackKey;
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

  /// Insert historical entries WITHOUT triggering live scroll.
  ///
  /// Deduplicates by ID (skips entries already in the store) and inserts
  /// at the beginning of the list, sorted by timestamp, to maintain order.
  /// Returns the number of entries actually inserted.
  int insertHistorical(List<LogEntry> entries) {
    final toInsert = <LogEntry>[];
    for (final entry in entries) {
      if (_idIndex.containsKey(entry.id)) continue;

      // If entry belongs to an existing stack, add to history only
      final stackKey = stackKeyFor(entry);
      if (stackKey != null && _stacks.containsKey(stackKey)) {
        final stack = _stacks[stackKey]!;
        var insertIdx = 0;
        while (insertIdx < stack.length - 1 &&
            stack[insertIdx].timestamp.compareTo(entry.timestamp) < 0) {
          insertIdx++;
        }
        stack.insert(insertIdx, entry);
        _idToStack[entry.id] = stackKey;
        while (stack.length > maxStackDepth) {
          final removed = stack.removeAt(0);
          if (removed.id != entry.id) {
            _idToStack.remove(removed.id);
          }
        }
        continue;
      }

      toInsert.add(entry);
    }
    if (toInsert.isEmpty) return 0;

    // Sort historical entries by timestamp (oldest first)
    toInsert.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    // Prepend to the front of the list
    _entries.insertAll(0, toInsert);

    // Rebuild the id index since all indices shifted
    _idIndex.clear();
    for (var i = 0; i < _entries.length; i++) {
      _idIndex[_entries[i].id] = i;
    }

    // Set up stacks for new historical entries
    for (final entry in toInsert) {
      final stackKey = stackKeyFor(entry);
      if (stackKey != null && !_stacks.containsKey(stackKey)) {
        _stacks[stackKey] = [entry];
        _idToStack[entry.id] = stackKey;
      } else if (stackKey != null) {
        _idToStack[entry.id] = stackKey;
      }
    }

    // Handle state updates for historical entries
    for (final entry in toInsert) {
      if (entry.kind == EntryKind.data && entry.key != null) {
        _stateStore.putIfAbsent(entry.sessionId, () => {});
        if (entry.value == null) {
          _stateStore[entry.sessionId]!.remove(entry.key);
        } else {
          _stateStore[entry.sessionId]![entry.key!] = entry.value;
        }
      }
    }

    _evictIfNeeded();
    _version++;
    notifyListeners();
    return toInsert.length;
  }

  /// Remove oldest entries when the cap is exceeded, rebuilding the id index.
  void _evictIfNeeded() {
    if (_entries.length <= maxEntries) return;
    final excess = _entries.length - maxEntries;
    for (var i = 0; i < excess; i++) {
      final evictedId = _entries[i].id;
      _idIndex.remove(evictedId);
      // Clean up entire stack when evicting a head entry
      final stackKey = _idToStack.remove(evictedId);
      if (stackKey != null && _stacks.containsKey(stackKey)) {
        final stack = _stacks.remove(stackKey)!;
        for (final e in stack) {
          _idToStack.remove(e.id);
        }
      }
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
    _stacks.clear();
    _idToStack.clear();
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
      if (section != null && entry.tag != section) return false;
      if (textSearch != null && textSearch.isNotEmpty) {
        final query = textSearch.toLowerCase();
        final text = entry.message?.toLowerCase() ?? '';
        if (!text.contains(query)) return false;
      }
      return true;
    }).toList();
  }
}
