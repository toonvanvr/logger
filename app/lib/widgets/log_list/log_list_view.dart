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

  /// Set of active severity names for filtering.
  final Set<String> activeSeverities;

  const LogListView({
    super.key,
    this.sectionFilter,
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
    return logStore
        .filter(
          section: widget.sectionFilter,
          minSeverity: _minSeverityFromActive(),
        )
        .where((entry) {
          return widget.activeSeverities.contains(entry.severity.name);
        })
        .toList();
  }

  /// Compute minimum severity from the active set (used for coarse filter).
  /// Returns null since we do fine-grained filtering in [_getFilteredEntries].
  Severity? _minSeverityFromActive() => null;

  @override
  Widget build(BuildContext context) {
    final logStore = context.watch<LogStore>();
    final entries = _getFilteredEntries(logStore);

    // Detect new arrivals for live mode / new-log counter.
    if (entries.length > _lastEntryCount) {
      final addedCount = entries.length - _lastEntryCount;
      if (!_isLiveMode) {
        _newLogCount += addedCount;
      }
    }
    _lastEntryCount = entries.length;

    // In live mode, auto-scroll after frame.
    if (_isLiveMode && entries.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
      });
    }

    if (entries.isEmpty) {
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
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries[index];
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
                onTap: () {
                  setState(() {
                    _selectedIndex = _selectedIndex == index ? -1 : index;
                  });
                },
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
