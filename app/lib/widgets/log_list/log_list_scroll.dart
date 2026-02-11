part of 'log_list_view.dart';

/// Scroll management, live mode, and pointer handling for the log list.
///
/// Manages the scroll controller, auto-scroll ("LIVE mode"), new-log counting,
/// shift-detection for range select, sticky-group expand/collapse, and
/// alt-scroll line-by-line navigation.
mixin _LogListScrollMixin on State<LogListView> {
  final ScrollController _scrollController = ScrollController();
  bool _isLiveMode = true;
  bool _isAutoScrolling = false;
  int _newLogCount = 0;
  int _firstVisibleIndex = 0;
  int _lastEntryCount = 0;
  static const double _estimatedRowHeight = 28.0;

  /// Whether more historical entries are available for scrollback.
  bool _hasMoreHistorical = false;

  /// Opaque cursor for the next historical page request.
  String? _historicalCursor;

  /// Whether a historical fetch is currently in progress.
  bool _isFetchingHistorical = false;

  final Set<String> _expandedStickyGroups = {};

  void _initScroll() {
    _scrollController.addListener(_onScroll);
  }

  void _disposeScroll() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients || _isAutoScrolling) return;
    final pos = _scrollController.position;
    final atBottom =
        pos.pixels >= pos.maxScrollExtent - _estimatedRowHeight * 3.0;
    final newFirst = (pos.pixels / _estimatedRowHeight).floor().clamp(
      0,
      1 << 30,
    );
    if (newFirst != _firstVisibleIndex) {
      setState(() => _firstVisibleIndex = newFirst);
    }
    if (atBottom && !_isLiveMode) {
      setState(() {
        _isLiveMode = true;
        _newLogCount = 0;
      });
    } else if (!atBottom && _isLiveMode) {
      setState(() => _isLiveMode = false);
    }

    if (_hasMoreHistorical &&
        !_isFetchingHistorical &&
        pos.maxScrollExtent > 0) {
      final scrollFraction = pos.pixels / pos.maxScrollExtent;
      if (scrollFraction < 0.20) {
        _requestMoreHistory();
      }
    }
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
    );
    setState(() {
      _isLiveMode = true;
      _newLogCount = 0;
    });
  }

  bool _isShiftHeld() {
    return HardwareKeyboard.instance.logicalKeysPressed.contains(
          LogicalKeyboardKey.shiftLeft,
        ) ||
        HardwareKeyboard.instance.logicalKeysPressed.contains(
          LogicalKeyboardKey.shiftRight,
        );
  }

  void _onHiddenTap(String? groupId) {
    if (groupId == null) return;
    setState(() {
      _expandedStickyGroups.contains(groupId)
          ? _expandedStickyGroups.remove(groupId)
          : _expandedStickyGroups.add(groupId);
    });
  }

  void _trackNewEntries(int currentCount) {
    if (currentCount > _lastEntryCount && !_isLiveMode) {
      _newLogCount += currentCount - _lastEntryCount;
    }
    _lastEntryCount = currentCount;
  }

  /// Request more historical entries from the server.
  void _requestMoreHistory() {
    // Guard with try/catch since Provider.of may throw if not available.
    try {
      final connection = Provider.of<ConnectionManager>(context, listen: false);
      if (!connection.isConnected) return;
      _isFetchingHistorical = true;
      connection.queryHistory(cursor: _historicalCursor, limit: 500);
    } catch (_) {
      // No ConnectionManager available in the widget tree — skip.
    }
  }

  /// Update historical scrollback state from a history response.
  void updateHistoricalState({required bool hasMore, required String? cursor}) {
    _hasMoreHistorical = hasMore;
    _historicalCursor = cursor;
    _isFetchingHistorical = false;
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent || !_scrollController.hasClients) return;
    final altHeld =
        HardwareKeyboard.instance.logicalKeysPressed.contains(
          LogicalKeyboardKey.altLeft,
        ) ||
        HardwareKeyboard.instance.logicalKeysPressed.contains(
          LogicalKeyboardKey.altRight,
        );
    if (altHeld) {
      final lines = event.scrollDelta.dy.sign.toInt();
      final target = (_scrollController.offset + lines * _estimatedRowHeight)
          .clamp(
            _scrollController.position.minScrollExtent,
            _scrollController.position.maxScrollExtent,
          );
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 50),
        curve: Curves.easeOut,
      );
    } else {
      final pos = _scrollController.position;
      _scrollController.jumpTo(
        (pos.pixels + event.scrollDelta.dy).clamp(
          pos.minScrollExtent,
          pos.maxScrollExtent,
        ),
      );
    }
  }
}
