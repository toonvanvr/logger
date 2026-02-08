import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/log_entry.dart';
import '../../plugins/builtin/smart_search_plugin.dart';
import '../../plugins/plugin_registry.dart';
import '../../services/log_store.dart';
import '../../services/sticky_state.dart';
import '../../services/time_range_service.dart';
import '../../theme/colors.dart';
import '../../theme/typography.dart';
import 'live_pill.dart';
import 'log_row.dart';
import 'sticky_header.dart';

/// Main virtualized log list using [ListView.builder].
///
/// Supports auto-scroll (LIVE mode) when scrolled to the bottom, and shows
/// a "N new" button when the user scrolls up and new logs arrive.
class LogListView extends StatefulWidget {
  /// Optional section filter (e.g. 'state', 'events', or a custom name).
  final String? sectionFilter;

  /// Optional text search filter.
  final String? textFilter;

  /// Selected session IDs — when non-empty, only show logs from these sessions.
  final Set<String> selectedSessionIds;

  /// Set of active severity names for filtering.
  final Set<String> activeSeverities;

  /// Whether selection mode is active (Shift held).
  final bool selectionMode;

  /// Set of entry IDs currently selected.
  final Set<String> selectedEntryIds;

  /// Callback when an entry is toggled in selection mode.
  final ValueChanged<String>? onEntrySelected;

  /// Callback for shift+click range selection.
  final ValueChanged<String>? onEntryRangeSelected;

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
  });

  @override
  State<LogListView> createState() => _LogListViewState();
}

class _LogListViewState extends State<LogListView> {
  final ScrollController _scrollController = ScrollController();
  bool _isLiveMode = true;
  int _newLogCount = 0;
  int _selectedIndex = -1;

  /// Track which entry IDs have been seen for animation purposes.
  final Set<String> _seenEntryIds = {};

  /// Set of group IDs that are collapsed.
  final Set<String> _collapsedGroups = {};

  /// Set of group IDs whose hidden items are expanded in the sticky overlay.
  final Set<String> _expandedStickyGroups = {};

  /// Index of the first visible item in the display list.
  int _firstVisibleIndex = 0;

  /// Estimated row height for first-visible-index computation.
  static const double _estimatedRowHeight = 28.0;

  /// The last known entry count — used to detect new arrivals.
  int _lastEntryCount = 0;

  /// Cached filtered entries to avoid recomputation when filters haven't changed.
  List<LogEntry>? _cachedFilteredEntries;
  int _cachedLogStoreVersion = -1;
  String? _cachedSectionFilter;
  String? _cachedTextFilter;
  Set<String> _cachedActiveSeverities = const {};
  Set<String> _cachedSessionIds = const {};
  bool _cachedTimeRangeActive = false;
  DateTime? _cachedTimeRangeStart;
  DateTime? _cachedTimeRangeEnd;

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

    // S02: Track the first visible item index.
    final newFirstVisible = (pos.pixels / _estimatedRowHeight).floor().clamp(
      0,
      1 << 30,
    );
    if (newFirstVisible != _firstVisibleIndex) {
      _firstVisibleIndex = newFirstVisible;
    }

