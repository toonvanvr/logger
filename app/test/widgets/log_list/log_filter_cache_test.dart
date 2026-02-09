import 'package:app/models/log_entry.dart';
import 'package:app/services/log_store.dart';
import 'package:app/services/time_range_service.dart';
import 'package:app/widgets/log_list/log_filter_cache.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_helpers.dart';

LogEntry _makeEntry({
  required String id,
  EntryKind kind = EntryKind.event,
  Severity severity = Severity.info,
  String? message,
  String? key,
  dynamic value,
}) {
  return makeTestEntry(
    id: id,
    kind: kind,
    severity: severity,
    message: message,
    key: key,
    value: value,
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

    test('excludes data entries from filtered results', () {
      store.addEntries([
        _makeEntry(id: '1', kind: EntryKind.event, message: 'hello'),
        _makeEntry(
          id: '2',
          kind: EntryKind.data,
          key: 'cpu',
          value: '42%',
        ),
        _makeEntry(id: '3', kind: EntryKind.event, message: 'world'),
        _makeEntry(
          id: '4',
          kind: EntryKind.data,
          key: 'mem',
          value: '1GB',
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

    test('keeps event entries with key set', () {
      store.addEntries([
        _makeEntry(
          id: '1',
          kind: EntryKind.event,
          message: 'setting cpu',
          key: 'cpu',
        ),
        _makeEntry(
          id: '2',
          kind: EntryKind.data,
          key: 'cpu',
          value: '42%',
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

    test('returns empty list when all entries are data kind', () {
      store.addEntries([
        _makeEntry(id: '1', kind: EntryKind.data, key: 'a'),
        _makeEntry(id: '2', kind: EntryKind.data, key: 'b'),
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

    test('state: prefix filter returns matching data entries', () {
      store.addEntries([
        _makeEntry(id: '1', kind: EntryKind.event, message: 'hello'),
        _makeEntry(
          id: '2',
          kind: EntryKind.data,
          key: 'cpu',
          value: '42%',
        ),
        _makeEntry(id: '3', kind: EntryKind.event, message: 'world'),
        _makeEntry(
          id: '4',
          kind: EntryKind.data,
          key: 'mem',
          value: '1GB',
        ),
      ]);

      final result = cache.getFiltered(
        logStore: store,
        timeRange: timeRange,
        sectionFilter: null,
        textFilter: 'state:cpu',
        activeSeverities: {'info'},
        selectedSessionIds: {},
      );

      expect(result.length, 1);
      expect(result.first.id, '2');
      expect(result.first.key, 'cpu');
    });

    test('state: prefix with unknown key returns empty', () {
      store.addEntries([
        _makeEntry(
          id: '1',
          kind: EntryKind.data,
          key: 'cpu',
          value: '42%',
        ),
      ]);

      final result = cache.getFiltered(
        logStore: store,
        timeRange: timeRange,
        sectionFilter: null,
        textFilter: 'state:nonexistent',
        activeSeverities: {'info'},
        selectedSessionIds: {},
      );

      expect(result, isEmpty);
    });
  });
}
