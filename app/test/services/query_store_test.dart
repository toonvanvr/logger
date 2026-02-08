import 'package:app/services/query_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SavedQuery', () {
    test('equality is based on name', () {
      final q1 = SavedQuery(
        name: 'errors only',
        severities: const {'error', 'critical'},
        textFilter: '',
        savedAt: DateTime(2026, 2, 8),
      );
      final q2 = SavedQuery(
        name: 'errors only',
        severities: const {'debug'},
        textFilter: 'different',
        savedAt: DateTime(2026, 2, 9),
      );
      expect(q1, equals(q2));
      expect(q1.hashCode, equals(q2.hashCode));
    });

    test('toString includes name', () {
      final q = SavedQuery(
        name: 'test',
        severities: const {'info'},
        textFilter: '',
        savedAt: DateTime(2026),
      );
      expect(q.toString(), contains('test'));
    });
  });

  group('QueryStore', () {
    late QueryStore store;

    setUp(() {
      store = QueryStore();
    });

    test('starts empty', () {
      expect(store.queries, isEmpty);
      expect(store.length, 0);
    });

    test('saveQuery adds a new query', () {
      store.saveQuery(
        'error filter',
        severities: const {'error', 'critical'},
        textFilter: 'exception',
      );

      expect(store.length, 1);
      expect(store.queries.first.name, 'error filter');
      expect(store.queries.first.severities, {'error', 'critical'});
      expect(store.queries.first.textFilter, 'exception');
      expect(store.queries.first.sessionIds, isNull);
    });

    test('saveQuery with sessionIds stores them', () {
      store.saveQuery(
        'session filter',
        severities: const {'info'},
        textFilter: '',
        sessionIds: const {'sess-1', 'sess-2'},
      );

      expect(store.queries.first.sessionIds, {'sess-1', 'sess-2'});
    });

    test('saveQuery replaces existing query with same name', () {
      store.saveQuery(
        'my query',
        severities: const {'debug'},
        textFilter: 'old',
      );
      store.saveQuery(
        'my query',
        severities: const {'error'},
        textFilter: 'new',
      );

      expect(store.length, 1);
      expect(store.queries.first.textFilter, 'new');
      expect(store.queries.first.severities, {'error'});
    });

    test('deleteQuery removes by index', () {
      store.saveQuery('first', severities: const {'info'}, textFilter: '');
      store.saveQuery('second', severities: const {'debug'}, textFilter: '');

      store.deleteQuery(0);

      expect(store.length, 1);
      expect(store.queries.first.name, 'second');
    });

    test('deleteQuery ignores invalid index', () {
      store.saveQuery('only', severities: const {'info'}, textFilter: '');

      store.deleteQuery(-1);
      store.deleteQuery(5);

      expect(store.length, 1);
    });

    test('loadQuery invokes onQueryLoaded callback', () {
      SavedQuery? loaded;
      store.onQueryLoaded = (q) => loaded = q;

      final query = SavedQuery(
        name: 'test',
        severities: const {'error'},
        textFilter: 'crash',
        savedAt: DateTime(2026),
      );
      store.loadQuery(query);

      expect(loaded, isNotNull);
      expect(loaded!.name, 'test');
      expect(loaded!.textFilter, 'crash');
    });

    test('loadQuery does nothing when no callback set', () {
      final query = SavedQuery(
        name: 'test',
        severities: const {'error'},
        textFilter: '',
        savedAt: DateTime(2026),
      );
      // Should not throw
      store.loadQuery(query);
    });

    test('notifies listeners on saveQuery', () {
      var notified = false;
      store.addListener(() => notified = true);

      store.saveQuery('test', severities: const {'info'}, textFilter: '');

      expect(notified, isTrue);
    });

    test('notifies listeners on deleteQuery', () {
      store.saveQuery('test', severities: const {'info'}, textFilter: '');

      var notified = false;
      store.addListener(() => notified = true);

      store.deleteQuery(0);

      expect(notified, isTrue);
    });

    test('queries list is unmodifiable', () {
      store.saveQuery('test', severities: const {'info'}, textFilter: '');

      expect(
        () => store.queries.add(
          SavedQuery(
            name: 'hack',
            severities: const {},
            textFilter: '',
            savedAt: DateTime(2026),
          ),
        ),
        throwsUnsupportedError,
      );
    });

    test('severities in saved query are unmodifiable', () {
      store.saveQuery('test', severities: {'info', 'debug'}, textFilter: '');

      expect(
        () => store.queries.first.severities.add('error'),
        throwsUnsupportedError,
      );
    });
  });
}
