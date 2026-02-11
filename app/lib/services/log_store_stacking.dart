import '../models/log_entry.dart';

/// Manages entry stacking (version history) for replaceable log entries.
///
/// Stackable entries are events with `replace: true` or data entries
/// with `override: true`. Each stack tracks all versions of an entry,
/// keyed by a composite of session ID and entry/data key.
class StackManager {
  /// Maximum number of versions retained per stack.
  static const int maxStackDepth = 500;

  final Map<String, List<LogEntry>> _stacks = {};
  final Map<String, String> _idToStack = {};

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
  ///
  /// Falls back to looking up [entries] by [idIndex] when no stack exists.
  List<LogEntry> getStack(
    String entryId,
    List<LogEntry> entries,
    Map<String, int> idIndex,
  ) {
    final key = _idToStack[entryId];
    if (key != null && _stacks.containsKey(key)) {
      return List.unmodifiable(_stacks[key]!);
    }
    final idx = idIndex[entryId];
    if (idx != null && idx < entries.length) {
      return [entries[idx]];
    }
    return [];
  }

  /// Process stacking for a new entry.
  ///
  /// Returns the updated entry list index if the entry was stacked onto an
  /// existing stack (replacing the head in [entries]), or `null` if this
  /// is not a stacked replacement (caller should do normal insert).
  int? processEntry(
    LogEntry entry,
    List<LogEntry> entries,
    Map<String, int> idIndex,
  ) {
    final stackKey = stackKeyFor(entry);

    if (stackKey != null && _stacks.containsKey(stackKey)) {
      final stack = _stacks[stackKey]!;
      final oldHead = stack.last;
      stack.add(entry);
      _idToStack[entry.id] = stackKey;
      _trimStack(stack, entry.id);

      if (idIndex.containsKey(oldHead.id)) {
        final index = idIndex[oldHead.id]!;
        entries[index] = entry;
        if (oldHead.id != entry.id) {
          idIndex.remove(oldHead.id);
          idIndex[entry.id] = index;
        }
      }
      return idIndex[entry.id];
    }

    if (stackKey != null) {
      _stacks[stackKey] = [entry];
      _idToStack[entry.id] = stackKey;
    }

    return null;
  }

  /// Process stacking for a historical entry.
  ///
  /// Returns `true` if the entry was absorbed into an existing stack
  /// (should NOT be added to the main entries list).
  bool processHistorical(LogEntry entry) {
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
      _trimStack(stack, entry.id);
      return true;
    }
    return false;
  }

  /// Set up stacks for newly inserted historical entries.
  void initHistoricalStacks(List<LogEntry> entries) {
    for (final entry in entries) {
      final stackKey = stackKeyFor(entry);
      if (stackKey != null && !_stacks.containsKey(stackKey)) {
        _stacks[stackKey] = [entry];
        _idToStack[entry.id] = stackKey;
      } else if (stackKey != null) {
        _idToStack[entry.id] = stackKey;
      }
    }
  }

  /// Remove the stack associated with an evicted entry id.
  void removeStackForEntry(String entryId) {
    final stackKey = _idToStack.remove(entryId);
    if (stackKey != null && _stacks.containsKey(stackKey)) {
      final stack = _stacks.remove(stackKey)!;
      for (final e in stack) {
        _idToStack.remove(e.id);
      }
    }
  }

  /// Clear all stacking state.
  void clear() {
    _stacks.clear();
    _idToStack.clear();
  }

  /// Trim a stack to the maximum depth, cleaning up id mappings.
  void _trimStack(List<LogEntry> stack, String currentId) {
    while (stack.length > maxStackDepth) {
      final removed = stack.removeAt(0);
      if (removed.id != currentId) {
        _idToStack.remove(removed.id);
      }
    }
  }
}
