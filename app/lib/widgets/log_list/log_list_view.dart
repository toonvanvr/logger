import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../services/log_connection.dart';
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
import 'sticky_section_builder.dart';

part 'log_list_scroll.dart';

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
  final VoidCallback? onFilterClear;

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
    this.onFilterClear,
  });

  @override
  State<LogListView> createState() => _LogListViewState();
}

class _LogListViewState extends State<LogListView> with _LogListScrollMixin {
  final LogFilterCache _filterCache = LogFilterCache();
  final Set<String> _seenEntryIds = {};
  final Set<String> _collapsedGroups = {};
  final Set<String> _processedUnpinIds = {};
  List<DisplayEntry> _currentDisplayEntries = [];
  int _selectedIndex = -1;

  @override
  void initState() {
    super.initState();
    _initScroll();
  }

  @override
  void dispose() {
    _disposeScroll();
    super.dispose();
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
    final stickySections = computeStickySections(
      displayEntries,
      firstVisibleIndex: _isLiveMode
          ? displayEntries.length
          : _firstVisibleIndex,
      dismissedIds: stickyState.dismissedIds,
      ignoredGroupIds: stickyState.ignoredGroupIds,
      expandedStickyGroups: _expandedStickyGroups,
      collapsedGroups: _collapsedGroups,
    );

    _trackNewEntries(displayEntries.length);

    if (_isLiveMode && displayEntries.isNotEmpty) {
      _isAutoScrolling = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
        _isAutoScrolling = false;
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
              StickyHeaderOverlay(
                sections: stickySections,
                onHiddenTap: _onHiddenTap,
                stickyState: stickyState,
              ),
              Expanded(
                child: Container(
                  color: LoggerColors.bgSurface,
                  child: ListView.builder(
                    controller: _scrollController,
                    physics: const ClampingScrollPhysics(),
                    itemCount: displayEntries.length,
                    itemBuilder: (ctx, i) => _buildItem(displayEntries[i], i),
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
          Positioned(
            bottom: 8,
            right: 8,
            child: LivePill(onTap: widget.onFilterClear),
          ),
      ],
    );
  }

  Widget _buildItem(DisplayEntry display, int index) {
    final entry = display.entry;
    final isNew = _seenEntryIds.add(entry.id);
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
      onGroupToggle: entry.groupId != null && !display.isStandalone
          ? () => setState(() {
              final gid = entry.groupId!;
              _collapsedGroups.contains(gid)
                  ? _collapsedGroups.remove(gid)
                  : _collapsedGroups.add(gid);
            })
          : null,
      isCollapsed:
          entry.groupId != null &&
          !display.isStandalone &&
          _collapsedGroups.contains(entry.groupId!),
    );
  }
}
