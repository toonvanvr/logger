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
  String? _sectionFilter;
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
    required String? sectionFilter,
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
        sectionFilter == _sectionFilter &&
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
      sectionFilter: sectionFilter,
      textFilter: textFilter,
      activeSeverities: activeSeverities,
      selectedSessionIds: selectedSessionIds,
    );
    _storeVersion = version;
    _sectionFilter = sectionFilter;
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
    required String? sectionFilter,
    required String? textFilter,
    required Set<String> activeSeverities,
    required Set<String> selectedSessionIds,
  }) {
    var results = logStore
        .filter(section: sectionFilter)
        .where((e) => e.stickyAction != 'unpin')
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
        (e) => e.type == LogType.state && stateKeys.contains(e.stateKey),
      );
      if (remainingFilter != null && remainingFilter.isNotEmpty) {
        final lower = remainingFilter.toLowerCase();
        results = results.where((e) {
          final text = e.text?.toLowerCase() ?? '';
          return text.contains(lower);
        });
      }
    } else {
      results = results.where((e) => e.type != LogType.state);
      if (textFilter != null && textFilter.isNotEmpty) {
        final smartSearch = PluginRegistry.instance
            .getEnabledPlugins<SmartSearchPlugin>()
            .firstOrNull;
        if (smartSearch != null) {
          results = results.where((e) => smartSearch.matches(e, textFilter));
        } else {
          final lower = textFilter.toLowerCase();
          results = results.where((e) {
            final text = e.text?.toLowerCase() ?? '';
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

    return results.toList();
  }
}
