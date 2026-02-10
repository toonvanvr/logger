import 'package:app/models/log_entry.dart';
import 'package:app/services/log_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_helpers.dart';

LogEntry _makeEntry({
  String id = 'e1',
  String sessionId = 'sess-1',
  Severity severity = Severity.info,
  EntryKind kind = EntryKind.event,
  String? message,
  String? tag,
  String? key,
  dynamic value,
  bool replace = false,
}) {
  return makeTestEntry(
    id: id,
    sessionId: sessionId,
    severity: severity,
    kind: kind,
    message: message,
    tag: tag,
    key: key,
    value: value,
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
      store.addEntry(_makeEntry(id: 'e1', message: 'original'));
      store.addEntry(_makeEntry(id: 'e1', message: 'updated', replace: true));

      expect(store.length, 1);
      expect(store.entries.first.message, 'updated');
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
      store.addEntry(_makeEntry(id: 'e1', message: 'original'));

      store.addEntries([
        _makeEntry(id: 'e1', message: 'replaced', replace: true),
        _makeEntry(id: 'e2', message: 'new'),
      ]);

      expect(store.length, 2);
      expect(store.entries[0].message, 'replaced');
      expect(store.entries[1].message, 'new');
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
        _makeEntry(id: 'e1', kind: EntryKind.data, key: 'theme', value: 'dark'),
      );

      expect(store.getState('sess-1'), {'theme': 'dark'});
    });

    // ── Test 8: state tracking — null value removes key ──

    test('state tracking removes key when value is null', () {
      store.addEntry(
        _makeEntry(id: 'e1', kind: EntryKind.data, key: 'theme', value: 'dark'),
      );
      store.addEntry(
        _makeEntry(id: 'e2', kind: EntryKind.data, key: 'theme', value: null),
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

      final result = store.filter(sessionIds: {'sess-1'});
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
        _makeEntry(id: 'e1', tag: 'network'),
        _makeEntry(id: 'e2', tag: 'ui'),
        _makeEntry(id: 'e3', tag: 'network'),
      ]);

      final result = store.filter(tag: 'network');
      expect(result.length, 2);
      expect(result.every((e) => e.tag == 'network'), isTrue);
    });

    // ── Test 12: filter by textSearch (case-insensitive) ──

    test('filter by textSearch is case-insensitive', () {
      store.addEntries([
        _makeEntry(id: 'e1', message: 'Hello World'),
        _makeEntry(id: 'e2', message: 'goodbye world'),
        _makeEntry(id: 'e3', message: 'no match'),
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
          tag: 'network',
          message: 'timeout error',
        ),
        _makeEntry(
          id: 'e2',
          sessionId: 'sess-1',
          severity: Severity.debug,
          tag: 'network',
          message: 'debug trace',
        ),
        _makeEntry(
          id: 'e3',
          sessionId: 'sess-2',
          severity: Severity.error,
          tag: 'ui',
          message: 'render error',
        ),
      ]);

      final result = store.filter(
        sessionIds: {'sess-1'},
        minSeverity: Severity.error,
        tag: 'network',
        textSearch: 'timeout',
      );
      expect(result.length, 1);
      expect(result.first.id, 'e1');
    });

    // ── Test 14: clear removes all entries and state ──

    test('clear removes all entries and state', () {
      store.addEntry(
        _makeEntry(id: 'e1', kind: EntryKind.data, key: 'k', value: 'v'),
      );
      store.clear();

      expect(store.length, 0);
      expect(store.entries, isEmpty);
      expect(store.getState('sess-1'), isEmpty);
    });

    // ── Test 15: getState returns session state map ──

    test('getState returns session state map', () {
      store.addEntry(
        _makeEntry(id: 'e1', kind: EntryKind.data, key: 'count', value: 42),
      );
      store.addEntry(
        _makeEntry(id: 'e2', kind: EntryKind.data, key: 'name', value: 'test'),
      );

      final state = store.getState('sess-1');
      expect(state, {'count': 42, 'name': 'test'});
    });

    test('getState returns empty map for unknown session', () {
      expect(store.getState('unknown'), isEmpty);
    });

    // ── Eviction tests ──

    group('entry cap eviction', () {
      test('entries below cap are not evicted', () {
        final entries = List.generate(100, (i) => _makeEntry(id: 'e$i'));
        store.addEntries(entries);

        expect(store.length, 100);
        expect(store.entries.first.id, 'e0');
        expect(store.entries.last.id, 'e99');
      });

      test('addEntry evicts oldest when cap exceeded', () {
        // Fill to exactly maxEntries
        final entries = List.generate(
          LogStore.maxEntries,
          (i) => _makeEntry(id: 'e$i'),
        );
        store.addEntries(entries);
        expect(store.length, LogStore.maxEntries);

        // Add one more — oldest should be evicted
        store.addEntry(_makeEntry(id: 'overflow'));

        expect(store.length, LogStore.maxEntries);
        expect(store.entries.first.id, 'e1');
        expect(store.entries.last.id, 'overflow');
      });

      test('id index remains valid after eviction', () {
        final entries = List.generate(
          LogStore.maxEntries,
          (i) => _makeEntry(id: 'e$i'),
        );
        store.addEntries(entries);

        // Add 5 more to trigger eviction of first 5
        for (var i = 0; i < 5; i++) {
          store.addEntry(_makeEntry(id: 'new$i'));
        }

        expect(store.length, LogStore.maxEntries);

        // Upsert via replace should still find the correct entry by id
        store.addEntry(
          _makeEntry(id: 'new0', message: 'updated', replace: true),
        );
        final idx = store.entries.indexWhere((e) => e.id == 'new0');
        expect(idx, isNonNegative);
        expect(store.entries[idx].message, 'updated');
        // Length should not change from a replace
        expect(store.length, LogStore.maxEntries);
      });

      test('addEntries batch eviction works', () {
        final initial = List.generate(
          LogStore.maxEntries,
          (i) => _makeEntry(id: 'e$i'),
        );
        store.addEntries(initial);

        // Add batch of 10 — oldest 10 should be evicted
        final batch = List.generate(10, (i) => _makeEntry(id: 'batch$i'));
        store.addEntries(batch);

        expect(store.length, LogStore.maxEntries);
        expect(store.entries.first.id, 'e10');
        expect(store.entries.last.id, 'batch9');
      });
    });

    // ── Stacking tests ──

    group('stacking', () {
      test('stackKeyFor returns key for event with replace=true', () {
        final entry = _makeEntry(id: 'e1', sessionId: 'sess-1', replace: true);
        expect(store.stackKeyFor(entry), 'sess-1::e1');
      });

      test('stackKeyFor returns key for data with key and override', () {
        final entry = _makeEntry(
          id: 'd1',
          kind: EntryKind.data,
          key: 'theme',
          value: 'dark',
        );
        // override_ defaults to true in makeTestEntry
        expect(store.stackKeyFor(entry), 'sess-1::data::theme');
      });

      test('stackKeyFor returns null for normal event', () {
        final entry = _makeEntry(id: 'e1');
        expect(store.stackKeyFor(entry), isNull);
      });

      test('stackKeyFor returns null for data without key', () {
        final entry = _makeEntry(id: 'd1', kind: EntryKind.data, value: 42);
        expect(store.stackKeyFor(entry), isNull);
      });

      test(
        'addEntry with replace=true creates stack and preserves history',
        () {
          store.addEntry(_makeEntry(id: 'e1', message: 'v1', replace: true));
          store.addEntry(_makeEntry(id: 'e1', message: 'v2', replace: true));
          store.addEntry(_makeEntry(id: 'e1', message: 'v3', replace: true));

          expect(store.length, 1);
          expect(store.entries.first.message, 'v3');
          expect(store.stackDepth('e1'), 3);

          final stack = store.getStack('e1');
          expect(stack.length, 3);
          expect(stack[0].message, 'v1');
          expect(stack[1].message, 'v2');
          expect(stack[2].message, 'v3');
        },
      );

      test('data entries with same key stack', () {
        store.addEntry(
          _makeEntry(id: 'd1', kind: EntryKind.data, key: 'count', value: 1),
        );
        store.addEntry(
          _makeEntry(id: 'd2', kind: EntryKind.data, key: 'count', value: 2),
        );
        store.addEntry(
          _makeEntry(id: 'd3', kind: EntryKind.data, key: 'count', value: 3),
        );

        // Only head (d3) in _entries
        expect(store.length, 1);
        expect(store.entries.first.value, 3);

        expect(store.stackDepth('d3'), 3);
        final stack = store.getStack('d3');
        expect(stack.length, 3);
        expect(stack[0].value, 1);
        expect(stack[2].value, 3);
      });

      test('stackDepth returns 1 for non-stacked entry', () {
        store.addEntry(_makeEntry(id: 'e1'));
        expect(store.stackDepth('e1'), 1);
      });

      test('getStack returns singleton for non-stacked entry', () {
        store.addEntry(_makeEntry(id: 'e1', message: 'hello'));
        final stack = store.getStack('e1');
        expect(stack.length, 1);
        expect(stack.first.message, 'hello');
      });

      test('getStack returns empty list for unknown id', () {
        expect(store.getStack('unknown'), isEmpty);
      });

      test('eviction clears entire stack', () {
        // Fill to near cap
        final entries = List.generate(
          LogStore.maxEntries - 1,
          (i) => _makeEntry(id: 'e$i'),
        );
        store.addEntries(entries);

        // Add a stacked entry at the front position (index 0)
        // First add the stackable entry (it gets appended at end)
        store.addEntry(_makeEntry(id: 'stack1', message: 'v1', replace: true));
        // Now at maxEntries exactly

        // Add versions to the stack
        store.addEntry(_makeEntry(id: 'stack1', message: 'v2', replace: true));
        store.addEntry(_makeEntry(id: 'stack1', message: 'v3', replace: true));

        expect(store.stackDepth('stack1'), 3);

        // Add enough new entries to push stack1 past eviction
        final overflow = List.generate(
          LogStore.maxEntries,
          (i) => _makeEntry(id: 'overflow$i'),
        );
        store.addEntries(overflow);

        // Stack should be fully evicted
        expect(store.stackDepth('stack1'), 1);
        expect(store.getStack('stack1'), isEmpty);
      });

      test('clear removes all stacks', () {
        store.addEntry(_makeEntry(id: 'e1', message: 'v1', replace: true));
        store.addEntry(_makeEntry(id: 'e1', message: 'v2', replace: true));
        expect(store.stackDepth('e1'), 2);

        store.clear();
        expect(store.stackDepth('e1'), 1);
        expect(store.getStack('e1'), isEmpty);
      });

      test('max stack depth of 500 enforced', () {
        // Add 505 versions
        for (var i = 0; i < 505; i++) {
          store.addEntry(_makeEntry(id: 'e1', message: 'v$i', replace: true));
        }

        expect(store.stackDepth('e1'), LogStore.maxStackDepth);
        final stack = store.getStack('e1');
        expect(stack.length, LogStore.maxStackDepth);
        // Oldest entries should be pruned; first kept is v5
        expect(stack.first.message, 'v5');
        expect(stack.last.message, 'v504');
      });

      test('different sessions with same key create separate stacks', () {
        store.addEntry(
          _makeEntry(
            id: 'd1',
            sessionId: 'sess-1',
            kind: EntryKind.data,
            key: 'theme',
            value: 'dark',
          ),
        );
        store.addEntry(
          _makeEntry(
            id: 'd2',
            sessionId: 'sess-2',
            kind: EntryKind.data,
            key: 'theme',
            value: 'light',
          ),
        );

        // Two separate entries (different sessions, different stack keys)
        expect(store.length, 2);
        expect(store.stackDepth('d1'), 1);
        expect(store.stackDepth('d2'), 1);
      });

      test('addEntries batch handles stacking', () {
        store.addEntry(
          _makeEntry(id: 'd1', kind: EntryKind.data, key: 'count', value: 1),
        );

        store.addEntries([
          _makeEntry(id: 'd2', kind: EntryKind.data, key: 'count', value: 2),
          _makeEntry(id: 'd3', kind: EntryKind.data, key: 'count', value: 3),
        ]);

        expect(store.length, 1);
        expect(store.stackDepth('d3'), 3);
      });
    });
  });
}
