part of 'log_viewer.dart';

/// Selection state and interaction handling for the log viewer.
///
/// Manages multi-select, range-select, bookmarking, sticky pinning,
/// clipboard copy, and JSON export of selected log entries.
mixin _SelectionMixin on State<LogViewerScreen> {
  bool _selectionMode = false;
  Set<String> _selectedEntryIds = {};
  String? _lastSelectedEntryId;
  final Set<String> _bookmarkedEntryIds = {};
  final Set<String> _stickyOverrideIds = {};

  void _onEntrySelected(String id) {
    setState(() {
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
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedEntryIds = {};
      _selectionMode = false;
      _lastSelectedEntryId = null;
    });
  }

  void _onEntryRangeSelected(String targetId, List<String> orderedIds) {
    if (_lastSelectedEntryId == null) {
      _onEntrySelected(targetId);
      return;
    }
    final anchorIdx = orderedIds.indexOf(_lastSelectedEntryId!);
    final targetIdx = orderedIds.indexOf(targetId);
    if (anchorIdx == -1 || targetIdx == -1) {
      _onEntrySelected(targetId);
      return;
    }
    final start = anchorIdx < targetIdx ? anchorIdx : targetIdx;
    final end = anchorIdx < targetIdx ? targetIdx : anchorIdx;
    setState(() {
      _selectedEntryIds.addAll(orderedIds.sublist(start, end + 1).toSet());
    });
  }

  void _copySelected() {
    final logStore = context.read<LogStore>();
    final entries = logStore.entries
        .where((e) => _selectedEntryIds.contains(e.id))
        .map((e) => e.message ?? '')
        .join('\n');
    Clipboard.setData(ClipboardData(text: entries));
  }

  void _exportSelectedJson() {
    final logStore = context.read<LogStore>();
    final entries = logStore.entries
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

  void _bookmarkSelected() {
    setState(() {
      for (final id in _selectedEntryIds) {
        if (_bookmarkedEntryIds.contains(id)) {
          _bookmarkedEntryIds.remove(id);
        } else {
          _bookmarkedEntryIds.add(id);
        }
      }
    });
  }

  void _stickySelected() {
    setState(() {
      final allPinned = _selectedEntryIds.every(
        (id) => _stickyOverrideIds.contains(id),
      );
      if (allPinned) {
        _stickyOverrideIds.removeAll(_selectedEntryIds);
      } else {
        _stickyOverrideIds.addAll(_selectedEntryIds);
      }
    });
  }
}
