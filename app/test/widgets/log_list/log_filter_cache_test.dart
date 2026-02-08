import 'package:app/models/log_entry.dart';
import 'package:app/services/log_store.dart';
import 'package:app/services/time_range_service.dart';
import 'package:app/widgets/log_list/log_filter_cache.dart';
import 'package:flutter_test/flutter_test.dart';

LogEntry _makeEntry({
  required String id,
  LogType type = LogType.text,
  Severity severity = Severity.info,
  String? text,
  String? stateKey,
  dynamic stateValue,
}) {
  return LogEntry(
    id: id,
    timestamp: '2026-01-01T00:00:00Z',
    sessionId: 's1',
    severity: severity,
    type: type,
    text: text,
    stateKey: stateKey,
    stateValue: stateValue,
  );
}

void main() {
  group('LogFilterCache state-type exclusion', () {
    late LogStore store;
    late TimeRangeService timeRange;
    late LogFilterCache cache;

    setUp(() {
      store = LogStore();
      timeRange = TimeRangeService();
      cache = LogFilterCache();
    });

    test('excludes LogType.state entries from filtered results', () {
      store.addEntries([
        _makeEntry(id: '1', type: LogType.text, text: 'hello'),
        _makeEntry(
          id: '2',
          type: LogType.state,
          stateKey: 'cpu',
          stateValue: '42%',
        ),
        _makeEntry(id: '3', type: LogType.text, text: 'world'),
        _makeEntry(
          id: '4',
          type: LogType.state,
          stateKey: 'mem',
          stateValue: '1GB',
        ),
      ]);

      final result = cache.getFiltered(
        logStore: store,
        timeRange: timeRange,
        sectionFilter: null,
        textFilter: null,
        activeSeverities: {'info'},
        selectedSessionIds: {},
      );

      expect(result.length, 2);
      expect(result.map((e) => e.id).toList(), ['1', '3']);
    });

    test('keeps entries with stateKey but non-state type', () {
      store.addEntries([
        _makeEntry(
          id: '1',
          type: LogType.text,
          text: 'setting cpu',
          stateKey: 'cpu',
        ),
        _makeEntry(
          id: '2',
          type: LogType.state,
          stateKey: 'cpu',
          stateValue: '42%',
        ),
      ]);

      final result = cache.getFiltered(
        logStore: store,
        timeRange: timeRange,
        sectionFilter: null,
        textFilter: null,
        activeSeverities: {'info'},
        selectedSessionIds: {},
      );

      expect(result.length, 1);
      expect(result.first.id, '1');
    });

    test('returns empty list when all entries are state type', () {
      store.addEntries([
        _makeEntry(id: '1', type: LogType.state, stateKey: 'a'),
        _makeEntry(id: '2', type: LogType.state, stateKey: 'b'),
      ]);

      final result = cache.getFiltered(
        logStore: store,
        timeRange: timeRange,
        sectionFilter: null,
        textFilter: null,
        activeSeverities: {'info'},
        selectedSessionIds: {},
      );

      expect(result, isEmpty);
    });
  });
}
