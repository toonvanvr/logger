import 'package:app/models/log_entry.dart';
import 'package:app/services/log_store.dart';
import 'package:flutter_test/flutter_test.dart';

LogEntry _makeEntry({
  String id = 'e1',
  String sessionId = 'sess-1',
  Severity severity = Severity.info,
  LogType type = LogType.text,
  String? text,
  String? section,
  String? stateKey,
  dynamic stateValue,
  bool? replace,
}) {
  return LogEntry(
    id: id,
    timestamp: '2026-02-07T12:00:00Z',
    sessionId: sessionId,
    severity: severity,
    type: type,
    text: text,
    section: section,
    stateKey: stateKey,
    stateValue: stateValue,
    replace: replace,
  );
}

void main() {
  group('LogStore', () {
    late LogStore store;

    setUp(() {
      store = LogStore();
    });

    // ── Test 1: addEntry stores entry and increments length ──

    test('addEntry stores entry and increments length', () {
      final entry = _makeEntry();
      store.addEntry(entry);

      expect(store.length, 1);
      expect(store.entries.first.id, 'e1');
    });

    // ── Test 2: addEntry calls notifyListeners ──

    test('addEntry calls notifyListeners', () {
      var notified = false;
      store.addListener(() => notified = true);

      store.addEntry(_makeEntry());

      expect(notified, isTrue);
    });

    // ── Test 3: addEntry upserts when replace=true and id exists ──

    test('addEntry upserts when replace=true and id exists', () {
      store.addEntry(_makeEntry(id: 'e1', text: 'original'));
      store.addEntry(_makeEntry(id: 'e1', text: 'updated', replace: true));

      expect(store.length, 1);
      expect(store.entries.first.text, 'updated');
    });

    // ── Test 4: addEntries batch adds multiple entries ──

    test('addEntries batch adds multiple entries', () {
      store.addEntries([
        _makeEntry(id: 'e1'),
        _makeEntry(id: 'e2'),
        _makeEntry(id: 'e3'),
      ]);

      expect(store.length, 3);
    });

    // ── Test 5: addEntries handles mix of new + replace entries ──

    test('addEntries handles mix of new and replace entries', () {
      store.addEntry(_makeEntry(id: 'e1', text: 'original'));

      store.addEntries([
        _makeEntry(id: 'e1', text: 'replaced', replace: true),
        _makeEntry(id: 'e2', text: 'new'),
      ]);

      expect(store.length, 2);
      expect(store.entries[0].text, 'replaced');
      expect(store.entries[1].text, 'new');
    });

    // ── Test 6: addEntries calls notifyListeners once per batch ──

    test('addEntries calls notifyListeners once per batch', () {
      var notifyCount = 0;
      store.addListener(() => notifyCount++);

      store.addEntries([_makeEntry(id: 'e1'), _makeEntry(id: 'e2')]);

      expect(notifyCount, 1);
    });

    // ── Test 7: state tracking — stateKey + stateValue stored per session ──

    test('state tracking stores stateKey and stateValue per session', () {
      store.addEntry(
        _makeEntry(
          id: 'e1',
          type: LogType.state,
          stateKey: 'theme',
          stateValue: 'dark',
        ),
      );

      expect(store.getState('sess-1'), {'theme': 'dark'});
    });

    // ── Test 8: state tracking — null stateValue removes key ──

    test('state tracking removes key when stateValue is null', () {
      store.addEntry(
        _makeEntry(
          id: 'e1',
          type: LogType.state,
          stateKey: 'theme',
          stateValue: 'dark',
        ),
      );
      store.addEntry(
        _makeEntry(
          id: 'e2',
          type: LogType.state,
          stateKey: 'theme',
          stateValue: null,
        ),
      );

      expect(store.getState('sess-1').containsKey('theme'), isFalse);
    });

    // ── Test 9: filter by sessionId ──

    test('filter by sessionId', () {
      store.addEntries([
        _makeEntry(id: 'e1', sessionId: 'sess-1'),
        _makeEntry(id: 'e2', sessionId: 'sess-2'),
        _makeEntry(id: 'e3', sessionId: 'sess-1'),
      ]);

      final result = store.filter(sessionId: 'sess-1');
      expect(result.length, 2);
      expect(result.every((e) => e.sessionId == 'sess-1'), isTrue);
    });

    // ── Test 10: filter by minSeverity ──

    test('filter by minSeverity', () {
      store.addEntries([
        _makeEntry(id: 'e1', severity: Severity.debug),
        _makeEntry(id: 'e2', severity: Severity.info),
        _makeEntry(id: 'e3', severity: Severity.warning),
        _makeEntry(id: 'e4', severity: Severity.error),
      ]);

      final result = store.filter(minSeverity: Severity.warning);
      expect(result.length, 2);
      expect(result[0].severity, Severity.warning);
      expect(result[1].severity, Severity.error);
    });

    // ── Test 11: filter by section ──

    test('filter by section', () {
      store.addEntries([
        _makeEntry(id: 'e1', section: 'network'),
        _makeEntry(id: 'e2', section: 'ui'),
        _makeEntry(id: 'e3', section: 'network'),
      ]);

      final result = store.filter(section: 'network');
      expect(result.length, 2);
      expect(result.every((e) => e.section == 'network'), isTrue);
    });

    // ── Test 12: filter by textSearch (case-insensitive) ──

    test('filter by textSearch is case-insensitive', () {
      store.addEntries([
        _makeEntry(id: 'e1', text: 'Hello World'),
        _makeEntry(id: 'e2', text: 'goodbye world'),
        _makeEntry(id: 'e3', text: 'no match'),
      ]);

      final result = store.filter(textSearch: 'WORLD');
      expect(result.length, 2);
    });

    // ── Test 13: filter combined criteria ──

    test('filter combined criteria', () {
      store.addEntries([
        _makeEntry(
          id: 'e1',
          sessionId: 'sess-1',
          severity: Severity.error,
          section: 'network',
          text: 'timeout error',
        ),
        _makeEntry(
          id: 'e2',
          sessionId: 'sess-1',
          severity: Severity.debug,
          section: 'network',
          text: 'debug trace',
        ),
        _makeEntry(
          id: 'e3',
          sessionId: 'sess-2',
          severity: Severity.error,
          section: 'ui',
          text: 'render error',
        ),
      ]);

      final result = store.filter(
        sessionId: 'sess-1',
        minSeverity: Severity.error,
        section: 'network',
        textSearch: 'timeout',
      );
      expect(result.length, 1);
      expect(result.first.id, 'e1');
    });

    // ── Test 14: clear removes all entries and state ──

    test('clear removes all entries and state', () {
      store.addEntry(
        _makeEntry(
          id: 'e1',
          type: LogType.state,
          stateKey: 'k',
          stateValue: 'v',
        ),
      );
      store.clear();

      expect(store.length, 0);
      expect(store.entries, isEmpty);
      expect(store.getState('sess-1'), isEmpty);
    });

    // ── Test 15: getState returns session state map ──

    test('getState returns session state map', () {
      store.addEntry(
        _makeEntry(
          id: 'e1',
          type: LogType.state,
          stateKey: 'count',
          stateValue: 42,
        ),
      );
      store.addEntry(
        _makeEntry(
          id: 'e2',
          type: LogType.state,
          stateKey: 'name',
          stateValue: 'test',
        ),
      );

      final state = store.getState('sess-1');
      expect(state, {'count': 42, 'name': 'test'});
    });

    test('getState returns empty map for unknown session', () {
      expect(store.getState('unknown'), isEmpty);
    });
  });
}
