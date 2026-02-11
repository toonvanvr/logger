import 'package:app/services/filter_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FilterService', () {
    late FilterService service;

    setUp(() {
      service = FilterService();
    });

    test('initial state has all severities active', () {
      expect(service.activeSeverities, defaultSeverities);
      expect(service.textFilter, '');
      expect(service.stateFilterStack, isEmpty);
      expect(service.flatMode, false);
      expect(service.hasActiveFilters, false);
    });

    test('setSeverities updates and notifies', () {
      var notified = false;
      service.addListener(() => notified = true);

      service.setSeverities({'info', 'error'});
      expect(service.activeSeverities, {'info', 'error'});
      expect(notified, true);
    });

    test('setSeverities with same set does not notify', () {
      var notified = false;
      service.addListener(() => notified = true);

      service.setSeverities(Set.of(defaultSeverities));
      expect(notified, false);
    });

    test('setTextFilter updates and notifies', () {
      var notified = false;
      service.addListener(() => notified = true);

      service.setTextFilter('hello');
      expect(service.textFilter, 'hello');
      expect(notified, true);
      expect(service.hasActiveFilters, true);
    });

    test('setTextFilter with same value does not notify', () {
      var notified = false;
      service.addListener(() => notified = true);

      service.setTextFilter('');
      expect(notified, false);
    });

    test('toggleStateFilter adds and removes', () {
      service.toggleStateFilter('count');
      expect(service.stateFilterStack, ['count']);
      expect(service.activeStateFilters, {'count'});

      service.toggleStateFilter('name');
      expect(service.stateFilterStack, ['count', 'name']);

      service.toggleStateFilter('count');
      expect(service.stateFilterStack, ['name']);
    });

    test('removeStateFilter removes and notifies', () {
      service.toggleStateFilter('count');
      var notified = false;
      service.addListener(() => notified = true);

      service.removeStateFilter('count');
      expect(service.stateFilterStack, isEmpty);
      expect(notified, true);
    });

    test('removeStateFilter with missing key does not notify', () {
      var notified = false;
      service.addListener(() => notified = true);

      service.removeStateFilter('missing');
      expect(notified, false);
    });

    test('effectiveFilter combines text and state filters', () {
      service.setTextFilter('error');
      service.toggleStateFilter('count');
      expect(service.effectiveFilter, 'error state:count');
    });

    test('effectiveFilter with only text', () {
      service.setTextFilter('warn');
      expect(service.effectiveFilter, 'warn');
    });

    test('effectiveFilter with only state', () {
      service.toggleStateFilter('name');
      expect(service.effectiveFilter, 'state:name');
    });

    test('setFlatMode updates and notifies', () {
      var notified = false;
      service.addListener(() => notified = true);

      service.setFlatMode(true);
      expect(service.flatMode, true);
      expect(notified, true);
      expect(service.hasActiveFilters, true);
    });

    test('loadQuery sets severities, text, and clears state stack', () {
      service.toggleStateFilter('count');
      service.setFlatMode(true);

      service.loadQuery(severities: {'info'}, textFilter: 'loaded');
      expect(service.activeSeverities, {'info'});
      expect(service.textFilter, 'loaded');
      expect(service.stateFilterStack, isEmpty);
      // flatMode is not reset by loadQuery
      expect(service.flatMode, true);
    });

    test('clear resets everything to defaults', () {
      service.setSeverities({'error'});
      service.setTextFilter('search');
      service.toggleStateFilter('key');
      service.setFlatMode(true);

      service.clear();
      expect(service.activeSeverities, defaultSeverities);
      expect(service.textFilter, '');
      expect(service.stateFilterStack, isEmpty);
      expect(service.flatMode, false);
      expect(service.hasActiveFilters, false);
    });
  });
}
