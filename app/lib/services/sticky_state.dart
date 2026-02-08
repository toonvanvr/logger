import 'package:flutter/foundation.dart';

/// Manages transient dismiss/ignore state for sticky entries.
///
/// Entries can be dismissed individually by ID, or entire groups can be
/// ignored by group ID. All state is session-scoped (lost on restart).
class StickyStateService extends ChangeNotifier {
  final Set<String> _dismissedIds = {};
  final Set<String> _ignoredGroupIds = {};

  /// Mark a single sticky entry as dismissed.
  void dismiss(String entryId) {
    _dismissedIds.add(entryId);
    notifyListeners();
  }

  /// Ignore all sticky entries from a group (current and future).
  void ignore(String groupId) {
    _ignoredGroupIds.add(groupId);
    notifyListeners();
  }

  /// Restore a previously dismissed entry.
  void restore(String entryId) {
    _dismissedIds.remove(entryId);
    notifyListeners();
  }

  /// Clear all dismissed and ignored state.
  void restoreAll() {
    _dismissedIds.clear();
    _ignoredGroupIds.clear();
    notifyListeners();
  }

  /// Whether a specific entry has been dismissed.
  bool isDismissed(String entryId) => _dismissedIds.contains(entryId);

  /// Whether a group has been ignored.
  bool isGroupIgnored(String groupId) => _ignoredGroupIds.contains(groupId);

  /// Number of individually dismissed entries.
  int get dismissedCount => _dismissedIds.length;

  /// Number of ignored groups.
  int get ignoredGroupCount => _ignoredGroupIds.length;

  /// Unmodifiable view of dismissed entry IDs.
  Set<String> get dismissedIds => Set.unmodifiable(_dismissedIds);

  /// Unmodifiable view of ignored group IDs.
  Set<String> get ignoredGroupIds => Set.unmodifiable(_ignoredGroupIds);
}
