import 'package:flutter/foundation.dart' show setEquals;

import '../../models/log_entry.dart';
import '../../plugins/builtin/smart_search_plugin.dart';
import '../../plugins/plugin_registry.dart';
import '../../services/log_store.dart';
import '../../services/time_range_service.dart';

/// Caches filtered log entries and recomputes only when inputs change.
class LogFilterCache {
  List<LogEntry>? _cached;
  int _storeVersion = -1;
  String? _tagFilter;
  String? _textFilter;
  Set<String> _activeSeverities = const {};
  Set<String> _sessionIds = const {};
  bool _timeRangeActive = false;
  DateTime? _timeRangeStart;
  DateTime? _timeRangeEnd;

  /// Returns cached filtered entries or recomputes if inputs changed.
  List<LogEntry> getFiltered({
    required LogStore logStore,
    required TimeRangeService timeRange,
    required String? tagFilter,
    required String? textFilter,
    required Set<String> activeSeverities,
    required Set<String> selectedSessionIds,
  }) {
    final version = logStore.version;
    final trActive = timeRange.isActive;
    final trStart = timeRange.rangeStart;
    final trEnd = timeRange.rangeEnd;

    if (_cached != null &&
        version == _storeVersion &&
        tagFilter == _tagFilter &&
        textFilter == _textFilter &&
        setEquals(activeSeverities, _activeSeverities) &&
        setEquals(selectedSessionIds, _sessionIds) &&
        trActive == _timeRangeActive &&
        trStart == _timeRangeStart &&
        trEnd == _timeRangeEnd) {
      return _cached!;
    }

    _cached = _computeFiltered(
      logStore: logStore,
      timeRange: timeRange,
      tagFilter: tagFilter,
      textFilter: textFilter,
      activeSeverities: activeSeverities,
      selectedSessionIds: selectedSessionIds,
    );
    _storeVersion = version;
    _tagFilter = tagFilter;
    _textFilter = textFilter;
    _activeSeverities = activeSeverities;
    _sessionIds = selectedSessionIds;
    _timeRangeActive = trActive;
    _timeRangeStart = trStart;
    _timeRangeEnd = trEnd;
    return _cached!;
  }

  static List<LogEntry> _computeFiltered({
    required LogStore logStore,
    required TimeRangeService timeRange,
    required String? tagFilter,
    required String? textFilter,
    required Set<String> activeSeverities,
    required Set<String> selectedSessionIds,
  }) {
    var results = logStore
        .filter(tag: tagFilter)
        .where((e) => activeSeverities.contains(e.severity.name));

    // Text filter via SmartSearchPlugin for prefix-aware matching.
    // When filtering by state: prefix, include state entries; otherwise exclude them.
    final stateKeys = <String>{};
    String? remainingFilter;
    if (textFilter != null && textFilter.contains('state:')) {
      final tokens = textFilter.split(' ');
      for (final token in tokens) {
        if (token.startsWith('state:')) {
          stateKeys.add(token.substring(6));
        }
      }
      remainingFilter = tokens
          .where((t) => !t.startsWith('state:'))
          .join(' ')
          .trim();
    }

    if (stateKeys.isNotEmpty) {
      results = results.where(
        (e) => e.kind == EntryKind.data && stateKeys.contains(e.key),
      );
      if (remainingFilter != null && remainingFilter.isNotEmpty) {
        final lower = remainingFilter.toLowerCase();
        results = results.where((e) {
          final text = e.message?.toLowerCase() ?? '';
          return text.contains(lower);
        });
      }
    } else {
      results = results.where((e) => e.kind != EntryKind.data);
      if (textFilter != null && textFilter.isNotEmpty) {
        final smartSearch = PluginRegistry.instance
            .getEnabledPlugins<SmartSearchPlugin>()
            .firstOrNull;
        if (smartSearch != null) {
          results = results.where((e) => smartSearch.matches(e, textFilter));
        } else {
          final lower = textFilter.toLowerCase();
          results = results.where((e) {
            final text = e.message?.toLowerCase() ?? '';
            return text.contains(lower);
          });
        }
      }
    }

    // Time range filter.
    if (timeRange.isActive) {
      results = results.where((e) {
        final ts = DateTime.parse(e.timestamp);
        return timeRange.isInRange(ts);
      });
    }

    // Session filter.
    if (selectedSessionIds.isNotEmpty) {
      results = results.where((e) => selectedSessionIds.contains(e.sessionId));
    }

    final resultList = results.toList();

    // Group-aware: include ancestor group headers for matched children.
    // When text search matches child entries, their group headers would be
    // dropped. This pass walks ancestor chains and re-inserts them.
    if (textFilter != null && textFilter.isNotEmpty && stateKeys.isEmpty) {
      final resultIds = <String>{for (final e in resultList) e.id};
      final neededGroupIds = <String>{};

      for (final e in resultList) {
        if (e.groupId != null && !resultIds.contains(e.groupId)) {
          neededGroupIds.add(e.groupId!);
        }
      }

      if (neededGroupIds.isNotEmpty) {
        // Build lookup from the full tag-filtered entry list.
        final allEntries = logStore
            .filter(tag: tagFilter)
            .where((e) => activeSeverities.contains(e.severity.name))
            .where((e) => e.kind != EntryKind.data)
            .toList();
        final idToEntry = <String, LogEntry>{
          for (final e in allEntries) e.id: e,
        };

        // Walk ancestor chains to collect all missing headers.
        final toAdd = <String>{};
        for (final gid in neededGroupIds) {
          var current = gid;
          while (idToEntry.containsKey(current) &&
              !resultIds.contains(current)) {
            toAdd.add(current);
            final parent = idToEntry[current]!;
            current = (parent.groupId != null && parent.groupId != parent.id)
                ? parent.groupId!
                : '';
          }
        }

        // Insert group headers preserving original order, then deduplicate.
        if (toAdd.isNotEmpty) {
          final extras =
              allEntries.where((e) => toAdd.contains(e.id)).toList();
          resultList.insertAll(0, extras);
          final seen = <String>{};
          resultList.retainWhere((e) => seen.add(e.id));
        }
      }
    }

    return resultList;
  }
}
