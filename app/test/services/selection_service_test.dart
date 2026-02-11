import 'package:app/services/selection_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SelectionService', () {
    late SelectionService service;

    setUp(() {
      service = SelectionService();
    });

    test('initial state', () {
      expect(service.selectionMode, false);
      expect(service.selectedEntryIds, isEmpty);
      expect(service.bookmarkedEntryIds, isEmpty);
      expect(service.stickyOverrideIds, isEmpty);
    });

    test('setSelectionMode updates and notifies', () {
      var notified = false;
      service.addListener(() => notified = true);

      service.setSelectionMode(true);
      expect(service.selectionMode, true);
      expect(notified, true);
    });

    test('setSelectionMode with same value does not notify', () {
      var notified = false;
      service.addListener(() => notified = true);

      service.setSelectionMode(false);
      expect(notified, false);
    });

    test('onEntrySelected toggles entry in set', () {
      service.setSelectionMode(true);

      service.onEntrySelected('a');
      expect(service.selectedEntryIds, contains('a'));

      service.onEntrySelected('a');
      expect(service.selectedEntryIds, isNot(contains('a')));
    });

    test('onEntrySelected notifies listeners', () {
      var count = 0;
      service.addListener(() => count++);

      service.onEntrySelected('a');
      expect(count, 1);

      service.onEntrySelected('a');
      expect(count, 2);
    });

    test('clearSelection resets all selection state', () {
      service.setSelectionMode(true);
      service.onEntrySelected('a');
      service.onEntrySelected('b');

      var notified = false;
      service.addListener(() => notified = true);

      service.clearSelection();
      expect(service.selectionMode, false);
      expect(service.selectedEntryIds, isEmpty);
      expect(notified, true);
    });

    test('onEntryRangeSelected selects range between anchor and target', () {
      final ids = ['a', 'b', 'c', 'd', 'e'];

      // First call sets anchor
      service.onEntrySelected('b');
      expect(service.selectedEntryIds, contains('b'));

      // Range select from b to d
      service.onEntryRangeSelected('d', ids);
      expect(service.selectedEntryIds, containsAll(['b', 'c', 'd']));
    });

    test('onEntryRangeSelected with no anchor falls back to single select',
        () {
      final ids = ['a', 'b', 'c'];

      service.onEntryRangeSelected('b', ids);
      expect(service.selectedEntryIds, contains('b'));
    });

    test('onEntryRangeSelected with invalid indices falls back to single', () {
      service.onEntrySelected('x');
      service.onEntryRangeSelected('b', ['a', 'b', 'c']);
      expect(service.selectedEntryIds, contains('b'));
    });

    test('onEntryRangeSelected reverse direction works', () {
      final ids = ['a', 'b', 'c', 'd', 'e'];

      service.onEntrySelected('d');
      service.onEntryRangeSelected('b', ids);
      expect(service.selectedEntryIds, containsAll(['b', 'c', 'd']));
    });

    test('bookmarkSelected toggles bookmark on selected entries', () {
      service.onEntrySelected('a');
      service.onEntrySelected('b');

      service.bookmarkSelected();
      expect(service.bookmarkedEntryIds, containsAll(['a', 'b']));

      // Toggle again removes them
      service.bookmarkSelected();
      expect(service.bookmarkedEntryIds, isEmpty);
    });

    test('stickySelected pins all when not all pinned', () {
      service.onEntrySelected('a');
      service.onEntrySelected('b');

      service.stickySelected();
      expect(service.stickyOverrideIds, containsAll(['a', 'b']));
    });

    test('stickySelected unpins all when all already pinned', () {
      service.onEntrySelected('a');
      service.onEntrySelected('b');

      service.stickySelected();
      expect(service.stickyOverrideIds, containsAll(['a', 'b']));

      service.stickySelected();
      expect(service.stickyOverrideIds, isEmpty);
    });
  });
}