    if (atBottom && !_isLiveMode) {
      setState(() {
        _isLiveMode = true;
        _newLogCount = 0;
      });
    } else if (!atBottom && _isLiveMode) {
      setState(() {
        _isLiveMode = false;
      });
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

  /// S03: Toggle expansion of hidden items in a sticky group.
  void _onHiddenTap(String? groupId) {
    if (groupId == null) return;
    setState(() {
      if (_expandedStickyGroups.contains(groupId)) {
        _expandedStickyGroups.remove(groupId);
      } else {
        _expandedStickyGroups.add(groupId);
      }
    });
  }

  List<LogEntry> _getFilteredEntries(LogStore logStore) {
    // Time range filter (cheapest check first).
    final timeRange = context.read<TimeRangeService>();

    var results = logStore
        .filter(
          section: widget.sectionFilter,
          minSeverity: _minSeverityFromActive(),
        )
        .where((entry) {
          return widget.activeSeverities.contains(entry.severity.name);
        });

    // Apply text filter via SmartSearchPlugin for prefix-aware matching
    if (widget.textFilter != null && widget.textFilter!.isNotEmpty) {
      final smartSearch = PluginRegistry.instance
          .getEnabledPlugins<SmartSearchPlugin>()
          .firstOrNull;
      if (smartSearch != null) {
        results = results.where(
          (entry) => smartSearch.matches(entry, widget.textFilter!),
        );
      } else {
        // Fallback to simple text matching
        final lower = widget.textFilter!.toLowerCase();
        results = results.where((entry) {
          final text = entry.text?.toLowerCase() ?? '';
          return text.contains(lower);
        });
      }
    }

    // Time range filter: if active, only show entries in range.
    if (timeRange.isActive) {
      results = results.where((entry) {
        final ts = DateTime.parse(entry.timestamp);
        return timeRange.isInRange(ts);
      });
    }

    // Session filter: if any sessions are selected, only show those
    if (widget.selectedSessionIds.isNotEmpty) {
      results = results.where(
        (entry) => widget.selectedSessionIds.contains(entry.sessionId),
      );
    }

    return results.toList();
  }

  /// Compute minimum severity from the active set (used for coarse filter).
  /// Returns null since we do fine-grained filtering in [_getFilteredEntries].
  Severity? _minSeverityFromActive() => null;

  /// Process entries to compute group depths and filter collapsed groups.
  List<_DisplayEntry> _processGrouping(List<LogEntry> entries) {
    // U01: Pre-scan to find group IDs that have at least one non-group child.
    final groupIdsWithChildren = <String>{};
    {
      final stack = <String>[];
      for (final entry in entries) {
        if (entry.type == LogType.group) {
          if (entry.groupAction == GroupAction.open) {
            stack.add(entry.groupId ?? entry.id);
          } else if (entry.groupAction == GroupAction.close) {
            if (stack.isNotEmpty) stack.removeLast();
          }
        } else if (stack.isNotEmpty) {
          groupIdsWithChildren.add(stack.last);
        }
      }
    }

    final hasTextFilter =
        widget.textFilter != null && widget.textFilter!.isNotEmpty;

    final result = <_DisplayEntry>[];
    int depth = 0;
    final groupStack = <String>[]; // stack of open group IDs
    final stickyGroupIds =
        <String>{}; // groups whose open entry has sticky=true

    for (final entry in entries) {
      // Check if this entry is inside a collapsed group
      bool isHidden = false;
      for (final gid in groupStack) {
        if (_collapsedGroups.contains(gid)) {
          isHidden = true;
          break;
        }
      }

      final parentGroupId = groupStack.isNotEmpty ? groupStack.last : null;

      if (entry.type == LogType.group) {
        if (entry.groupAction == GroupAction.open) {
          final gid = entry.groupId ?? entry.id;
          final isSticky = entry.sticky == true;
          if (isSticky) stickyGroupIds.add(gid);
          final hasChildren = groupIdsWithChildren.contains(gid);

          if (!isHidden) {
            // U01: Skip group-open with no children when text filtering,
            // unless the group-open itself matched (show as standalone).
            if (!hasChildren && hasTextFilter) {
              result.add(
                _DisplayEntry(
                  entry: entry,
                  depth: depth,
                  isSticky: isSticky,
                  parentGroupId: parentGroupId,
                  isStandalone: true,
                ),
              );
            } else {
              result.add(
                _DisplayEntry(
                  entry: entry,
                  depth: depth,
                  isSticky: isSticky,
                  parentGroupId: parentGroupId,
                ),
              );
            }
          }
          groupStack.add(gid);
          depth++;
        } else if (entry.groupAction == GroupAction.close) {
          if (depth > 0) depth--;
          final closedId = groupStack.isNotEmpty
              ? groupStack.removeLast()
              : null;
          if (closedId != null) stickyGroupIds.remove(closedId);

          // U01: Skip group-close for groups with no children when filtering.
          final closeHasChildren =
              closedId != null && groupIdsWithChildren.contains(closedId);
          if (!isHidden && (closeHasChildren || !hasTextFilter)) {
            result.add(
              _DisplayEntry(
                entry: entry,
                depth: depth,
                parentGroupId: parentGroupId,
              ),
            );
          }
        }
      } else {
        if (!isHidden) {
          // Entry is sticky if:
          // 1. It has sticky=true itself
          // 2. It's inside a group that has sticky=true
          final isInStickyGroup = groupStack.any(
            (gid) => stickyGroupIds.contains(gid),
          );
          final isSticky = entry.sticky == true || isInStickyGroup;

          result.add(
            _DisplayEntry(
              entry: entry,
              depth: depth,
              isSticky: isSticky,
              parentGroupId: parentGroupId,
            ),
          );
        }
      }
    }

    return result;
  }

  /// Compute sticky sections from display entries for the pinned overlay.
  ///
  /// Filters by scroll position (S02), dismissed/ignored state (S05),
  /// expanded groups (S03), and mutual exclusion (S04).
  List<StickySection> _computeStickySections(
    List<_DisplayEntry> entries, {
    required int firstVisibleIndex,
    Set<String> dismissedIds = const {},
    Set<String> ignoredGroupIds = const {},
    Set<String> expandedStickyGroups = const {},
    Set<String> collapsedGroups = const {},
  }) {
    final stickyEntries = entries.where((e) => e.isSticky).toList();
    if (stickyEntries.isEmpty) return [];

    // Group sticky entries by their parent group ID
    final grouped = <String?, List<_DisplayEntry>>{};
    for (final entry in stickyEntries) {
      // Skip group-open / group-close entries from direct inclusion;
      // they serve as headers.
      if (entry.entry.type == LogType.group) continue;

      // S05: Skip dismissed entries.
      if (dismissedIds.contains(entry.entry.id)) continue;

      grouped.putIfAbsent(entry.parentGroupId, () => []).add(entry);
    }

    // Also find sticky groups that have no individually-sticky children
    // (the group itself was marked sticky, so all children are sticky)
    for (final entry in stickyEntries) {
      if (entry.entry.type == LogType.group &&
          entry.entry.groupAction == GroupAction.open) {
        final gid = entry.entry.groupId ?? entry.entry.id;
        grouped.putIfAbsent(gid, () => []);
      }
    }

    final sections = <StickySection>[];

    for (final mapEntry in grouped.entries) {
      final parentId = mapEntry.key;
      final stickyChildren = mapEntry.value;

      // S05: Skip ignored groups entirely.
      if (parentId != null && ignoredGroupIds.contains(parentId)) continue;

      LogEntry? groupHeader;
      int hiddenCount = 0;
      int groupDepth = 0;
      int groupHeaderIndex = -1;

      if (parentId != null) {
        // Find the group-open entry for this parent
        for (int i = 0; i < entries.length; i++) {
          final d = entries[i];
          if (d.entry.type == LogType.group &&
              d.entry.groupAction == GroupAction.open &&
              (d.entry.groupId ?? d.entry.id) == parentId) {
            groupHeader = d.entry;
            groupDepth = d.depth;
            groupHeaderIndex = i;
            break;
          }
        }

        // S04: Mutual exclusion — if the group is expanded in the list
        // (not collapsed) AND its header is visible (index >= firstVisibleIndex),
        // exclude it from sticky.
        if (!collapsedGroups.contains(parentId) &&
            groupHeaderIndex >= firstVisibleIndex) {
          continue;
        }

        // Count non-sticky children in this group
        hiddenCount = entries
            .where(
              (d) =>
                  d.parentGroupId == parentId &&
                  !d.isSticky &&
                  d.entry.type != LogType.group,
            )
            .length;
      }

      // S02: Filter out sticky entries whose display index >= firstVisibleIndex
      // (they are still visible on screen, no need to pin).
      final visibleStickyChildren = <_DisplayEntry>[];
      for (final child in stickyChildren) {
        final idx = entries.indexOf(child);
        if (idx < firstVisibleIndex) {
          visibleStickyChildren.add(child);
        }
      }

      // S03: If this group is in expandedStickyGroups, include ALL non-group
      // entries for this group (not just sticky), capped at 10.
      List<LogEntry> sectionEntries;
      if (parentId != null && expandedStickyGroups.contains(parentId)) {
        final allGroupEntries = entries
            .where(
              (d) =>
                  d.parentGroupId == parentId &&
                  d.entry.type != LogType.group &&
                  !dismissedIds.contains(d.entry.id),
            )
            .take(10)
            .map((d) => d.entry)
            .toList();
        sectionEntries = allGroupEntries;
        // When expanded, hidden count is the remainder beyond the cap.
        final totalInGroup = entries
            .where(
              (d) =>
                  d.parentGroupId == parentId &&
                  d.entry.type != LogType.group &&
                  !dismissedIds.contains(d.entry.id),
            )
            .length;
        hiddenCount = totalInGroup > 10 ? totalInGroup - 10 : 0;
      } else {
        sectionEntries = visibleStickyChildren.map((d) => d.entry).toList();
      }

      if (sectionEntries.isNotEmpty || groupHeader != null) {
        sections.add(
          StickySection(
            groupHeader: groupHeader,
            entries: sectionEntries,
            hiddenCount: hiddenCount,
            groupDepth: groupDepth,
          ),
        );
      }
    }

    return sections;
  }

  /// S07: Auto-dismiss entries that arrive with sticky_action: 'unpin'.
  final Set<String> _processedUnpinIds = {};

  void _processUnpinEntries(LogStore logStore, StickyStateService stickyState) {
    final groupsToIgnore = <String>[];
    final idsTooDismiss = <String>[];

    for (final entry in logStore.entries) {
      if (entry.stickyAction == 'unpin' &&
          !_processedUnpinIds.contains(entry.id)) {
        _processedUnpinIds.add(entry.id);
        final groupId = entry.groupId;
        if (groupId != null) {
          groupsToIgnore.add(groupId);
        }
        idsTooDismiss.add(entry.id);
      }
    }

    if (groupsToIgnore.isNotEmpty || idsTooDismiss.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        for (final gid in groupsToIgnore) {
          stickyState.ignore(gid);
        }
        for (final id in idsTooDismiss) {
          stickyState.dismiss(id);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final logStore = context.watch<LogStore>();
    final stickyState = context.watch<StickyStateService>();
    final timeRange = context.watch<TimeRangeService>();

    // S07: Process unpin entries — auto-dismiss matching sticky entries.
    _processUnpinEntries(logStore, stickyState);

    // Only recompute filtered entries when inputs actually changed.
    final storeVersion = logStore.version;
    final timeRangeActive = timeRange.isActive;
    final timeRangeStart = timeRange.rangeStart;
    final timeRangeEnd = timeRange.rangeEnd;
    if (_cachedFilteredEntries == null ||
        storeVersion != _cachedLogStoreVersion ||
        widget.sectionFilter != _cachedSectionFilter ||
        widget.textFilter != _cachedTextFilter ||
        !setEquals(widget.activeSeverities, _cachedActiveSeverities) ||
        !setEquals(widget.selectedSessionIds, _cachedSessionIds) ||
        timeRangeActive != _cachedTimeRangeActive ||
        timeRangeStart != _cachedTimeRangeStart ||
        timeRangeEnd != _cachedTimeRangeEnd) {
      _cachedFilteredEntries = _getFilteredEntries(logStore);
      _cachedLogStoreVersion = storeVersion;
      _cachedSectionFilter = widget.sectionFilter;
      _cachedTextFilter = widget.textFilter;
      _cachedActiveSeverities = widget.activeSeverities;
      _cachedSessionIds = widget.selectedSessionIds;
      _cachedTimeRangeActive = timeRangeActive;
      _cachedTimeRangeStart = timeRangeStart;
      _cachedTimeRangeEnd = timeRangeEnd;
    }

    final filteredEntries = _cachedFilteredEntries!;
    final displayEntries = _processGrouping(filteredEntries);

    // S02: In live mode the user is at the bottom — all entries are
    // "scrolled past", so all stickies should show.
    final effectiveFirstVisible = _isLiveMode
        ? displayEntries.length
        : _firstVisibleIndex;

    final stickySections = _computeStickySections(
      displayEntries,
      firstVisibleIndex: effectiveFirstVisible,
      dismissedIds: stickyState.dismissedIds,
      ignoredGroupIds: stickyState.ignoredGroupIds,
      expandedStickyGroups: _expandedStickyGroups,
      collapsedGroups: _collapsedGroups,
    );

    // Detect new arrivals for live mode / new-log counter.
    if (displayEntries.length > _lastEntryCount) {
      final addedCount = displayEntries.length - _lastEntryCount;
      if (!_isLiveMode) {
        _newLogCount += addedCount;
      }
    }
    _lastEntryCount = displayEntries.length;

    // In live mode, auto-scroll after frame.
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
        // S01: Listener forwards pointer scroll events to ListView's
        // ScrollController so scrolling over the sticky header scrolls
        // the list underneath.
        Listener(
          onPointerSignal: (event) {
            if (event is PointerScrollEvent && _scrollController.hasClients) {
              final altHeld =
                  HardwareKeyboard.instance.logicalKeysPressed.contains(
                    LogicalKeyboardKey.altLeft,
                  ) ||
                  HardwareKeyboard.instance.logicalKeysPressed.contains(
                    LogicalKeyboardKey.altRight,
                  );

              if (altHeld) {
                // Alt+Scroll: snap to 28dp line increments.
                final lines = event.scrollDelta.dy.sign.toInt();
                final target =
                    (_scrollController.offset + lines * _estimatedRowHeight)
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
                final newOffset = (pos.pixels + event.scrollDelta.dy).clamp(
                  pos.minScrollExtent,
                  pos.maxScrollExtent,
                );
                _scrollController.jumpTo(newOffset);
              }
            }
          },
          child: Column(
            children: [
              // Sticky pinned header
              if (stickySections.isNotEmpty)
                StickyHeaderOverlay(
                  sections: stickySections,
                  onHiddenTap: _onHiddenTap,
                  stickyState: stickyState,
                ),
              // Main scrollable list
              Expanded(
                child: Container(
                  color: LoggerColors.bgSurface,
                  child: SelectionArea(
                    child: ListView.builder(
                      controller: _scrollController,
                      physics: const ClampingScrollPhysics(),
                      itemCount: displayEntries.length,
                      itemBuilder: (context, index) {
                        final display = displayEntries[index];
                        final entry = display.entry;
                        final isNew = !_seenEntryIds.contains(entry.id);

                        // Mark seen after building.
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
                          isSelectionSelected: widget.selectedEntryIds.contains(
                            entry.id,
                          ),
                          onSelect: () {
                            widget.onEntrySelected?.call(entry.id);
                          },
                          groupDepth: display.depth,
                          onTap: () {
                            setState(() {
                              _selectedIndex = _selectedIndex == index
                                  ? -1
                                  : index;
                            });
                          },
                          // U01: Don't make standalone groups expandable.
                          onGroupToggle:
                              entry.type == LogType.group &&
                                  entry.groupAction == GroupAction.open &&
                                  !display.isStandalone
                              ? () {
                                  setState(() {
                                    final gid = entry.groupId ?? entry.id;
                                    if (_collapsedGroups.contains(gid)) {
                                      _collapsedGroups.remove(gid);
                                    } else {
                                      _collapsedGroups.add(gid);
                                    }
                                  });
                                }
                              : null,
                          isCollapsed:
                              entry.type == LogType.group &&
                              entry.groupAction == GroupAction.open &&
                              !display.isStandalone &&
                              _collapsedGroups.contains(
                                entry.groupId ?? entry.id,
                              ),
                        );
                      },
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
}

class _DisplayEntry {
  final LogEntry entry;
  final int depth;
  final bool isSticky;
  final String? parentGroupId;

  /// U01: True when this group-open has no visible children (text filtering).
  final bool isStandalone;

  const _DisplayEntry({
    required this.entry,
    required this.depth,
    this.isSticky = false,
    this.parentGroupId,
    this.isStandalone = false,
  });
}
