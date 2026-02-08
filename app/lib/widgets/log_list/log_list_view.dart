import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/log_entry.dart';
import '../../services/log_store.dart';
import '../../services/sticky_state.dart';
import '../../services/time_range_service.dart';
import '../../theme/colors.dart';
import '../../theme/typography.dart';
import 'live_pill.dart';
import 'log_filter_cache.dart';
import 'log_list_builder.dart';
import 'log_row.dart';
import 'sticky_header.dart';

/// Main virtualized log list with auto-scroll (LIVE mode) and sticky headers.
class LogListView extends StatefulWidget {
  final String? sectionFilter;
  final String? textFilter;
  final Set<String> selectedSessionIds;
  final Set<String> activeSeverities;
  final bool selectionMode;
  final Set<String> selectedEntryIds;
  final ValueChanged<String>? onEntrySelected;
  final void Function(String targetId, List<String> orderedIds)?
  onEntryRangeSelected;
  final Set<String> bookmarkedEntryIds;
  final Set<String> stickyOverrideIds;

  const LogListView({
    super.key,
    this.sectionFilter,
    this.textFilter,
    this.selectedSessionIds = const {},
    this.activeSeverities = const {
      'debug',
      'info',
      'warning',
      'error',
      'critical',
    },
    this.selectionMode = false,
    this.selectedEntryIds = const {},
    this.onEntrySelected,
    this.onEntryRangeSelected,
    this.bookmarkedEntryIds = const {},
    this.stickyOverrideIds = const {},
  });

  @override
  State<LogListView> createState() => _LogListViewState();
}

class _LogListViewState extends State<LogListView> {
  final ScrollController _scrollController = ScrollController();
  final LogFilterCache _filterCache = LogFilterCache();
  final Set<String> _seenEntryIds = {};
  final Set<String> _collapsedGroups = {};
  final Set<String> _expandedStickyGroups = {};
  final Set<String> _processedUnpinIds = {};
  List<DisplayEntry> _currentDisplayEntries = [];
  bool _isLiveMode = true;
  int _newLogCount = 0;
  int _selectedIndex = -1;
  int _firstVisibleIndex = 0;
  int _lastEntryCount = 0;
  static const double _estimatedRowHeight = 28.0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    final atBottom = pos.pixels >= pos.maxScrollExtent - 24;
    final newFirst = (pos.pixels / _estimatedRowHeight).floor().clamp(
      0,
      1 << 30,
    );
    if (newFirst != _firstVisibleIndex) _firstVisibleIndex = newFirst;
    if (atBottom && !_isLiveMode) {
      setState(() {
        _isLiveMode = true;
        _newLogCount = 0;
      });
    } else if (!atBottom && _isLiveMode) {
      setState(() => _isLiveMode = false);
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

  @override
  Widget build(BuildContext context) {
    final logStore = context.watch<LogStore>();
    final stickyState = context.watch<StickyStateService>();
    final timeRange = context.watch<TimeRangeService>();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      processUnpinEntries(
        logStore: logStore,
        stickyState: stickyState,
        processedUnpinIds: _processedUnpinIds,
      );
    });

    final filteredEntries = _filterCache.getFiltered(
      logStore: logStore,
      timeRange: timeRange,
      sectionFilter: widget.sectionFilter,
      textFilter: widget.textFilter,
      activeSeverities: widget.activeSeverities,
      selectedSessionIds: widget.selectedSessionIds,
    );
    final displayEntries = processGrouping(
      entries: filteredEntries,
      textFilter: widget.textFilter,
      collapsedGroups: _collapsedGroups,
      stickyOverrideIds: widget.stickyOverrideIds,
    );
    _currentDisplayEntries = displayEntries;
    final effectiveFirstVisible = _isLiveMode
        ? displayEntries.length
        : _firstVisibleIndex;
    final stickySections = computeStickySections(
      displayEntries,
      firstVisibleIndex: effectiveFirstVisible,
      dismissedIds: stickyState.dismissedIds,
      ignoredGroupIds: stickyState.ignoredGroupIds,
      expandedStickyGroups: _expandedStickyGroups,
      collapsedGroups: _collapsedGroups,
    );

    if (displayEntries.length > _lastEntryCount && !_isLiveMode) {
      _newLogCount += displayEntries.length - _lastEntryCount;
    }
    _lastEntryCount = displayEntries.length;

    if (_isLiveMode && displayEntries.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
      });
    }

    if (displayEntries.isEmpty) {
      return Container(
        color: LoggerColors.bgSurface,
        child: Center(
          child: Text('Waiting for logs...', style: LoggerTypography.logBody),
        ),
      );
    }

    return Stack(
      children: [
        Listener(
          onPointerSignal: _handlePointerSignal,
          child: Column(
            children: [
              if (stickySections.isNotEmpty)
                StickyHeaderOverlay(
                  sections: stickySections,
                  onHiddenTap: _onHiddenTap,
                  stickyState: stickyState,
                ),
              Expanded(
                child: Container(
                  color: LoggerColors.bgSurface,
                  child: SelectionArea(
                    child: ListView.builder(
                      controller: _scrollController,
                      physics: const ClampingScrollPhysics(),
                      itemCount: displayEntries.length,
                      itemBuilder: (ctx, i) => _buildItem(displayEntries[i], i),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (!_isLiveMode && _newLogCount > 0)
          Positioned(
            bottom: 8,
            right: 8,
            child: NewLogsButton(count: _newLogCount, onTap: _scrollToBottom),
          ),
        if (_isLiveMode)
          const Positioned(bottom: 8, right: 8, child: LivePill()),
      ],
    );
  }

  Widget _buildItem(DisplayEntry display, int index) {
    final entry = display.entry;
    final isNew = !_seenEntryIds.contains(entry.id);
    if (isNew) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _seenEntryIds.add(entry.id);
      });
    }
    return LogRow(
      key: ValueKey(entry.id),
      entry: entry,
      isNew: isNew,
      isEvenRow: index.isEven,
      isSelected: _selectedIndex == index,
      selectionMode: widget.selectionMode,
      isSelectionSelected: widget.selectedEntryIds.contains(entry.id),
      onSelect: () {
        if (widget.selectionMode && _isShiftHeld()) {
          final orderedIds = _currentDisplayEntries
              .map((e) => e.entry.id)
              .toList();
          widget.onEntryRangeSelected?.call(entry.id, orderedIds);
        } else {
          widget.onEntrySelected?.call(entry.id);
        }
      },
      isBookmarked: widget.bookmarkedEntryIds.contains(entry.id),
      groupDepth: display.depth,
      onTap: () {
        setState(() {
          _selectedIndex = _selectedIndex == index ? -1 : index;
        });
      },
      onGroupToggle:
          entry.type == LogType.group &&
              entry.groupAction == GroupAction.open &&
              !display.isStandalone
          ? () => setState(() {
              final gid = entry.groupId ?? entry.id;
              _collapsedGroups.contains(gid)
                  ? _collapsedGroups.remove(gid)
                  : _collapsedGroups.add(gid);
            })
          : null,
      isCollapsed:
          entry.type == LogType.group &&
          entry.groupAction == GroupAction.open &&
          !display.isStandalone &&
          _collapsedGroups.contains(entry.groupId ?? entry.id),
    );
  }
}
