import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../services/connection_manager.dart';
import '../../services/log_store.dart';
import '../../services/sticky_state.dart';
import '../../services/time_range_service.dart';
import '../../theme/colors.dart';
import '../../theme/typography.dart';
import 'live_pill.dart';
import 'log_filter_cache.dart';
import 'log_list_builder.dart';
import 'log_row.dart';
import 'stack_expansion_panel.dart';
import 'sticky_header_overlay.dart';
import 'sticky_section_builder.dart';

part 'log_list_item_builder.dart';
part 'log_list_scroll.dart';

/// Main virtualized log list with auto-scroll (LIVE mode) and sticky headers.
class LogListView extends StatefulWidget {
  final String? tagFilter;
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
  final bool flatMode;

  const LogListView({
    super.key,
    this.tagFilter,
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
    this.flatMode = false,
  });

  @override
  State<LogListView> createState() => _LogListViewState();
}

class _LogListViewState extends State<LogListView>
    with _LogListScrollMixin, _LogListItemBuilderMixin {
  final LogFilterCache _filterCache = LogFilterCache();

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
    // Select only filter-relevant fields — avoids rebuilds when buckets,
    // viewport position, or other minimap state changes.
    context.select<TimeRangeService, (bool, DateTime?, DateTime?)>(
      (s) => (s.isActive, s.rangeStart, s.rangeEnd),
    );
    final timeRange = context.read<TimeRangeService>();
    final filteredEntries = _filterCache.getFiltered(
      logStore: logStore,
      timeRange: timeRange,
      tagFilter: widget.tagFilter,
      textFilter: widget.textFilter,
      activeSeverities: widget.activeSeverities,
      selectedSessionIds: widget.selectedSessionIds,
    );
    autoCollapseGroups(
      entries: filteredEntries,
      collapsedGroups: _collapsedGroups,
      seenGroupIds: _autoCollapsedSeen,
    );
    final displayEntries = processGrouping(
      entries: filteredEntries,
      textFilter: widget.textFilter,
      collapsedGroups: _collapsedGroups,
      stickyOverrideIds: widget.stickyOverrideIds,
      logStore: logStore,
      flatMode: widget.flatMode,
    );
    _currentDisplayEntries = displayEntries;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      processUnpinEntries(
        logStore: logStore,
        stickyState: stickyState,
        processedUnpinIds: _processedUnpinIds,
        displayEntries: displayEntries,
        firstVisibleIndex: _isLiveMode
            ? displayEntries.length
            : _firstVisibleIndex,
        isLiveMode: _isLiveMode,
      );
    });
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
          final pos = _scrollController.position;
          final delta = pos.maxScrollExtent - pos.pixels;
          if (delta > 28.0) {
            _scrollController.jumpTo(pos.maxScrollExtent);
          }
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
                    itemBuilder: (ctx, i) =>
                        _buildItem(displayEntries[i], i, logStore),
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
}
