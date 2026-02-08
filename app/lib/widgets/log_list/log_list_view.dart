import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/log_entry.dart';
import '../../services/log_store.dart';
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

  /// The last known entry count — used to detect new arrivals.
  int _lastEntryCount = 0;

  /// Cached filtered entries to avoid recomputation when filters haven't changed.
  List<LogEntry>? _cachedFilteredEntries;
  int _cachedLogStoreVersion = -1;
  String? _cachedSectionFilter;
  String? _cachedTextFilter;
  Set<String> _cachedActiveSeverities = const {};
  Set<String> _cachedSessionIds = const {};

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

  List<LogEntry> _getFilteredEntries(LogStore logStore) {
    var results = logStore
        .filter(
          section: widget.sectionFilter,
          minSeverity: _minSeverityFromActive(),
          textSearch: widget.textFilter,
        )
        .where((entry) {
          return widget.activeSeverities.contains(entry.severity.name);
        });

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

          if (!isHidden) {
            result.add(
              _DisplayEntry(
                entry: entry,
                depth: depth,
                isSticky: isSticky,
                parentGroupId: parentGroupId,
              ),
            );
          }
          groupStack.add(gid);
          depth++;
        } else if (entry.groupAction == GroupAction.close) {
          if (depth > 0) depth--;
          if (groupStack.isNotEmpty) {
            final closedId = groupStack.removeLast();
            stickyGroupIds.remove(closedId);
          }
          if (!isHidden) {
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
  List<StickySection> _computeStickySections(List<_DisplayEntry> entries) {
    final stickyEntries = entries.where((e) => e.isSticky).toList();
    if (stickyEntries.isEmpty) return [];

    // Group sticky entries by their parent group ID
    final grouped = <String?, List<_DisplayEntry>>{};
    for (final entry in stickyEntries) {
      // Skip group-open / group-close entries from direct inclusion;
      // they serve as headers.
      if (entry.entry.type == LogType.group) continue;
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

      LogEntry? groupHeader;
      int hiddenCount = 0;
      int groupDepth = 0;

      if (parentId != null) {
        // Find the group-open entry for this parent
        final headerDisplay = entries.where(
          (d) =>
              d.entry.type == LogType.group &&
              d.entry.groupAction == GroupAction.open &&
              (d.entry.groupId ?? d.entry.id) == parentId,
        );
        if (headerDisplay.isNotEmpty) {
          groupHeader = headerDisplay.first.entry;
          groupDepth = headerDisplay.first.depth;
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

      if (stickyChildren.isNotEmpty || groupHeader != null) {
        sections.add(
          StickySection(
            groupHeader: groupHeader,
            entries: stickyChildren.map((d) => d.entry).toList(),
            hiddenCount: hiddenCount,
            groupDepth: groupDepth,
          ),
        );
      }
    }

    return sections;
  }

  @override
  Widget build(BuildContext context) {
    final logStore = context.watch<LogStore>();

    // Only recompute filtered entries when inputs actually changed.
    final storeVersion = logStore.version;
    if (_cachedFilteredEntries == null ||
        storeVersion != _cachedLogStoreVersion ||
        widget.sectionFilter != _cachedSectionFilter ||
        widget.textFilter != _cachedTextFilter ||
        !setEquals(widget.activeSeverities, _cachedActiveSeverities) ||
        !setEquals(widget.selectedSessionIds, _cachedSessionIds)) {
      _cachedFilteredEntries = _getFilteredEntries(logStore);
      _cachedLogStoreVersion = storeVersion;
      _cachedSectionFilter = widget.sectionFilter;
      _cachedTextFilter = widget.textFilter;
      _cachedActiveSeverities = widget.activeSeverities;
      _cachedSessionIds = widget.selectedSessionIds;
    }

    final filteredEntries = _cachedFilteredEntries!;
    final displayEntries = _processGrouping(filteredEntries);
    final stickySections = _computeStickySections(displayEntries);

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
        Column(
          children: [
            // Sticky pinned header
            if (stickySections.isNotEmpty)
              StickyEntriesHeader(sections: stickySections),
            // Main scrollable list
            Expanded(
              child: Container(
                color: LoggerColors.bgSurface,
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
                      groupDepth: display.depth,
                      onTap: () {
                        setState(() {
                          _selectedIndex = _selectedIndex == index ? -1 : index;
                        });
                      },
                      onGroupToggle:
                          entry.type == LogType.group &&
                              entry.groupAction == GroupAction.open
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
                          _collapsedGroups.contains(entry.groupId ?? entry.id),
                    );
                  },
                ),
              ),
            ),
          ],
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

  const _DisplayEntry({
    required this.entry,
    required this.depth,
    this.isSticky = false,
    this.parentGroupId,
  });
}
