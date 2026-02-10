part of 'log_viewer.dart';

/// Default severity set used when clearing filters.
const Set<String> _defaultSeverities = {
  'debug',
  'info',
  'warning',
  'error',
  'critical',
};

/// Keyboard shortcut handling and filter/setup state for the log viewer.
mixin _KeyboardMixin on State<LogViewerScreen>, _SelectionMixin {
  bool _isFilterExpanded = false;
  Set<String> _activeSeverities = _defaultSeverities;
  String _textFilter = '';
  List<String> _stateFilterStack = [];
  String? _selectedSection;
  bool _settingsPanelVisible = false;
  bool _flatMode = false;
  bool _landingDelayActive = true;
  Timer? _landingDelayTimer;

  bool _handleKeyEvent(KeyEvent event) {
    // Ctrl+M → toggle mini mode
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.keyM &&
        (HardwareKeyboard.instance.logicalKeysPressed.contains(
              LogicalKeyboardKey.controlLeft,
            ) ||
            HardwareKeyboard.instance.logicalKeysPressed.contains(
              LogicalKeyboardKey.controlRight,
            ))) {
      final settings = context.read<SettingsService>();
      settings.setMiniMode(!settings.miniMode);
      return true;
    }

    // Cmd+C / Ctrl+C → explicitly dispatch copy to the focused context
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.keyC &&
        (HardwareKeyboard.instance.logicalKeysPressed.contains(
              LogicalKeyboardKey.metaLeft,
            ) ||
            HardwareKeyboard.instance.logicalKeysPressed.contains(
              LogicalKeyboardKey.metaRight,
            ) ||
            HardwareKeyboard.instance.logicalKeysPressed.contains(
              LogicalKeyboardKey.controlLeft,
            ) ||
            HardwareKeyboard.instance.logicalKeysPressed.contains(
              LogicalKeyboardKey.controlRight,
            ))) {
      final ctx = primaryFocus?.context;
      if (ctx != null) {
        final action = Actions.maybeFind<CopySelectionTextIntent>(ctx);
        if (action != null) {
          Actions.invoke(ctx, CopySelectionTextIntent.copy);
          return true;
        }
      }
      return false;
    }

    if (event is KeyDownEvent &&
        (event.logicalKey == LogicalKeyboardKey.shiftLeft ||
            event.logicalKey == LogicalKeyboardKey.shiftRight)) {
      if (!_selectionMode) {
        setState(() => _selectionMode = true);
      }
      return false;
    }
    if (event is KeyUpEvent &&
        (event.logicalKey == LogicalKeyboardKey.shiftLeft ||
            event.logicalKey == LogicalKeyboardKey.shiftRight)) {
      if (_selectionMode && _selectedEntryIds.isEmpty) {
        setState(() => _selectionMode = false);
      }
      return false;
    }
    return false;
  }

  void _setupQueryStore() {
    final queryStore = context.read<QueryStore>();
    queryStore.onQueryLoaded = (query) {
      setState(() {
        _activeSeverities = Set.from(query.severities);
        _textFilter = query.textFilter;
        _stateFilterStack = [];
      });
    };
  }

  /// Process launch URI for filter, tab, and clear actions.
  void _handleLaunchUri() {
    final uri = widget.launchUri;
    if (uri == null) return;
    UriHandler.handleUri(
      uri,
      connectionManager: context.read<ConnectionManager>(),
      onFilter: (query) => setState(() => _textFilter = query),
      onTab: (name) => setState(() => _selectedSection = name),
      onClear: () => setState(() {
        _activeSeverities = _defaultSeverities;
        _textFilter = '';
        _stateFilterStack = [];
      }),
    );
  }

  /// Composes the effective filter from user text and state filter stack.
  String get _effectiveFilter {
    final parts = [
      _textFilter,
      ..._stateFilterStack.map((k) => 'state:$k'),
    ].where((s) => s.isNotEmpty);
    return parts.join(' ');
  }

  /// Toggles a state key in/out of the filter stack.
  void _toggleStateFilter(String stateKey) {
    setState(() {
      if (_stateFilterStack.contains(stateKey)) {
        _stateFilterStack.remove(stateKey);
      } else {
        _stateFilterStack.add(stateKey);
      }
      _isFilterExpanded = true;
    });
  }
}
