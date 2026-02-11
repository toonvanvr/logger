import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/log_entry.dart';

/// Manages multi-select, range-select, bookmarking, sticky pinning,
/// clipboard copy, and JSON export of selected log entries.
class SelectionService extends ChangeNotifier {
  bool _selectionMode = false;
  Set<String> _selectedEntryIds = {};
  String? _lastSelectedEntryId;
  final Set<String> _bookmarkedEntryIds = {};
  final Set<String> _stickyOverrideIds = {};

  bool get selectionMode => _selectionMode;
  Set<String> get selectedEntryIds => _selectedEntryIds;
  Set<String> get bookmarkedEntryIds => _bookmarkedEntryIds;
  Set<String> get stickyOverrideIds => _stickyOverrideIds;

  void setSelectionMode(bool value) {
    if (_selectionMode != value) {
      _selectionMode = value;
      notifyListeners();
    }
  }

  void onEntrySelected(String id) {
    _lastSelectedEntryId = id;
    if (_selectedEntryIds.contains(id)) {
      _selectedEntryIds.remove(id);
    } else {
      _selectedEntryIds.add(id);
    }
    if (_selectedEntryIds.isEmpty &&
        !HardwareKeyboard.instance.logicalKeysPressed.contains(
          LogicalKeyboardKey.shiftLeft,
        ) &&
        !HardwareKeyboard.instance.logicalKeysPressed.contains(
          LogicalKeyboardKey.shiftRight,
        )) {
      _selectionMode = false;
    }
    notifyListeners();
  }

  void clearSelection() {
    _selectedEntryIds = {};
    _selectionMode = false;
    _lastSelectedEntryId = null;
    notifyListeners();
  }

  void onEntryRangeSelected(String targetId, List<String> orderedIds) {
    if (_lastSelectedEntryId == null) {
      onEntrySelected(targetId);
      return;
    }
    final anchorIdx = orderedIds.indexOf(_lastSelectedEntryId!);
    final targetIdx = orderedIds.indexOf(targetId);
    if (anchorIdx == -1 || targetIdx == -1) {
      onEntrySelected(targetId);
      return;
    }
    final start = anchorIdx < targetIdx ? anchorIdx : targetIdx;
    final end = anchorIdx < targetIdx ? targetIdx : anchorIdx;
    _selectedEntryIds.addAll(orderedIds.sublist(start, end + 1).toSet());
    notifyListeners();
  }

  /// Copy selected entries' messages to clipboard.
  /// Takes entries list as parameter to avoid tight coupling to LogStore.
  void copySelected(List<LogEntry> allEntries) {
    final entries = allEntries
        .where((e) => _selectedEntryIds.contains(e.id))
        .map((e) => e.message ?? '')
        .join('\n');
    Clipboard.setData(ClipboardData(text: entries));
  }

  /// Export selected entries as JSON to clipboard.
  void exportSelectedJson(List<LogEntry> allEntries) {
    final entries = allEntries
        .where((e) => _selectedEntryIds.contains(e.id))
        .map(
          (e) => {
            'id': e.id,
            'timestamp': e.timestamp,
            'severity': e.severity.name,
            'message': e.message,
            'sessionId': e.sessionId,
          },
        )
        .toList();
    final json = const JsonEncoder.withIndent('  ').convert(entries);
    Clipboard.setData(ClipboardData(text: json));
  }

  void bookmarkSelected() {
    for (final id in _selectedEntryIds) {
      if (_bookmarkedEntryIds.contains(id)) {
        _bookmarkedEntryIds.remove(id);
      } else {
        _bookmarkedEntryIds.add(id);
      }
    }
    notifyListeners();
  }

  void stickySelected() {
    final allPinned = _selectedEntryIds.every(
      (id) => _stickyOverrideIds.contains(id),
    );
    if (allPinned) {
      _stickyOverrideIds.removeAll(_selectedEntryIds);
    } else {
      _stickyOverrideIds.addAll(_selectedEntryIds);
    }
    notifyListeners();
  }
}
