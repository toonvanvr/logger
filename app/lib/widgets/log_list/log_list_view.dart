import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/log_entry.dart';
import '../../services/log_store.dart';
import '../../theme/colors.dart';
import '../../theme/typography.dart';
import 'live_pill.dart';
import 'log_row.dart';

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

    for (final entry in entries) {
      // Check if this entry is inside a collapsed group
      bool isHidden = false;
      for (final gid in groupStack) {
        if (_collapsedGroups.contains(gid)) {
          isHidden = true;
          break;
        }
      }

      if (entry.type == LogType.group) {
        if (entry.groupAction == GroupAction.open) {
          if (!isHidden) {
            result.add(_DisplayEntry(entry: entry, depth: depth));
          }
          groupStack.add(entry.groupId ?? entry.id);
          depth++;
        } else if (entry.groupAction == GroupAction.close) {
          if (depth > 0) depth--;
          if (groupStack.isNotEmpty) groupStack.removeLast();
          if (!isHidden) {
            result.add(_DisplayEntry(entry: entry, depth: depth));
          }
        }
      } else {
        if (!isHidden) {
          result.add(_DisplayEntry(entry: entry, depth: depth));
        }
      }
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final logStore = context.watch<LogStore>();
    final filteredEntries = _getFilteredEntries(logStore);
    final displayEntries = _processGrouping(filteredEntries);

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
        Container(
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

  const _DisplayEntry({required this.entry, required this.depth});
}
